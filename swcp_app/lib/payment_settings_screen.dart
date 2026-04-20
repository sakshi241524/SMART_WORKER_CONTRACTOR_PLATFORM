import 'package:flutter/material.dart';
import 'package:swcp_app/services/payment_service.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final details = await PaymentService.instance.getPaymentDetails();
    if (details != null) {
      _upiController.text = details['upiId'] ?? '';
      _accountController.text = details['accountNumber'] ?? '';
      _ifscController.text = details['ifscCode'] ?? '';
      _nameController.text = details['accountHolderName'] ?? '';
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await PaymentService.instance.updatePaymentDetails(
        upiId: _upiController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifscCode: _ifscController.text.trim(),
        accountHolderName: _nameController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Payment details saved successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: const Text('Payment Settings', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F3A40))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F3A40)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Withdrawal Method',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F3A40)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Provide your bank or UPI details where you would like to receive your earnings.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // UPI Section
                  _buildSectionHeader('UPI Details'),
                  _buildTextField(
                    controller: _upiController,
                    label: 'UPI ID',
                    hint: 'example@okaxis',
                    icon: Icons.alternate_email,
                  ),
                  const SizedBox(height: 24),

                  // Bank Section
                  _buildSectionHeader('Bank Account Details'),
                  _buildTextField(
                    controller: _nameController,
                    label: 'Account Holder Name',
                    hint: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _accountController,
                    label: 'Account Number',
                    hint: '0000 0000 0000 0000',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _ifscController,
                    label: 'IFSC Code',
                    hint: 'SBIN0012345',
                    icon: Icons.code,
                  ),
                  
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveDetails,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F3A40),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF0F3A40).withOpacity(0.5)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
