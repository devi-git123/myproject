import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final Color kTealColor = const Color(0xFF2B90B6);

  // FAQ Data
  final List<Map<String, String>> _faqs = [
    {
      "question": "How do I change my default currency?",
      "answer": "Go to Settings > Account Management > Default Currency. Select your preferred currency, and your dashboard will update automatically."
    },
    {
      "question": "How do I add a new expense?",
      "answer": "Tap the '+' button in the center of the bottom navigation bar. Enter the amount, select a category, and ensure 'Expense' is selected before saving."
    },
    {
      "question": "Is my data stored safely?",
      "answer": "Yes, we use Firebase Firestore with secure authentication. Your financial data is linked only to your private account."
    },
    {
      "question": "Can I use the app offline?",
      "answer": "The app requires an internet connection to sync your data in real-time. Offline support is planned for a future update."
    },
    {
      "question": "How do I reset my password?",
      "answer": "On the login screen, tap 'Forgot Password'. We will send a reset link to your registered email address."
    },
  ];

  // Function to show feedback dialog
  void _contactSupport() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    String? selectedCategory;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Contact Support"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Category (optional)",
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: "Bug Report", child: Text("Bug Report")),
                  DropdownMenuItem(value: "Feature Request", child: Text("Feature Request")),
                  DropdownMenuItem(value: "General Support", child: Text("General Support")),
                ],
                onChanged: (val) => selectedCategory = val,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: "Message",
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              
              // Validation
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please login to submit a ticket")),
                );
                return;
              }
              
              if (messageController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter a message")),
                );
                return;
              }
              
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please enter your name")),
                );
                return;
              }
              
              // Close popup immediately
              Navigator.pop(ctx);
              
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Thank you! Your message has been sent.")),
              );
              
              // Submit to Firebase Support Tickets collection in background
              FirebaseFirestore.instance
                  .collection('supportTickets')
                  .add({
                'userId': user.uid,
                'senderName': nameController.text,
                'senderEmail': emailController.text.isNotEmpty ? emailController.text : 'No email provided',
                'category': selectedCategory ?? 'General Support',
                'message': messageController.text,
                'status': 'pending',
                'timestamp': FieldValue.serverTimestamp(),
              }).then((docRef) {
                debugPrint('Support ticket created successfully: ${docRef.id}');
              }).catchError((error) {
                debugPrint('Error submitting support ticket: $error');
                // Show error to user since this is a critical failure
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Submission failed: $error")),
                  );
                }
              });
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help Center", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: kTealColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP ILLUSTRATION/HEADER ---
            Center(
              child: Column(
                children: [
                  Icon(Icons.help_center_rounded, size: 80, color: kTealColor),
                  const SizedBox(height: 10),
                  const Text(
                    "How can we help you?",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const Text("Search our FAQs or contact support", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // --- FAQ SECTION ---
            const Text("Frequently Asked Questions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Generate Expandable FAQ Tiles
            ..._faqs.map((faq) => ExpansionTile(
              title: Text(faq['question']!, style: const TextStyle(fontWeight: FontWeight.w500)),
              iconColor: kTealColor,
              textColor: kTealColor,
              childrenPadding: const EdgeInsets.all(15),
              children: [
                Text(faq['answer']!, style: const TextStyle(height: 1.5, color: Colors.black87)),
              ],
            )),

            const SizedBox(height: 40),

            // --- CONTACT SECTION ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kTealColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Still need help?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 5),
                        const Text("Our team is available 24/7", style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _contactSupport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTealColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Email Us", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}