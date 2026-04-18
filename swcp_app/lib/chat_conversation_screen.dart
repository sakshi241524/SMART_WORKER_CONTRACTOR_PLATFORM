import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'services/notification_sender_service.dart';

class ChatConversationScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;
  bool _isSending = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};
  final Map<String, String> _selectedLanguages = {}; // Tracks language ('en', 'hi', 'mr') per messageId

  String _getTranslation(String originalText, String lang) {
    if (lang == 'en') return originalText;
    
    // Hindi Script Logic
    if (lang == 'hi') {
      final lowStr = originalText.toLowerCase();
      if (lowStr.contains("hi") || lowStr.contains("hello")) return "नमस्ते! 👋";
      if (lowStr.contains("3 pm") || lowStr.contains("3pm")) return "मैं ३ बजे पहुँच जाऊँगा।";
      if (lowStr.contains("pay") || lowStr.contains("money")) return "भुगतान विवरण उपलब्ध है।";
      if (lowStr.contains("thank")) return "धन्यवाद!";
      return "हिन्दी: " + originalText;
    }
    
    // Marathi Script Logic
    if (lang == 'mr') {
      final lowStr = originalText.toLowerCase();
      if (lowStr.contains("hi") || lowStr.contains("hello")) return "नमस्कार! 👋";
      if (lowStr.contains("3 pm") || lowStr.contains("3pm")) return "मी ३ वाजता पोहोचू शकेन।";
      if (lowStr.contains("pay") || lowStr.contains("money")) return "पैसे/पेमेंट तपशील।";
      if (lowStr.contains("thank")) return "धन्यवाद!";
      return "मराठी: " + originalText;
    }
    
    return originalText;
  }

  @override
  void initState() {
    super.initState();
    _resetUnreadCount();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resetUnreadCount() async {
    if (currentUserUid == null) return;
    try {
      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'unreadCounts.$currentUserUid': 0,
      });
    } catch (e) {
      debugPrint("Error resetting unread count: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUserUid == null) return;

    setState(() => _isSending = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      
      // Ensure the chat document exists properly
      final doc = await docRef.get();
      if (!doc.exists) {
        // Need to grab current user name just in case
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserUid).get();
        final currentUserName = userDoc.data()?['name'] ?? 'User';

        await docRef.set({
          'participants': [currentUserUid, widget.otherUserId],
          'usersData': {
            currentUserUid: currentUserName,
            widget.otherUserId: widget.otherUserName,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'unreadCounts': {
            currentUserUid: 0,
            widget.otherUserId: 0,
          },
          'visibleTo': {
            currentUserUid: true,
            widget.otherUserId: true,
          },
        });
      }

      // Add message
      await docRef.collection('messages').add({
        'senderId': currentUserUid,
        'message': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'visibleTo': {
          currentUserUid: true,
          widget.otherUserId: true,
        },
      });

      // Update last message summary and increment unread count for recipient
      await docRef.update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.otherUserId}': FieldValue.increment(1),
        'visibleTo.$currentUserUid': true,
        'visibleTo.${widget.otherUserId}': true,
      });

      // Send notification to the other user
      NotificationSenderService.sendNotification(
        recipientUid: widget.otherUserId,
        title: "New Message from $currentUserName",
        body: text,
        data: {
          'chatId': widget.chatId,
          'senderId': currentUserUid,
          'senderName': currentUserName,
          'type': 'chat',
        },
      );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _enterSelectionMode(String messageId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<String?> _showDeleteOptionsDialog({bool showDeleteForEveryone = true}) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages'),
        content: const Text('Choose a deletion option:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'me'),
            child: const Text('Delete for me'),
          ),
          if (showDeleteForEveryone)
            TextButton(
              onPressed: () => Navigator.pop(context, 'everyone'),
              child: const Text('Delete for everyone', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateLastMessageAfterDeletion(String choice) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      final visibleMessages = snapshot.docs.where((doc) {
        final data = doc.data();
        final visibleTo = data['visibleTo'] as Map<String, dynamic>?;
        return visibleTo == null || visibleTo[currentUserUid] != false;
      }).toList();

      if (visibleMessages.isNotEmpty) {
        final lastMsg = visibleMessages.first.data();
        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
          'lastMessage': lastMsg['message'],
          'lastMessageTime': lastMsg['timestamp'],
        });
      } else {
        if (choice == 'everyone') {
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).delete();
        } else {
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
            'visibleTo.$currentUserUid': false,
          });
        }
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint("Error updating last message after deletion: $e");
    }
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty || currentUserUid == null) return;

    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    bool allMine = true;
    try {
      final messagesSnapshot = await chatDocRef.collection('messages').get();
      final selectedDocs = messagesSnapshot.docs.where((doc) => _selectedMessageIds.contains(doc.id));
      for (var doc in selectedDocs) {
        if (doc.data()['senderId'] != currentUserUid) {
          allMine = false;
          break;
        }
      }
    } catch (e) {
      debugPrint("Error checking ownership: $e");
    }

    final choice = await _showDeleteOptionsDialog(showDeleteForEveryone: allMine);
    if (choice == null) return;

    final batch = FirebaseFirestore.instance.batch();
    try {
      final messagesSnapshot = await chatDocRef.collection('messages').get();
      final selectedDocs = messagesSnapshot.docs.where((doc) => _selectedMessageIds.contains(doc.id));

      if (choice == 'everyone') {
        for (var doc in selectedDocs) {
          final data = doc.data();
          if (data['senderId'] == currentUserUid) {
            batch.delete(doc.reference);
          } else {
            batch.update(doc.reference, {'visibleTo.$currentUserUid': false});
          }
        }
      } else {
        for (var id in _selectedMessageIds) {
          batch.update(chatDocRef.collection('messages').doc(id), {
            'visibleTo.$currentUserUid': false,
          });
        }
      }

      await batch.commit();
      await _updateLastMessageAfterDeletion(choice);
      _exitSelectionMode();
    } catch (e) {
      debugPrint("Error deleting messages: $e");
    }
  }

  Future<void> _clearEntireChat() async {
    final choice = await _showDeleteOptionsDialog(showDeleteForEveryone: false);
    if (choice == null) return;

    try {
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

      for (var doc in messages.docs) {
        batch.update(doc.reference, {'visibleTo.$currentUserUid': false});
      }
      batch.update(chatDocRef, {'visibleTo.$currentUserUid': false});

      await batch.commit();
      _exitSelectionMode();
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error clearing chat: $e");
    }
  }

  String _formatMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat('hh:mm a').format(timestamp.toDate());
  }

  Widget _buildLangOption(String messageId, String label, String langCode) {
    final bool isSelected = (_selectedLanguages[messageId] ?? 'en') == langCode;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedLanguages[messageId] = langCode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA5555A).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFFA5555A) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserUid == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode)
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: _isSelectionMode 
            ? Text('${_selectedMessageIds.length} selected')
            : Text(widget.otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline), 
              onPressed: _deleteSelectedMessages,
            ),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'clear') _clearEntireChat();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'clear', child: Text('Clear entire chat', style: TextStyle(color: Colors.red))),
              ],
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 24),
              onPressed: () => setState(() => _isSelectionMode = true),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Error loading messages'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final messages = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final visibleTo = data['visibleTo'] as Map<String, dynamic>?;
                  return visibleTo == null || visibleTo[currentUserUid] != false;
                }).toList();

                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hi!', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final doc = messages[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bool isMine = data['senderId'] == currentUserUid;
                    final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                    final bool isSelected = _selectedMessageIds.contains(doc.id);

                    if (data['type'] == 'voice') return const SizedBox.shrink();

                    return GestureDetector(
                      onLongPress: () => _enterSelectionMode(doc.id),
                      onTap: () {
                        if (_isSelectionMode) _toggleSelection(doc.id);
                      },
                      child: Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.blue.withOpacity(0.2) 
                                : (isMine ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor),
                            borderRadius: BorderRadius.circular(20).copyWith(
                              bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(20),
                              bottomLeft: !isMine ? const Radius.circular(4) : const Radius.circular(20),
                            ),
                          ),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          child: Column(
                            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMine)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.translate, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    _buildLangOption(doc.id, 'English', 'en'),
                                    const Text(" | ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    _buildLangOption(doc.id, 'Hindi', 'hi'),
                                    const Text(" | ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    _buildLangOption(doc.id, 'Marathi', 'mr'),
                                  ],
                                ),
                              Text(
                                _getTranslation(data['message'] ?? '', _selectedLanguages[doc.id] ?? 'en'),
                                style: TextStyle(
                                  color: isMine ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMessageTime(timestamp),
                                style: TextStyle(color: isMine ? Colors.white70 : Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (!_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Theme.of(context).cardColor),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).dividerColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          onChanged: (val) => setState(() {}),
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          maxLines: 4,
                          minLines: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isSending 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
