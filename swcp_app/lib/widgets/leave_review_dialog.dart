import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeaveReviewDialog extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const LeaveReviewDialog({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
  });

  @override
  State<LeaveReviewDialog> createState() => _LeaveReviewDialogState();
}

class _LeaveReviewDialogState extends State<LeaveReviewDialog> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final reviewerName = userDoc.data()?['name'] ?? 'User';

    setState(() {
      _isSubmitting = true;
    });

    try {
      final reviewsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .collection('reviews');

      // Check if user already reviewed
      final existingReview = await reviewsRef.where('reviewerId', isEqualTo: uid).limit(1).get();

      if (existingReview.docs.isNotEmpty) {
        // Update existing
        await existingReview.docs.first.reference.update({
          'rating': _rating.toDouble(),
          'reviewText': _reviewController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new
        await reviewsRef.add({
          'reviewerId': uid,
          'reviewerName': reviewerName,
          'rating': _rating.toDouble(),
          'reviewText': _reviewController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // Re-calculate average
      final allReviews = await reviewsRef.get();
      double totalRating = 0;
      for (var doc in allReviews.docs) {
        final data = doc.data();
        final double rating = (data['rating'] != null) ? (data['rating'] as num).toDouble() : 0.0;
        totalRating += rating;
      }
      
      double avgRating = allReviews.docs.isNotEmpty ? totalRating / allReviews.docs.length : 0.0;

      await FirebaseFirestore.instance.collection('users').doc(widget.targetUserId).update({
        'rating': avgRating,
        'reviewCount': allReviews.docs.length,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review submitted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Review ${widget.targetUserName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rating', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text('Written Review', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share details of your experience...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F3A40), width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F3A40),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}
