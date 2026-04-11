import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/recommendation_engine.dart';

class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _jobNameController = TextEditingController();
  final TextEditingController _contractorNameController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F3A40),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          _startTimeController.text = picked.format(context);
        } else {
          _endTime = picked;
          _endTimeController.text = picked.format(context);
        }
      });
    }
  }
  final List<String> _professions = [
    'Plumber', 'Electrician', 'Carpenter', 'Mason (bricklayer)', 'Painter',
    'Welder', 'Mechanic (automobile technician)', 'AC Technician (HVAC technician)',
    'Roofer', 'Tiler (tile installer)', 'Plasterer', 'Blacksmith',
    'Construction Laborer', 'Interior Designer', 'Glass Installer (glazier)',
    'Locksmith', 'Solar Panel Installer', 'Elevator Technician',
    'Cable Technician (internet/TV wiring)'
  ];
  final Map<String, int> _selectedWorkers = {};
  bool _isLoading = false;
  double? _contractorLat;
  double? _contractorLng;

  @override
  void initState() {
    super.initState();
    _fetchContractorName();
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
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set both start and end working times'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Perform AI Smart Dispatch Scan
      final List<String> targetedWorkerIds = await RecommendationEngine.identifyMatchingWorkers(
        requiredWorkers: _selectedWorkers,
        district: "", // Removed district field
        contractorLat: _contractorLat,
        contractorLng: _contractorLng,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final jobDocRef = await FirebaseFirestore.instance.collection('jobs').add({
        'contractorId': uid,
        'jobName': _jobNameController.text.trim(),
        'contractorName': _contractorNameController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
        'address': _addressController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'startTime': _startTime!.format(context),
        'endTime': _endTime!.format(context),
        'contractorMessage': _messageController.text.trim(),
        'requiredWorkers': _selectedWorkers,
        'acceptedWorkers': _selectedWorkers.map((key, value) => MapEntry(key, [])),
        'targetedWorkerIds': targetedWorkerIds, // Targeted dispatch
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Broadcast message to targeted workers
      final String companyName = _contractorNameController.text.trim().isNotEmpty ? _contractorNameController.text.trim() : 'A Contractor';
      for (String workerId in targetedWorkerIds) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'recipientId': workerId,
          'senderId': uid,
          'senderName': companyName,
          'type': 'job_invitation',
          'title': 'New Job: ${_jobNameController.text.trim()}',
          'message': _messageController.text.trim().isNotEmpty 
              ? _messageController.text.trim()
              : 'You have a new job invitation. Tap to view details.',
          'jobId': jobDocRef.id,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job posted successfully!'), backgroundColor: Colors.green),
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
        title: const Text('Post Job', style: TextStyle(color: Color(0xFF5D1212), fontWeight: FontWeight.bold, fontSize: 24)),
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
              _buildTextField(_jobNameController, 'Job Name'),
              _buildTextField(_contractorNameController, 'Contractor Name'),
              _buildTextField(_phoneNumberController, 'Phone Number', keyboardType: TextInputType.phone),
              _buildTextField(_addressController, 'Construction Address', maxLines: 2),
              
              const SizedBox(height: 16),
              const Text('Working Hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F3A40))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, true),
                      child: _buildTimeInput('Start Time', _startTimeController),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(context, false),
                      child: _buildTimeInput('End Time', _endTimeController),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
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
              _buildTextField(_messageController, 'Message to Workers (Optional)', maxLines: 3),
              const SizedBox(height: 24),
              if (_selectedWorkers.isNotEmpty) ...[
                const Text('Selected Workers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                ..._selectedWorkers.entries.map((entry) => _buildWorkerCounter(entry.key, entry.value)),
                const SizedBox(height: 24),
              ],

              const Text('Select Professions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _professions.map((prof) => FilterChip(
                  label: Text(prof),
                  selected: _selectedWorkers.containsKey(prof),
                  onSelected: (_) => _toggleProfession(prof),
                  selectedColor: const Color(0xFF7CB9B3).withOpacity(0.5),
                  checkmarkColor: const Color(0xFF0F3A40),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                )).toList(),
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
                    : const Text('Post Job', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
        validator: (value) => (label.contains('Optional')) ? null : (value == null || value.isEmpty ? 'Required field' : null),
      ),
    );
  }

  Widget _buildTimeInput(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: false,
          decoration: InputDecoration(
            hintText: 'Select Time',
            prefixIcon: const Icon(Icons.access_time, size: 20, color: Color(0xFF0F3A40)),
            filled: true,
            fillColor: Colors.grey.shade50,
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
      ],
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
