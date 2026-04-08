import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkHistoryScreen extends StatefulWidget {
  const WorkHistoryScreen({super.key});

  @override
  State<WorkHistoryScreen> createState() => _WorkHistoryScreenState();
}

class _WorkHistoryScreenState extends State<WorkHistoryScreen> {
  final List<Map<String, String>> _workHistory = [];
  bool _isLoading = false;

  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadWorkHistory();
  }

  Future<void> _loadWorkHistory() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['work_history'] != null) {
          setState(() {
            _workHistory.addAll(List<Map<String, dynamic>>.from(data['work_history']).map((e) => {
              'company': e['company'].toString(),
              'duration': e['duration'].toString(),
            }));
          });
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _addHistoryItem() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Work History"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _companyController, decoration: const InputDecoration(labelText: "Company Name")),
            TextField(controller: _durationController, decoration: const InputDecoration(labelText: "Duration (e.g. 2020-2023)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (_companyController.text.isNotEmpty && _durationController.text.isNotEmpty) {
                setState(() {
                  _workHistory.add({
                    'company': _companyController.text,
                    'duration': _durationController.text,
                  });
                });
                _companyController.clear();
                _durationController.clear();
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
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'work_history': _workHistory,
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Work history updated!")));
        Navigator.pop(context);
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Work History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0F3A40)),
            onPressed: _addHistoryItem,
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
                  child: _workHistory.isEmpty 
                    ? const Center(child: Text("No work history added.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _workHistory.length,
                        itemBuilder: (context, index) {
                          final item = _workHistory[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFE8F1F1),
                                child: Icon(Icons.business, color: Color(0xFF0F3A40)),
                              ),
                              title: Text(item['company']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(item['duration']!),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => setState(() => _workHistory.removeAt(index)),
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
                    child: const Text("Save History", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
