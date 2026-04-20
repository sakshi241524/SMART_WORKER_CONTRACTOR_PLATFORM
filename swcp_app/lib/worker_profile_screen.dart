import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/storage_service.dart';
import 'profile_sections/personal_info_screen.dart';
import 'profile_sections/skills_certificates_screen.dart';
import 'profile_sections/work_history_screen.dart';
import 'profile_sections/account_settings_screen.dart';
import 'profile_sections/help_support_screen.dart';
import 'widgets/reviews_list_widget.dart';
import 'payment_settings_screen.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'services/notification_service.dart';

class WorkerProfileScreen extends StatefulWidget {
  const WorkerProfileScreen({super.key});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  String _name = "...";
  String _email = "...";
  String? _profileImageUrl;
  bool _isUploading = false;
  double _rating = 0.0;
  int _reviewsCount = 0;
  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {  
      _email = user.email ?? "...";
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        if (mounted) {
          setState(() {
            _name = doc.get('name') ?? "Worker Name";
            _profileImageUrl = doc.data()?.containsKey('profileImageUrl') == true ? doc.get('profileImageUrl') : null;
            _rating = (doc.data()?['rating'] ?? 0.0).toDouble();
            _reviewsCount = (doc.data()?['reviewCount'] ?? 0).toInt();
          });
        }
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          // Profile Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                  backgroundImage: (_profileImageUrl != null && _profileImageUrl!.startsWith('data:image'))
                      ? MemoryImage(base64Decode(_profileImageUrl!.split(',').last)) as ImageProvider
                      : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(_profileImageUrl!)
                          : null,
                  child: (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 50, color: Color(0xFF0F3A40))
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _email,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 5),
                          Text(
                            "$_rating ($_reviewsCount reviews)",
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Divider(thickness: 1, height: 1),
          // Menu Items
          _buildMenuItem(
            icon: Icons.person_outline,
            title: "Personal Information",
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PersonalInfoScreen()));
              if (result == true) _fetchUserData();
            },
          ),
          _buildMenuItem(
            icon: Icons.card_membership_outlined,
            title: "My Skills & Certificates",
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SkillsCertificatesScreen()));
              if (result == true) _fetchUserData();
            },
          ),
          _buildMenuItem(
            icon: Icons.history_outlined,
            title: "Work History",
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const WorkHistoryScreen()));
              if (result == true) _fetchUserData();
            },
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: "Account Settings",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen())),
          ),
          _buildMenuItem(
            icon: Icons.account_balance_outlined,
            title: "Payment Settings",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentSettingsScreen())),
          ),

          _buildMenuItem(
            icon: Icons.help_outline,
            title: "Help & Support",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpSupportScreen())),
          ),
          const SizedBox(height: 20),
          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: OutlinedButton(
              onPressed: () async {
                // Clear FCM token from Firestore before logging out
                await NotificationService.instance.deleteToken();
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: BorderSide(color: Colors.red.shade100, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.logout),
                   SizedBox(width: 10),
                   Text("Log Out", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          // Reviews Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Work Reviews",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                ),
                const SizedBox(height: 15),
                ReviewsListWidget(userId: FirebaseAuth.instance.currentUser?.uid ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.grey.shade700),
            const SizedBox(width: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }


}
