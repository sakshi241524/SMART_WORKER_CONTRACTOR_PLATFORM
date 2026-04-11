import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/india_data.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = "...";
  String _email = "...";
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  // Tiered Address State
  String? _selectedState;
  String? _selectedDistrict;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _email = user.email ?? "";
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _name = data['name'] ?? "";
        _phoneController.text = data['phone'] ?? "";
        _addressController.text = data['address'] ?? "";
        _educationController.text = data['education'] ?? "";
        _dobController.text = data['dob'] ?? "";
        _selectedState = data['state'];
        _selectedDistrict = data['district'];
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }


  Future<void> _saveData() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'phone': _phoneController.text.trim(),
            'address': _addressController.text.trim(),
            'education': _educationController.text.trim(),
            'dob': _dobController.text.trim(),
            'state': _selectedState,
            'district': _selectedDistrict,
          }, SetOptions(merge: true));
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile updated successfully"), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true); // Return true to indicate update
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving data: $e"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Personal Information", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadOnlyField("Name", _name),
                  const SizedBox(height: 15),
                  _buildReadOnlyField("Email", _email),
                  const SizedBox(height: 25),
                  const Text("Editable Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 15),
                  _buildTextField("Phone Number", _phoneController, Icons.phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 15),
                  _buildTextField("Education", _educationController, Icons.school),
                  const SizedBox(height: 15),
                  _buildTextField("Birth Date", _dobController, Icons.calendar_today, hint: "DD/MM/YYYY"),
                  const SizedBox(height: 25),
                  
                  const Text("Address Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 15),
                  _buildFullAddressSummary(),
                  const SizedBox(height: 15),
                  _buildAddressField(), // Specific place and takula (Block 1)
                  const SizedBox(height: 15),
                  _buildCascadingAddressFields(), // State, District (Blocks 2, 3)
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _saveData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3A40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Save Information", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, String? hint}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF0F3A40)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return "Please enter $label";
        return null;
      },
    );
  }

  Widget _buildAddressField() {
    return Column(
      children: [
        TextFormField(
          controller: _addressController,
          maxLines: 1,
          decoration: InputDecoration(
            labelText: "Specific place and takula",
            hintText: "e.g. Near Bus Stand, Baramati",
            prefixIcon: const Icon(Icons.location_on, color: Color(0xFF0F3A40)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          onChanged: (v) => setState(() {}),
          validator: (value) {
            if (value == null || value.isEmpty) return "Please enter landmark";
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildFullAddressSummary() {
    String fullAddress = "";
    if (_addressController.text.isNotEmpty) fullAddress += "${_addressController.text}, ";
    if (_selectedDistrict != null) fullAddress += "$_selectedDistrict, ";
    if (_selectedState != null) fullAddress += _selectedState!;
    
    // Remove trailing comma/space if any
    if (fullAddress.endsWith(", ")) fullAddress = fullAddress.substring(0, fullAddress.length - 2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3A40).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0F3A40).withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Full Address Preview", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
          const SizedBox(height: 4),
          Text(
            fullAddress.isEmpty ? "Complete the fields below..." : fullAddress,
            style: TextStyle(
              fontSize: 14, 
              color: fullAddress.isEmpty ? Colors.grey : const Color(0xFF0F3A40),
              fontWeight: FontWeight.w500
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCascadingAddressFields() {
    final List<String> districts = _selectedState != null ? (indiaMapData[_selectedState] ?? []) : [];

    return Column(
      children: [
        // State Selection
        DropdownButtonFormField<String>(
          value: _selectedState,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: "Select State",
            prefixIcon: const Icon(Icons.map, color: Color(0xFF0F3A40)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: const Text("Select State"),
          items: indiaMapData.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (val) {
            setState(() {
              _selectedState = val;
              _selectedDistrict = null;
            });
          },
        ),
        const SizedBox(height: 15),

        // District Selection
        DropdownButtonFormField<String>(
          value: _selectedDistrict,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: "Select District",
            prefixIcon: const Icon(Icons.location_city, color: Color(0xFF0F3A40)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: const Text("Select District"),
          disabledHint: const Text("Select State first"),
          items: districts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: _selectedState == null ? null : (val) {
            setState(() {
              _selectedDistrict = val;
            });
          },
        ),
      ],
    );
  }
}
