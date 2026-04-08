import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SendMessageScreen extends StatefulWidget {
  final String recipientName;
  final String senderName;
  final String recipientId;
  final String senderId;

  const SendMessageScreen({
    super.key,
    required this.recipientName,
    required this.senderName,
    required this.recipientId,
    required this.senderId,
  });

  @override
  State<SendMessageScreen> createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);
    
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': widget.recipientId,
        'senderId': widget.senderId,
        'senderName': widget.senderName,
        'message': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        // Keep these for backward compatibility with old queries if necessary
        'workerId': widget.recipientId, 
        'contractorId': widget.senderId,
        'contractorName': widget.senderName,
      });

      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F3A40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel('TO:'),
            _buildReadOnlyField(widget.recipientName),
            const SizedBox(height: 20),
            
            _buildFieldLabel('FROM:'),
            _buildReadOnlyField(widget.senderName),
            const SizedBox(height: 32),
            
            _buildFieldLabel('MESSAGE:'),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Type your message to ${widget.recipientName} here...',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFF0F3A40)),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendMessage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F3A40),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Send Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F3A40)),
      ),
    );
  }
}
