/**
 * Firebase Cloud Function Example for sending Push Notifications
 * 
 * Deployment:
 * 1. Install Firebase CLI (npm install -g firebase-tools)
 * 2. Run 'firebase init functions'
 * 3. Replace index.js with this code
 * 4. Run 'firebase deploy --only functions'
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// 1. Notify on New Message
exports.onNewMessage = functions.firestore
    .document('chats/{chatId}/messages/{messageId}')
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.data();
        const chatId = context.params.chatId;
        const senderId = messageData.senderId;

        // Get chat document to find recipient
        const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
        const chatData = chatDoc.data();
        const participants = chatData.participants;
        const recipientId = participants.find(id => id !== senderId);

        if (!recipientId) return null;

        // Get recipient's FCM token
        const recipientDoc = await admin.firestore().collection('users').doc(recipientId).get();
        const fcmToken = recipientDoc.data().fcmToken;

        if (!fcmToken) return null;

        // Send Notification
        const senderName = chatData.usersData[senderId] || 'Someone';
        const payload = {
            notification: {
                title: `New message from ${senderName}`,
                body: messageData.message,
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
            data: {
                chatId: chatId,
                type: 'chat',
            }
        };

        return admin.messaging().sendToDevice(fcmToken, payload);
    });

// 2. Notify on Direct Job Offer
exports.onNewJobNotification = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snapshot, context) => {
        const data = snapshot.data();
        const receiverId = data.receiverId || data.workerId;
        
        if (!receiverId) return null;

        const receiverDoc = await admin.firestore().collection('users').doc(receiverId).get();
        const fcmToken = receiverDoc.data().fcmToken;

        if (!fcmToken) return null;

        const payload = {
            notification: {
                title: data.title,
                body: data.message,
                clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            },
            data: {
                jobId: data.jobId || '',
                type: data.type || '',
            }
        };

        return admin.messaging().sendToDevice(fcmToken, payload);
    });
