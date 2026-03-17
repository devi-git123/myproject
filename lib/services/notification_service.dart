import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level function required by FCM for background message handling.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint('FCM Background message: ${message.notification?.title}');
}

/// Singleton service that handles:
/// - FCM initialization & token management
/// - Writing notifications to Firestore (shown in NotificationsScreen)
/// - Budget alert triggers (80% warning, exceeded)
/// - Monthly summary notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── INITIALIZATION ──────────────────────────────────────────────────────────

  /// Call once from main() after Firebase.initializeApp().
  Future<void> initialize() async {
    // Register the background handler
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Request notification permissions (required on iOS, recommended on Android 13+)
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen for token refreshes and update Firestore
    _fcm.onTokenRefresh.listen(_persistToken);

    // Handle messages received while the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && message.notification != null) {
        _storeNotification(
          uid: uid,
          title: message.notification!.title ?? 'New Alert',
          body: message.notification!.body ?? '',
          type: message.data['type'] ?? 'info',
        );
      }
    });
  }

  /// Call this after a user successfully logs in to save their FCM token.
  Future<void> saveTokenForUser(String uid) async {
    final token = await _fcm.getToken();
    if (token != null) {
      await _persistToken(token);
    }
  }

  // ─── TOKEN MANAGEMENT ────────────────────────────────────────────────────────

  Future<void> _persistToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // merge: true so we don't overwrite other user fields
    await _db.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  // ─── NOTIFICATION STORAGE (Firestore) ────────────────────────────────────────

  /// Writes a notification document to users/{uid}/notifications.
  /// This is the collection that NotificationsScreen reads from.
  Future<void> _storeNotification({
    required String uid,
    required String title,
    required String body,
    String type = 'info', // 'info' | 'warning' | 'success'
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
      'title': title,
      'message': body,
      'type': type,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // ─── BUDGET ALERT TRIGGER ────────────────────────────────────────────────────

  /// Call this after every expense transaction is saved.
  ///
  /// [totalSpent] = sum of all expenses in this category this month
  /// [budget]     = the category's budget limit
  ///
  /// Triggers:
  ///   • 80% reached  → 'Budget Alert – 80%' warning notification
  ///   • 100% reached → 'Budget Exceeded!' warning notification
  Future<void> checkBudgetAndAlert({
    required String uid,
    required String categoryName,
    required double totalSpent,
    required double budget,
  }) async {
    if (budget <= 0) return;

    // Respect user's notification preference
    final doc = await _db.collection('users').doc(uid).get();
    final bool enabled = (doc.data() ?? {})['notifBudgetAlerts'] ?? true;
    if (!enabled) return;

    final double ratio = totalSpent / budget;

    if (ratio >= 1.0) {
      await _storeNotification(
        uid: uid,
        title: 'Budget Exceeded!',
        body:
            '$categoryName: spent ${totalSpent.toStringAsFixed(2)} / ${budget.toStringAsFixed(2)}',
        type: 'warning',
      );
    } else if (ratio >= 0.8) {
      await _storeNotification(
        uid: uid,
        title: 'Budget Alert – ${(ratio * 100).round()}%',
        body:
            '$categoryName is at ${(ratio * 100).round()}% of its budget limit',
        type: 'warning',
      );
    }
  }

  // ─── MONTHLY SUMMARY TRIGGER ─────────────────────────────────────────────────

  /// Call at the start of a new month (or after loading the previous month's data).
  ///
  /// Writes a summary notification showing income, expenses, and savings/overspend.
  Future<void> sendMonthlySummary({
    required String uid,
    required double totalIncome,
    required double totalExpense,
  }) async {
    // Respect user's notification preference
    final doc = await _db.collection('users').doc(uid).get();
    final bool enabled = (doc.data() ?? {})['notifMonthlySummary'] ?? true;
    if (!enabled) return;

    final double savings = totalIncome - totalExpense;
    final bool isSaving = savings >= 0;

    await _storeNotification(
      uid: uid,
      title: isSaving ? 'Monthly Summary ✅' : 'Monthly Summary ⚠️',
      body:
          'Income: ${totalIncome.toStringAsFixed(2)} | Expenses: ${totalExpense.toStringAsFixed(2)} | '
          '${isSaving ? 'Saved' : 'Overspent'}: ${savings.abs().toStringAsFixed(2)}',
      type: isSaving ? 'success' : 'warning',
    );
  }
}
