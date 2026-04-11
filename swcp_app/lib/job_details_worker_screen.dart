import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_conversation_screen.dart';

class JobDetailsWorkerScreen extends StatefulWidget {
  final Map<String, dynamic> jobData;
  final String jobId;

  const JobDetailsWorkerScreen({super.key, required this.jobData, required this.jobId});

  @override
  State<JobDetailsWorkerScreen> createState() => _JobDetailsWorkerScreenState();
}

class _JobDetailsWorkerScreenState extends State<JobDetailsWorkerScreen> {
  bool _isAccepting = false;
  bool _isRejecting = false;
  String? _selectedProfession;

  Future<void> _acceptJob() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (widget.jobData['requiredWorkers'].length > 1 && _selectedProfession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select which profession you are joining as')),
      );
      return;
    }

    // If only one profession, auto-select it
    final profession = _selectedProfession ?? widget.jobData['requiredWorkers'].keys.first;

    setState(() => _isAccepting = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('jobs').doc(widget.jobId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw "Job doesn't exist";

        final data = snapshot.data() as Map<String, dynamic>;
        final Map<String, dynamic> accepted = Map<String, dynamic>.from(data['acceptedWorkers'] ?? {});
        final Map<String, dynamic> required = Map<String, dynamic>.from(data['requiredWorkers'] ?? {});

        List<dynamic> workersInRole = List.from(accepted[profession] ?? []);
        
        // 1. Check if worker already accepted
        bool alreadyJoined = false;
        accepted.values.forEach((list) {
          if ((list as List).contains(uid)) alreadyJoined = true;
        });

        if (alreadyJoined) throw "You have already joined this job";

        // 2. Check if role is full
        if (workersInRole.length >= (required[profession] ?? 0)) {
          throw "This position ($profession) is already full";
        }

        // 3. Add worker
        workersInRole.add(uid);
        accepted[profession] = workersInRole;

        // 4. Check if whole job is now full
        int totalRequired = 0;
        required.values.forEach((v) => totalRequired += (v as int));
        
        int totalAccepted = 0;
        accepted.values.forEach((v) => totalAccepted += (v as List).length);

        String status = data['status'] ?? 'open';
        if (totalAccepted >= totalRequired) {
          status = 'closed';
        }

        transaction.update(docRef, {
          'acceptedWorkers': accepted,
          'status': status,
        });
      });

      // Send notification to contractor
      final contractorId = widget.jobData['contractorId'] ?? widget.jobData['constructorId'];
      if (contractorId != null) {
        try {
          final workerDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final workerName = workerDoc.data()?['name'] ?? 'A worker';
          
          await FirebaseFirestore.instance.collection('notifications').add({
            'receiverId': contractorId,
            'senderId': uid,
            'senderName': workerName,
            'type': 'job_accepted',
            'message': '$workerName has joined your job: ${widget.jobData['jobName'] ?? 'Untitled Job'}',
            'jobId': widget.jobId,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });
        } catch (e) {
          debugPrint("Error sending notification to contractor: $e");
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job accepted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _rejectJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Job?'),
        content: const Text('This job will be permanently removed from your list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isRejecting = true);

    try {
      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
        'rejectedBy': FieldValue.arrayUnion([uid]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job rejected')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final Map<String, dynamic> acceptedBy = widget.jobData['acceptedWorkers'] ?? {};
    
    bool alreadyJoined = false;
    acceptedBy.values.forEach((list) {
      if ((list as List).contains(uid)) alreadyJoined = true;
    });

    final requiredWorkers = Map<String, int>.from(widget.jobData['requiredWorkers'] ?? {});
    final date = (widget.jobData['date'] as Timestamp).toDate();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Job Details', style: TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F3A40),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.jobData['jobName'] ?? 'Untitled Job', 
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text('Posted by: ${widget.jobData['contractorName'] ?? widget.jobData['constructorName'] ?? 'Contractor'}', 
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
            if (widget.jobData['targetWorkerId'] != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Text('DIRECT OFFER FOR YOU', 
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const Divider(height: 48),
            
            _buildInfoSection(Icons.calendar_today_outlined, 'Date', DateFormat('EEEE, MMM dd, yyyy').format(date)),
            if (widget.jobData['startTime'] != null && widget.jobData['endTime'] != null)
              _buildInfoSection(Icons.access_time_outlined, 'Working Hours', '${widget.jobData['startTime']} - ${widget.jobData['endTime']}'),
            _buildInfoSection(Icons.location_on_outlined, 'Location', widget.jobData['address'] ?? 'Not provided'),
            _buildInfoSection(Icons.phone_outlined, 'Contact', widget.jobData['phoneNumber'] ?? 'Not provided'),
            if (widget.jobData['contractorMessage'] != null && widget.jobData['contractorMessage'].toString().isNotEmpty)
              _buildInfoSection(Icons.message_outlined, 'Message from Contractor', widget.jobData['contractorMessage']),
            
            const SizedBox(height: 32),
            const Text('Required Professions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
            const SizedBox(height: 16),
            ...requiredWorkers.entries.map((e) {
              final isSelected = _selectedProfession == e.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedProfession = e.key),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0F3A40).withOpacity(0.05) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? const Color(0xFF0F3A40) : Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: TextStyle(fontSize: 18, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                        Text('Need: ${e.value}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final contractorId = widget.jobData['contractorId'] ?? widget.jobData['constructorId'];
                  if (contractorId != null) {
                    final contractorName = widget.jobData['contractorName'] ?? widget.jobData['constructorName'] ?? 'Contractor';
                    
                    // Create chat ID by sorting
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    
                    final ids = [uid, contractorId];
                    ids.sort();
                    final chatId = ids.join('_');

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatConversationScreen(
                          chatId: chatId,
                          otherUserId: contractorId,
                          otherUserName: contractorName,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Could not find contractor ID.')),
                    );
                  }
                },
                icon: const Icon(Icons.message_outlined, color: Color(0xFF0F3A40)),
                label: const Text('Message Contractor', style: TextStyle(color: Color(0xFF0F3A40), fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF0F3A40), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 48),
            if (alreadyJoined)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 32),
                    SizedBox(height: 12),
                    Text(
                      'YOU HAVE JOINED THIS JOB',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'The contractor will contact you soon.',
                      style: TextStyle(color: Colors.green, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isRejecting ? null : _rejectJob,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isRejecting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                        : const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAccepting ? null : _acceptJob,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3A40),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isAccepting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: const Color(0xFF0F3A40)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F3A40))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
