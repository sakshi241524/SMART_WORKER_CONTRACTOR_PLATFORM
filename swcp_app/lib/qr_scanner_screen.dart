import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'widgets/leave_review_dialog.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleQRScan(String code) async {
    if (_isProcessing) return;
    
    try {
      final data = jsonDecode(code);
      if (data['type'] != 'attendance' || data['jobId'] == null) {
        throw const FormatException();
      }

      setState(() {
        _isProcessing = true;
      });

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("User not logged in");

      final String jobId = data['jobId'];
      final attendanceRef = FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .collection('attendance')
          .doc(uid);

      final docSnap = await attendanceRef.get();
      
      String message = "";
      
      if (docSnap.exists) {
        final attendanceData = docSnap.data() as Map<String, dynamic>;
        if (attendanceData['clockOut'] == null) {
          // Clock out
          await attendanceRef.update({
            'clockOut': FieldValue.serverTimestamp(),
          });
          
            if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Clock-Out Successful! Job Completed."), backgroundColor: Colors.green),
            );
            Navigator.pop(context);
          }
          return;
        } else {
          message = "You have already clocked out for today.";
        }
      } else {
        // Clock in
        await attendanceRef.set({
          'clockIn': FieldValue.serverTimestamp(),
          'clockOut': null,
          'workerId': uid,
        });
        message = "Clock-In Successful!";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back after success
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (e is FormatException) {
          errorMsg = "Not a recognized Job QR code.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot scan: $errorMsg'), backgroundColor: Colors.red),
        );
      }
      // Delay before allowing another scan attempt
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR to Clock In/Out', style: TextStyle(color: Color(0xFF0F3A40), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F3A40)),
        actions: [],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleQRScan(barcode.rawValue!);
                  break; // Only process the first barcode
                }
              }
            },
          ),
          // QR overlay box
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            ),
        ],
      ),
    );
  }
}
