import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class NotificationSenderService {
  // IMPORTANT: In a real production app, you should NOT keep your Server Key
  // in the client code. This is for demonstration and development purposes only.
  // Ideally, this should be handled by a Firebase Cloud Function.
  static const String _serverKey = 'YOUR_LEGACY_SERVER_KEY_HERE';
  static const String _fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  static Future<void> sendNotification({
    required String recipientUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. Fetch user's FCM token from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(recipientUid).get();
      final token = userDoc.data()?['fcmToken'];

      if (token == null) {
        debugPrint("FCM: No token found for user $recipientUid");
        return;
      }

      // 2. Prepare the notification payload
      final payload = {
        'to': token,
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
        'data': {
          'title': title,
          'body': body,
          ...data ?? {},
        },
        'priority': 'high',
      };

      // 3. Send the request
      if (_serverKey == 'YOUR_LEGACY_SERVER_KEY_HERE') {
        debugPrint("FCM: Skipping send - Server Key not set. Please set it in notification_sender_service.dart");
        return;
      }

      final response = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        debugPrint("FCM: Notification sent successfully to $recipientUid");
      } else {
        debugPrint("FCM: Error sending notification. Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("FCM: Exception sending notification: $e");
    }
  }
}
