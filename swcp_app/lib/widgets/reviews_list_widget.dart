import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ReviewsListWidget extends StatelessWidget {
  final String userId;
  final int? limit;

  const ReviewsListWidget({super.key, required this.userId, this.limit});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reviews')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(20.0),
            child: CircularProgressIndicator(),
          ));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No reviews yet.',
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),
          );
        }

        final allDocs = snapshot.data!.docs;
        final docs = limit != null ? allDocs.take(limit!).toList() : allDocs;

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final reviewerName = data['reviewerName'] ?? 'Anonymous';
            final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
            final reviewText = data['reviewText'] as String? ?? '';
            final timestamp = data['timestamp'] as Timestamp?;
            final dateStr = timestamp != null
                ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                : 'Recent';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                            child: Text(
                              reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40), fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(reviewerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (starIndex) {
                      return Icon(
                        starIndex < rating.floor() ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                  ),
                  if (reviewText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(reviewText, style: const TextStyle(fontSize: 14)),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
