import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
      // Query for the last 10 messages to find the new preview
      // We don't filter in Firestore here to maintain compatibility with legacy messages without 'visibleTo'
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      // Client-side filter for visibility
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
        // No visible messages left for me
        if (choice == 'everyone') {
          // If deleted for everyone and none left, remove the whole chat document
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).delete();
        } else {
          // Just hide the chat from my list
          await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
            'visibleTo.$currentUserUid': false,
          });
        }
        
        // Auto-navigate back since conversation is empty
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
    
    // Check if ALL selected messages are mine BEFORE showing dialog
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
      // We need to check who sent each message for 'Delete for everyone'
      final messagesSnapshot = await chatDocRef.collection('messages').get();
      final selectedDocs = messagesSnapshot.docs.where((doc) => _selectedMessageIds.contains(doc.id));

      if (choice == 'everyone') {
        for (var doc in selectedDocs) {
          final data = doc.data();
          if (data['senderId'] == currentUserUid) {
            // My message: delete for both
            batch.delete(doc.reference);
          } else {
            // Their message: only hide for me
            batch.update(doc.reference, {'visibleTo.$currentUserUid': false});
          }
        }
      } else {
        // Delete for me only (hide for all selected regardless of sender)
        for (var id in _selectedMessageIds) {
          batch.update(chatDocRef.collection('messages').doc(id), {
            'visibleTo.$currentUserUid': false,
          });
        }
      }

      await batch.commit();
      await _updateLastMessageAfterDeletion(choice);
      
      _exitSelectionMode();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(choice == 'everyone' ? 'Deleted for everyone' : 'Deleted for me'))
      );
    } catch (e) {
      debugPrint("Error deleting messages: $e");
    }
  }

  Future<void> _clearEntireChat() async {
    // For clearing entire chat, we only show 'Delete for me' if there's any receiver message
    // To be safe and adhere to user rule, we hide 'Everyone' for whole chat clears
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

      if (choice == 'everyone') {
        for (var doc in messages.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['senderId'] == currentUserUid) {
            // Delete my messages for everyone
            batch.delete(doc.reference);
          } else {
            // Hide their messages for me
            batch.update(doc.reference, {'visibleTo.$currentUserUid': false});
          }
        }
        // For 'everyone', we only delete the parent chat if BOTH agree or it's empty
        // But for simplicity, we'll just hide it for the current user
        batch.update(chatDocRef, {'visibleTo.$currentUserUid': false});
      } else {
        // Hide all for me
        for (var doc in messages.docs) {
          batch.update(doc.reference, {'visibleTo.$currentUserUid': false});
        }
        batch.update(chatDocRef, {'visibleTo.$currentUserUid': false});
      }

      await batch.commit();
      _exitSelectionMode();
      
      Navigator.pop(context); // Go back to chat list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(choice == 'everyone' ? 'Chat deleted for everyone' : 'Chat deleted for me'))
      );
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
        // Visual feedback
        final langName = langCode == 'en' ? 'English' : langCode == 'hi' ? 'Hindi' : 'Marathi';
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to $langName'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: _exitSelectionMode)
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: _isSelectionMode 
            ? Text('${_selectedMessageIds.length} selected')
            : Text(widget.otherUserName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: const Color(0xFF0F3A40),
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
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading messages'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allMessages = snapshot.data?.docs ?? [];
                
                // Filter visible messages client-side for compatibility
                final messages = allMessages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final visibleTo = data['visibleTo'] as Map<String, dynamic>?;
                  return visibleTo == null || visibleTo[currentUserUid] != false;
                }).toList();

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi!', style: TextStyle(color: Colors.grey)),
                  );
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

                    return GestureDetector(
                      onLongPress: () => _enterSelectionMode(doc.id),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(doc.id);
                        }
                      },
                      child: Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.blue.withOpacity(0.2) // Selection tint
                                : (isMine ? const Color(0xFF0F3A40) : Colors.white),
                            borderRadius: BorderRadius.circular(20).copyWith(
                              bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(20),
                              bottomLeft: !isMine ? const Radius.circular(4) : const Radius.circular(20),
                            ),
                            border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (!isMine)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.transparent : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 4),
                                            child: Icon(Icons.translate, size: 12, color: Colors.grey),
                                          ),
                                          _buildLangOption(doc.id, 'English', 'en'),
                                          const Text(" | ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          _buildLangOption(doc.id, 'Hindi', 'hi'),
                                          const Text(" | ", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                          _buildLangOption(doc.id, 'Marathi', 'mr'),
                                        ],
                                      ),
                                    ),
                                  Text(
                                    _getTranslation(data['message'] ?? '', _selectedLanguages[doc.id] ?? 'en'),
                                    key: ValueKey('${doc.id}_${_selectedLanguages[doc.id] ?? 'en'}'),
                                    style: TextStyle(
                                      color: isMine 
                                          ? Colors.white 
                                          : ((_selectedLanguages[doc.id] ?? 'en') != 'en' ? Colors.blue : Colors.black87),
                                      fontSize: 16,
                                      fontStyle: (_selectedLanguages[doc.id] ?? 'en') != 'en' ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatMessageTime(timestamp),
                                    style: TextStyle(
                                      color: isMine ? Colors.white70 : Colors.grey,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Icon(Icons.check_circle, size: 16, color: Colors.blue),
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
          
          // Input field area
          if (!_isSelectionMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
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
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F3A40),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: _isSending 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white),
                        onPressed: _isSending ? null : _sendMessage,
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
