import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_conversation_screen.dart';
import 'post_job_screen.dart';
import 'direct_post_job_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WorkerDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> workerData;
  final String contractorName;

  const WorkerDetailsScreen({
    super.key, 
    required this.workerData,
    required this.contractorName,
  });

  void _makeCall(BuildContext context, String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> skills = workerData['skills'] ?? [];
    
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFC),
      appBar: AppBar(
        title: const Text('Worker Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F3A40),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Profile Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                    child: Text(
                      (workerData['name'] != null && workerData['name'].toString().isNotEmpty) 
                        ? workerData['name'].toString()[0].toUpperCase() 
                        : 'W',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    workerData['name'] ?? 'Unknown Worker',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                  ),
                  Text(
                    workerData['email'] ?? 'No email available',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Professional Skills'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: skills.map((skill) => Chip(
                      label: Text(skill.toString()),
                      backgroundColor: const Color(0xFF0F3A40).withOpacity(0.05),
                      labelStyle: const TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.w500),
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Contact Information'),
                  const SizedBox(height: 12),
                  _buildInfoTile(Icons.phone_outlined, 'Phone Number', workerData['phone'] ?? 'Not provided'),
                  _buildInfoTile(Icons.email_outlined, 'Email Address', workerData['email'] ?? 'Not provided'),
                  _buildInfoTile(
                    Icons.location_on_outlined, 
                    'Address', 
                    [
                      workerData['address'],
                      workerData['district'],
                      workerData['state'],
                      workerData['country']
                    ].where((e) => e != null && e.toString().isNotEmpty).join(', ') ?? 'Not provided'
                  ),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Educational Background'),
                  const SizedBox(height: 12),
                  _buildInfoTile(Icons.school_outlined, 'Education', workerData['education'] ?? 'Not provided'),
                  
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _makeCall(context, workerData['phone']),
                          icon: const Icon(Icons.call),
                          label: const Text('Call Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final contractorId = FirebaseAuth.instance.currentUser?.uid ?? '';
                            final workerId = workerData['uid'] ?? '';
                            if (contractorId.isEmpty || workerId.isEmpty) return;

                            final ids = [contractorId, workerId];
                            ids.sort();
                            final chatId = ids.join('_');

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatConversationScreen(
                                  chatId: chatId,
                                  otherUserId: workerId,
                                  otherUserName: workerData['name'] ?? 'Worker',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message_outlined),
                          label: const Text('Message'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F3A40),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DirectPostJobScreen(workerData: workerData),
                          ),
                        );
                      },
                      icon: const Icon(Icons.business_center),
                      label: const Text('Post Job for this Worker'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA5555A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF0F3A40))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
