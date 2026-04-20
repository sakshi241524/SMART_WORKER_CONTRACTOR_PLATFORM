import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/notification_sender_service.dart';

class DirectPostJobScreen extends StatefulWidget {
  final Map<String, dynamic> workerData;

  const DirectPostJobScreen({super.key, required this.workerData});

  @override
  State<DirectPostJobScreen> createState() => _DirectPostJobScreenState();
}

class _DirectPostJobScreenState extends State<DirectPostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _jobNameController = TextEditingController();
  final TextEditingController _contractorNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  
  DateTime _selectedDate = DateTime.now();
  final List<String> _professions = [
    'Plumber', 'Electrician', 'Carpenter', 'Mason (bricklayer)', 'Painter',
    'Welder', 'Mechanic (automobile technician)', 'AC Technician (HVAC technician)',
    'Roofer', 'Tiler (tile installer)', 'Plasterer', 'Blacksmith',
    'Construction Laborer', 'Interior Designer', 'Glass Installer (glazier)',
    'Locksmith', 'Solar Panel Installer', 'Elevator Technician',
    'Cable Technician (internet/TV wiring)'
  ];
  final Map<String, int> _selectedWorkers = {};
  final Set<String> _autoDetectedSkills = {};
  bool _isLoading = false;
  double? _contractorLat;
  double? _contractorLng;

  @override
  void initState() {
    super.initState();
    _fetchContractorName();
    _performSmartMatch();
  }

  void _performSmartMatch() {
    final List<dynamic> workerSkills = widget.workerData['skills'] ?? [];
    if (workerSkills.isEmpty) return;

    for (var skillObj in workerSkills) {
      String skill = skillObj.toString().toLowerCase().trim();
      
      for (var prof in _professions) {
        String profLower = prof.toLowerCase();
        
        // 1. Exact Match
        // 2. Contains (e.g. "Specialist Electrician" matches "Electrician")
        // 3. Suffix variations (e.g. "Carpentry" matches "Carpenter")
        bool isMatch = skill == profLower || 
                      skill.contains(profLower) || 
                      profLower.contains(skill);
        
        // Handle common variations
        if (!isMatch) {
          if (profLower == "carpenter" && skill.contains("carpentr")) isMatch = true;
          if (profLower == "painter" && skill.contains("paint")) isMatch = true;
          if (profLower.contains("laborer") && (skill.contains("labor") || skill.contains("labour"))) isMatch = true;
          if (profLower.contains("mason") && skill.contains("mason")) isMatch = true;
          if (profLower.contains("ac technician") && (skill.contains("hvac") || skill.contains("air condition"))) isMatch = true;
        }

        if (isMatch) {
          setState(() {
            _selectedWorkers[prof] = 1;
            _autoDetectedSkills.add(prof);
          });
        }
      }
    }

    // Fallback: If no match found, don't auto-select anything to avoid incorrect guesses
  }

  Future<void> _fetchContractorName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _contractorNameController.text = data?['name'] ?? "";
          _phoneNumberController.text = data?['phone'] ?? "";
          _contractorLat = data?['latitude'];
          _contractorLng = data?['longitude'];
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F3A40),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F3A40),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _toggleProfession(String profession) {
    setState(() {
      if (_selectedWorkers.containsKey(profession)) {
        _selectedWorkers.remove(profession);
      } else {
        _selectedWorkers[profession] = 1;
      }
    });
  }

  void _updateWorkerCount(String profession, int delta) {
    setState(() {
      if (_selectedWorkers.containsKey(profession)) {
        int newValue = _selectedWorkers[profession]! + delta;
        if (newValue > 0) {
          _selectedWorkers[profession] = newValue;
        } else {
          _selectedWorkers.remove(profession);
        }
      }
    });
  }

  Future<void> _postJob() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one profession'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final jobDocRef = await FirebaseFirestore.instance.collection('jobs').add({
        'contractorId': uid,
        'targetWorkerId': widget.workerData['uid'], // Direct job target
        'workerId': widget.workerData['uid'], // Added for compatibility
        'jobName': _jobNameController.text.trim(),
        'contractorName': _contractorNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'requiredWorkers': _selectedWorkers,
        'budgetPerWorker': double.tryParse(_budgetController.text) ?? 0.0,
        'paymentStatus': 'unpaid',
        'acceptedWorkers': _selectedWorkers.map((key, value) => MapEntry(key, [])),
        'status': 'open',

        'latitude': _contractorLat,
        'longitude': _contractorLng,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send notification to targeted worker
      final String companyName = _contractorNameController.text.trim().isNotEmpty ? _contractorNameController.text.trim() : 'A Contractor';
      await FirebaseFirestore.instance.collection('notifications').add({
        'receiverId': widget.workerData['uid'],
        'workerId': widget.workerData['uid'], // For backwards compatibility
        'senderId': uid,
        'senderName': companyName,
        'type': 'job_invitation',
        'title': 'Direct Job offer: ${_jobNameController.text.trim()}',
        'message': 'You have received a direct job offer. Tap to view details.',
        'jobId': jobDocRef.id,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // Send Push Notification
      NotificationSenderService.sendNotification(
        recipientUid: widget.workerData['uid'],
        title: "Direct Job Offer from $companyName",
        body: "Job: ${_jobNameController.text.trim()}. Tap to view details.",
        data: {
          'jobId': jobDocRef.id,
          'type': 'job_invitation',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Job posted directly to ${widget.workerData['name']}!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting job: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Post Job to ${widget.workerData['name']}', 
          style: const TextStyle(color: Color(0xFF5D1212), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F3A40)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F3A40).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0F3A40).withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFF0F3A40).withOpacity(0.1),
                      backgroundImage: (widget.workerData['profileImageUrl'] != null && widget.workerData['profileImageUrl'].toString().startsWith('data:image'))
                        ? MemoryImage(base64Decode(widget.workerData['profileImageUrl'].toString().split(',').last)) as ImageProvider
                        : (widget.workerData['profileImageUrl'] != null && widget.workerData['profileImageUrl'].toString().isNotEmpty)
                          ? CachedNetworkImageProvider(widget.workerData['profileImageUrl'])
                          : null,
                      child: (widget.workerData['profileImageUrl'] == null || widget.workerData['profileImageUrl'].toString().isEmpty)
                        ? Text(widget.workerData['name']?[0].toUpperCase() ?? 'W', 
                            style: const TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold))
                        : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Directed to:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(widget.workerData['name'] ?? 'Worker', 
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
                        ],
                      ),
                    ),
                    const Icon(Icons.flash_on, color: Colors.amber, size: 20),
                  ],
                ),
              ),
              if (_autoDetectedSkills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "AI detected ${_autoDetectedSkills.length} matching skills from profile.",
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildTextField(_jobNameController, 'Job Name'),
              _buildTextField(_contractorNameController, 'Contractor Name'),
              _buildTextField(_phoneNumberController, 'Phone Number', keyboardType: TextInputType.phone),
              _buildTextField(_addressController, 'Construction Address', maxLines: 2),
              _buildTextField(_budgetController, 'Job Budget (₹)', keyboardType: TextInputType.number),

              
              const SizedBox(height: 16),
              const Text('Job Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F3A40))),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      DateFormat('EEE MMM dd yyyy').format(_selectedDate),
                      style: const TextStyle(fontSize: 18, color: Color(0xFF0F3A40)),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              if (_selectedWorkers.isNotEmpty) ...[
                const Text('Selected Workers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                ..._selectedWorkers.entries.map((entry) => _buildWorkerCounter(entry.key, entry.value)),
                const SizedBox(height: 24),
              ],

              const Text('Select Profession', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _professions.map((prof) {
                  bool isAuto = _autoDetectedSkills.contains(prof);
                  return FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(prof),
                        if (isAuto) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.auto_awesome, size: 12, color: Colors.blue),
                        ],
                      ],
                    ),
                    selected: _selectedWorkers.containsKey(prof),
                    onSelected: (_) => _toggleProfession(prof),
                    selectedColor: isAuto ? Colors.blue.shade100 : const Color(0xFF7CB9B3).withOpacity(0.5),
                    checkmarkColor: isAuto ? Colors.blue : const Color(0xFF0F3A40),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: isAuto ? Colors.blue.shade200 : Colors.grey.shade300),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _postJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F354D),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Post Direct Job', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F3A40)),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
        ),
        validator: (value) => value == null || value.isEmpty ? 'Required field' : null,
      ),
    );
  }

  Widget _buildWorkerCounter(String profession, int count) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(profession, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          Row(
            children: [
              IconButton(onPressed: () => _updateWorkerCount(profession, -1), icon: const Icon(Icons.remove, color: Colors.red)),
              Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => _updateWorkerCount(profession, 1), icon: const Icon(Icons.add, color: Colors.green)),
            ],
          ),
        ],
      ),
    );
  }
}
