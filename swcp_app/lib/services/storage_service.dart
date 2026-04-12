import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadResult {
  final bool success;
  final String? downloadUrl; // Now stores the Base64 data string
  final String? error;

  UploadResult({required this.success, this.downloadUrl, this.error});
}

class StorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Converts an image to a Base64 string and saves it to Firestore.
  /// This bypasses the need for Firebase Storage billing.
  Future<UploadResult> uploadProfileImage(File imageFile, String uid) async {
    try {
      print('Starting Base64 conversion for UID: $uid');
      
      // Read file into bytes
      final Uint8List bytes = await imageFile.readAsBytes();
      
      // Check size (Firestore limit is 1MB, but we should stay lower for performance)
      if (bytes.length > 800 * 1024) {
        return UploadResult(success: false, error: 'Image is too large. Please select a smaller photo (under 800KB).');
      }
      
      // Convert to Base64
      String base64String = base64Encode(bytes);
      String dataUrl = 'data:image/jpeg;base64,$base64String';
      
      print('Conversion completed. Data size: ${dataUrl.length} characters');

      // Update Firestore with the Base64 data string
      await _firestore.collection('users').doc(uid).update({
        'profileImageUrl': dataUrl,
      });

      return UploadResult(success: true, downloadUrl: dataUrl);
    } catch (e) {
      print('Error saving profile image to database: $e');
      return UploadResult(success: false, error: e.toString());
    }
  }
}
