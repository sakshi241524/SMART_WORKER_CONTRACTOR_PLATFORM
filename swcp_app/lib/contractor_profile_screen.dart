import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/storage_service.dart';
import 'profile_sections/contractor_personal_info_screen.dart';
import 'profile_sections/skills_certificates_screen.dart';
import 'profile_sections/contractor_experience_screen.dart';
import 'profile_sections/account_settings_screen.dart';
import 'profile_sections/help_support_screen.dart';

class ContractorProfileScreen extends StatefulWidget {
  const ContractorProfileScreen({super.key});

  @override
  State<ContractorProfileScreen> createState() => _ContractorProfileScreenState();
}

class _ContractorProfileScreenState extends State<ContractorProfileScreen> {
  String _name = "...";
  String _email = "...";
  String? _profileImageUrl;
  bool _isUploading = false;
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
            _name = doc.get('name') ?? "Contractor Name";
            _profileImageUrl = doc.data()?.containsKey('profileImageUrl') == true ? doc.get('profileImageUrl') : null;
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
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                        backgroundImage: _profileImageUrl != null
                            ? CachedNetworkImageProvider(_profileImageUrl!)
                            : null,
                        child: _profileImageUrl == null
                            ? Text(
                                _name.isNotEmpty ? _name[0].toUpperCase() : "C",
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                              )
                            : null,
                      ),
                    ),
                    if (_isUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(45),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F3A40),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _name,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                      ),
                      Text(
                        _email,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                      const SizedBox(height: 5),
                      const Chip(
                        label: Text("CONTRACTOR", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: Color(0xFFA5555A),
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
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ContractorPersonalInfoScreen()));
              if (result == true) _fetchUserData();
            },
          ),
          _buildMenuItem(
            icon: Icons.card_membership_outlined,
            title: "Certificates",
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SkillsCertificatesScreen(showSkills: false)));
              if (result == true) _fetchUserData();
            },
          ),
          _buildMenuItem(
            icon: Icons.history_outlined,
            title: "Work Experience",
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ContractorExperienceScreen()));
              if (result == true) _fetchUserData();
            },
          ),
          _buildMenuItem(
            icon: Icons.settings_outlined,
            title: "Account Settings",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsScreen())),
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
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Log Out"),
                    content: const Text("Are you sure you want to log out?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Log Out", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                  }
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
            Icon(icon, size: 28, color: const Color(0xFF0F3A40).withOpacity(0.7)),
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

  Future<void> _pickAndUploadImage() async {
    if (_isUploading) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (image != null) {
      if (mounted) setState(() => _isUploading = true);
      
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final String? downloadUrl = await _storageService.uploadProfileImage(File(image.path), user.uid);
        if (downloadUrl != null) {
          if (mounted) {
            setState(() {
              _profileImageUrl = downloadUrl;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile image updated successfully!')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image.')),
            );
          }
        }
      }
      
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
