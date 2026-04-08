import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContractorExperienceScreen extends StatefulWidget {
  const ContractorExperienceScreen({super.key});

  @override
  State<ContractorExperienceScreen> createState() => _ContractorExperienceScreenState();
}

class _ContractorExperienceScreenState extends State<ContractorExperienceScreen> {
  final List<Map<String, String>> _experience = [];
  bool _isLoading = false;

  final TextEditingController _contractNameController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExperience();
  }

  Future<void> _loadExperience() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['work_experience'] != null) {
          setState(() {
            _experience.clear();
            _experience.addAll(List<Map<String, dynamic>>.from(data['work_experience']).map((e) => {
              'contract_name': e['contract_name'].toString(),
              'year': e['year'].toString(),
            }));
          });
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addExperienceItem() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Contract Experience"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _contractNameController, 
              decoration: const InputDecoration(labelText: "Contract Name", hintText: "e.g. Hospital Construction")
            ),
            TextField(
              controller: _yearController, 
              decoration: const InputDecoration(labelText: "Year", hintText: "e.g. 2022")
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (_contractNameController.text.isNotEmpty && _yearController.text.isNotEmpty) {
                setState(() {
                  _experience.add({
                    'contract_name': _contractNameController.text,
                    'year': _yearController.text,
                  });
                });
                _contractNameController.clear();
                _yearController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Future<void> _saveData() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'work_experience': _experience,
        }, SetOptions(merge: true));
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Work experience updated!"), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving work experience: $e"), backgroundColor: Colors.red),
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
        title: const Text("Work Experience", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F3A40),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFA5555A)),
            onPressed: _addExperienceItem,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: _experience.isEmpty 
                    ? const Center(child: Text("No contract history added yet.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _experience.length,
                        itemBuilder: (context, index) {
                          final item = _experience[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFBFBFC),
                                child: Icon(Icons.business_center, color: Color(0xFF0F3A40)),
                              ),
                              title: Text(item['contract_name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Year: ${item['year']}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => setState(() => _experience.removeAt(index)),
                              ),
                            ),
                          );
                        },
                      ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3A40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Save Experience", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
