import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/india_data.dart';

class ContractorPersonalInfoScreen extends StatefulWidget {
  const ContractorPersonalInfoScreen({super.key});

  @override
  State<ContractorPersonalInfoScreen> createState() => _ContractorPersonalInfoScreenState();
}

class _ContractorPersonalInfoScreenState extends State<ContractorPersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = "...";
  String _email = "...";
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _tempAddrController = TextEditingController();
  final TextEditingController _permAddrController = TextEditingController();

  bool _isLoading = false;
  Position? _currentPosition;

  // Tiered Address State
  String? _selectedState;
  String? _selectedDistrict;

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
        _tempAddrController.text = data['temp_address'] ?? "";
        _permAddrController.text = data['permanent_address'] ?? "";
        if (data['latitude'] != null && data['longitude'] != null) {
          _currentPosition = Position(
            latitude: data['latitude'],
            longitude: data['longitude'],
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _openMap() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter an address first")));
      return;
    }
    final query = Uri.encodeComponent(address);
    final googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$query";
    final uri = Uri.parse(googleMapsUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch Maps app")));
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _currentPosition = position;
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          String addr = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
          setState(() {
            _addressController.text = addr;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching location: $e")));
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
            'temp_address': _tempAddrController.text.trim(),
            'permanent_address': _permAddrController.text.trim(),
            'latitude': _currentPosition?.latitude,
            'longitude': _currentPosition?.longitude,
          }, SetOptions(merge: true));
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile updated successfully"), backgroundColor: Colors.green),
            );
            Navigator.pop(context, true);
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
        foregroundColor: const Color(0xFF0F3A40),
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
                  _buildReadOnlyField("Full Name", _name),
                  const SizedBox(height: 15),
                  _buildReadOnlyField("Email Address", _email),
                  const SizedBox(height: 25),
                  const Text("Contractor Profile Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
                  const SizedBox(height: 15),
                  _buildTextField("Phone Number", _phoneController, Icons.phone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 15),
                  _buildFullAddressSummary(),
                  const SizedBox(height: 15),
                  _buildAddressField(), // Specific place and takula
                  const SizedBox(height: 15),
                  _buildCascadingAddressFields(), // State, District
                  const SizedBox(height: 15),
                  _buildTextField("Education", _educationController, Icons.school),
                  const SizedBox(height: 15),
                  _buildDatePickerField(),
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
                      child: const Text("Save Changes", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
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
          child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F3A40))),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
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

  Widget _buildDatePickerField() {
    return InkWell(
      onTap: () => _selectDate(context),
      child: IgnorePointer(
        child: TextFormField(
          controller: _dobController,
          decoration: InputDecoration(
            labelText: "Birth Date",
            prefixIcon: const Icon(Icons.calendar_month, color: Color(0xFF0F3A40)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return "Please select Birth Date";
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildFullAddressSummary() {
    String fullAddress = "";
    if (_addressController.text.isNotEmpty) fullAddress += "${_addressController.text}, ";
    if (_selectedDistrict != null) fullAddress += "$_selectedDistrict, ";
    if (_selectedState != null) fullAddress += _selectedState!;
    
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
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF0F3A40)),
              SizedBox(width: 8),
              Text("Full Address Preview", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            fullAddress.isEmpty ? "Incomplete address" : fullAddress,
            style: TextStyle(color: fullAddress.isEmpty ? Colors.grey : Colors.black87),
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

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      maxLines: 1,
      decoration: InputDecoration(
        labelText: "Specific place and takula",
        hintText: "e.g. Office No 4, Baramati",
        prefixIcon: const Icon(Icons.location_on, color: Color(0xFF0F3A40)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (v) => setState(() {}),
      validator: (value) {
        if (value == null || value.isEmpty) return "Please enter address details";
        return null;
      },
    );
  }
}
