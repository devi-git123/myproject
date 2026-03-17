import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2B90B6),
        elevation: 0,
        centerTitle: true,
        actions: [
          // Clear all notifications button
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('notifications')
                .snapshots(),
            builder: (context, snapshot) {
              final hasNotifications = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
              if (!hasNotifications) return const SizedBox.shrink();
              
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: "Clear All",
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Clear All Notifications?"),
                      content: const Text("This will delete all notifications permanently."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text("Clear All"),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    final batch = FirebaseFirestore.instance.batch();
                    final notifs = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('notifications')
                        .get();
                    
                    for (var doc in notifs.docs) {
                      batch.delete(doc.reference);
                    }
                    await batch.commit();
                  }
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listening to a 'notifications' collection under the user
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          // Sort docs by timestamp manually (handles null timestamps)
          final docs = snapshot.data!.docs;
          docs.sort((a, b) {
            final Timestamp? aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final Timestamp? bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1; // null timestamps go to end
            if (bTime == null) return -1;
            
            return bTime.compareTo(aTime); // descending order (newest first)
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              return _buildNotificationCard(data, docs[index].id, uid!);
            },
          );
        },
      ),
    );
  }

  // UI for when there are no notifications
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "All caught up!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            "You have no new budget alerts.",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // UI for each notification item
  Widget _buildNotificationCard(Map<String, dynamic> data, String docId, String uid) {
    final String title = data['title'] ?? "Alert";
    final String message = data['message'] ?? "";
    final String type = data['type'] ?? "info"; // e.g., 'warning', 'success', 'info'
    final Timestamp? time = data['timestamp'] as Timestamp?;

    // Determine icon and color based on type
    IconData icon;
    Color color;
    if (type == 'warning') {
      icon = Icons.warning_amber_rounded;
      color = Colors.orange;
    } else if (type == 'success') {
      icon = Icons.check_circle_outline;
      color = Colors.green;
    } else {
      icon = Icons.info_outline;
      color = const Color(0xFF2B90B6);
    }

    return Dismissible(
      key: Key(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(docId)
            .delete();
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: .1),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 4),
              Text(
                time != null ? _formatTimestamp(time.toDate()) : "",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          isThreeLine: true,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime date) {
    return "${date.day}/${date.month} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}