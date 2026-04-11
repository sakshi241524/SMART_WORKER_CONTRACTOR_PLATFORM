import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class SkillsCertificatesScreen extends StatefulWidget {
  final bool showSkills;
  const SkillsCertificatesScreen({super.key, this.showSkills = true});

  @override
  State<SkillsCertificatesScreen> createState() => _SkillsCertificatesScreenState();
}

class _SkillsCertificatesScreenState extends State<SkillsCertificatesScreen> {
  final List<String> _suggestedSkills = [
    "Plumber", 
    "Electrician", 
    "Carpenter", 
    "Mason (bricklayer)", 
    "Painter", 
    "Welder", 
    "Mechanic (automobile technician)", 
    "AC Technician (HVAC technician)", 
    "Roofer", 
    "Tiler (tile installer)", 
    "Plasterer", 
    "Blacksmith", 
    "Construction Laborer", 
    "Interior Designer", 
    "Glass Installer (glazier)", 
    "Locksmith", 
    "Solar Panel Installer", 
    "Elevator Technician", 
    "Cable Technician (internet/TV wiring)"
  ];
  final List<String> _mySkills = [];
  final List<String> _certificates = [];
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSkillsData();
  }

  Future<void> _loadSkillsData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _mySkills.clear();
          _certificates.clear();
          if (data['skills'] != null) _mySkills.addAll(List<String>.from(data['skills']));
          if (data['certificates'] != null) _certificates.addAll(List<String>.from(data['certificates']));
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _addSkill(String skill) {
    if (!_mySkills.contains(skill)) {
      setState(() => _mySkills.add(skill));
    }
  }

  void _removeSkill(String skill) {
    setState(() => _mySkills.remove(skill));
  }

  Future<void> _pickCertificate() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _certificates.add("Cert: ${image.name}");
      });
    }
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'skills': _mySkills,
          'certificates': _certificates,
        }, SetOptions(merge: true));
        
        if (mounted) {
          String message = widget.showSkills ? "Skills and Certificates saved!" : "Certificates saved!";
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving skills: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.showSkills ? "Skills & Certificates" : "Certificates", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showSkills) ...[
                  const Text("My Skills", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _mySkills.isEmpty 
                      ? [const Text("No skills added yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))]
                      : _mySkills.map((skill) => Chip(
                          label: Text(skill),
                          onDeleted: () => _removeSkill(skill),
                          backgroundColor: Colors.blue.shade50,
                          deleteIconColor: Colors.red,
                        )).toList(),
                  ),
                  const SizedBox(height: 25),
                  const Text("Suggested Skills", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedSkills.where((s) => !_mySkills.contains(s)).map((skill) => ActionChip(
                      label: Text(skill),
                      onPressed: () => _addSkill(skill),
                      backgroundColor: Colors.grey.shade100,
                    )).toList(),
                  ),
                  const SizedBox(height: 40),
                ],
                const Text("Certificates", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ..._certificates.map((cert) => ListTile(
                  leading: const Icon(Icons.verified, color: Colors.green),
                  title: Text(cert),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _certificates.remove(cert)),
                  ),
                )).toList(),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _pickCertificate,
                  icon: const Icon(Icons.upload_file),
                  label: const Text("Upload New Certificate"),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0F3A40),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFF0F3A40))
                    ),
                  ),
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3A40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Save & Upload", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
