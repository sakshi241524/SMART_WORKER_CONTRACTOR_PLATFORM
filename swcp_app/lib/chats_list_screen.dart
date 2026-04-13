import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_conversation_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime date = timestamp.toDate();
    final DateTime now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return DateFormat('hh:mm a').format(date); // e.g. 02:30 PM
    } else {
      return DateFormat('MMM dd').format(date); // e.g. Oct 12
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserUid == null) {
      return const Center(child: Text("Please login to see messages."));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUserUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // We use list so we can sort them manually and avoid Firestore composite index requirement
          final List<QueryDocumentSnapshot> allDocs = snapshot.data?.docs.toList() ?? [];
          
          // Filter out chats hidden for me ('Delete for me') or empty chats
          final List<QueryDocumentSnapshot> docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final visibleTo = data['visibleTo'] as Map<String, dynamic>?;
            final lastMessage = data['lastMessage'] as String? ?? '';
            
            // If the field is missing, assume it's visible. If it exists, check for false.
            return visibleTo == null || visibleTo[currentUserUid] != false;
          }).toList();
          
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['lastMessageTime'] as Timestamp?;
            final bTime = bData['lastMessageTime'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No messages yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              
              // Get the ID of the other user
              final List<dynamic> participants = data['participants'] ?? [];
              final String otherUserId = participants.firstWhere(
                (id) => id != currentUserUid, 
                orElse: () => ''
              );

              // Get the name of the other user
              final Map<String, dynamic> usersData = data['usersData'] ?? {};
              final String otherUserName = usersData[otherUserId] ?? 'Unknown User';

              final String lastMessage = data['lastMessage'] ?? '';
              final Timestamp? lastMessageTime = data['lastMessageTime'] as Timestamp?;
              final Map<String, dynamic> unreadCounts = data['unreadCounts'] ?? {};
              final int unreadCount = unreadCounts[currentUserUid] ?? 0;
              final bool hasUnread = unreadCount > 0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatConversationScreen(
                        chatId: docs[index].id,
                        otherUserId: otherUserId,
                        otherUserName: otherUserName,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F3A40).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: Color(0xFF0F3A40),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    otherUserName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: hasUnread ? FontWeight.w900 : FontWeight.bold,
                                      color: hasUnread ? Colors.black : const Color(0xFF0F3A40),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  _formatTimestamp(lastMessageTime),
                                  style: TextStyle(
                                    fontSize: 12, 
                                    color: hasUnread ? const Color(0xFF25D366) : Colors.grey,
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    lastMessage.isEmpty ? "Started a new conversation" : lastMessage,
                                    style: TextStyle(
                                      fontSize: 14, 
                                      color: hasUnread ? Colors.black87 : Colors.grey,
                                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasUnread)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
