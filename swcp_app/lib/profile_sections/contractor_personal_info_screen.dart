import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  _buildAddressField(),
                  const SizedBox(height: 15),
                  _buildTextField("Education", _educationController, Icons.school),
                  const SizedBox(height: 15),
                  _buildDatePickerField(),
                  const SizedBox(height: 15),
                  _buildTextField("Temporary Address", _tempAddrController, Icons.home_outlined, maxLines: 2),
                  const SizedBox(height: 15),
                  _buildTextField("Permanent Address", _permAddrController, Icons.location_on_outlined, maxLines: 2),
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

  Widget _buildAddressField() {
    return Column(
      children: [
        TextFormField(
          controller: _addressController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: "Address",
            prefixIcon: const Icon(Icons.map_outlined, color: Color(0xFF0F3A40)),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.my_location, color: Colors.blue),
                  onPressed: _getCurrentLocation,
                  tooltip: "Fetch current location",
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, color: Colors.green),
                  onPressed: _openMap,
                  tooltip: "View on Map",
                ),
              ],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return "Please enter Address";
            return null;
          },
        ),
        const SizedBox(height: 5),
        const Text("Use GPS icon to fetch address, or Map icon to visualize it", style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontStyle: FontStyle.italic)),
      ],
    );
  }
}
