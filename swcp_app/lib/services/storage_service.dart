import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Uploads a profile image and returns its download URL.
  /// Also updates the Firestore document for the user.
  Future<String?> uploadProfileImage(File imageFile, String uid) async {
    try {
      // Create a reference to the location you want to upload to in firebase storage
      Reference ref = _storage.ref().child('profile_images').child('$uid.jpg');

      // Upload the file
      UploadTask uploadTask = ref.putFile(imageFile);

      // Wait for the upload to complete and get the download URL
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with the new image URL
      await _firestore.collection('users').doc(uid).update({
        'profileImageUrl': downloadUrl,
      });

      return downloadUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }
}
