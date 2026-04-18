import 'package:flutter/material.dart';
import 'widgets/reviews_list_widget.dart';

class AllReviewsScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const AllReviewsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFC),
      appBar: AppBar(
        title: Text('Reviews for $userName', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F3A40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'All Feedback',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
            ),
            const SizedBox(height: 16),
            ReviewsListWidget(userId: userId), // No limit here
          ],
        ),
      ),
    );
  }
}
