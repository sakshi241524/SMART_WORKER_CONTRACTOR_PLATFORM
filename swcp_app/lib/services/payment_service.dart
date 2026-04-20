import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  static final PaymentService instance = PaymentService._();
  PaymentService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Releases payment for a specific worker on a specific job
  Future<void> releasePayment({
    required String jobId,
    required String workerId,
    required double amount,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final jobDoc = await transaction.get(_firestore.collection('jobs').doc(jobId));
        final workerDoc = await transaction.get(_firestore.collection('users').doc(workerId));

        if (!jobDoc.exists) throw "Job not found";
        if (!workerDoc.exists) throw "Worker not found";

        final jobData = jobDoc.data() as Map<String, dynamic>;
        final Map<String, dynamic> releasedPayments = Map<String, dynamic>.from(jobData['releasedPayments'] ?? {});
        
        if (releasedPayments.containsKey(workerId)) {
          throw "Payment already released for this worker";
        }

        // 1. Update Worker's Wallet
        final double currentBalance = (workerDoc.data()?['walletBalance'] ?? 0.0).toDouble();
        transaction.update(_firestore.collection('users').doc(workerId), {
          'walletBalance': currentBalance + amount,
        });

        // 2. Mark payment as released in Job
        releasedPayments[workerId] = {
          'amount': amount,
          'releasedAt': FieldValue.serverTimestamp(),
        };
        transaction.update(_firestore.collection('jobs').doc(jobId), {
          'releasedPayments': releasedPayments,
        });

        // 3. Log transaction
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'jobId': jobId,
          'workerId': workerId,
          'contractorId': FirebaseAuth.instance.currentUser?.uid,
          'amount': amount,
          'type': 'payout',
          'status': 'completed',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the wallet data for the current user
  Stream<DocumentSnapshot> getWalletStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore.collection('users').doc(uid).snapshots();
  }

  /// Fetches transaction history for the user
  Stream<QuerySnapshot> getTransactionsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _firestore.collection('transactions')
        .where('workerId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Updates the payment details for the current user
  Future<void> updatePaymentDetails({
    required String upiId,
    required String accountNumber,
    required String ifscCode,
    required String accountHolderName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw "User not logged in";

    try {
      await _firestore.collection('users').doc(uid).update({
        'paymentDetails': {
          'upiId': upiId,
          'accountNumber': accountNumber,
          'ifscCode': ifscCode,
          'accountHolderName': accountHolderName,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Gets the payment details for the current user
  Future<Map<String, dynamic>?> getPaymentDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    return (doc.data() as Map<String, dynamic>?)?['paymentDetails'];
  }

  /// Resets the wallet balance and clears transactions (Debug Only)
  Future<void> resetWallet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw "User not logged in";

    try {
      final batch = _firestore.batch();
      
      // 1. Reset balance
      batch.update(_firestore.collection('users').doc(uid), {'walletBalance': 0.0});

      // 2. Delete transactions
      final transDocs = await _firestore.collection('transactions')
          .where('workerId', isEqualTo: uid)
          .get();
      
      for (var doc in transDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Requests a withdrawal from the wallet
  Future<void> requestWithdrawal({
    required double amount,
    required String upiId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw "User not logged in";

    try {
      await _firestore.runTransaction((transaction) async {
        final userDocRef = _firestore.collection('users').doc(uid);
        final userDoc = await transaction.get(userDocRef);

        if (!userDoc.exists) throw "User not found";

        final double currentBalance = (userDoc.data()?['walletBalance'] ?? 0.0).toDouble();

        if (amount > currentBalance) {
          throw "Insufficient balance. Yours: ₹${currentBalance.toStringAsFixed(0)}";
        }

        if (amount <= 0) {
          throw "Invalid amount";
        }

        // 1. Deduct from wallet
        transaction.update(userDocRef, {
          'walletBalance': currentBalance - amount,
        });

        // 2. Create withdrawal request for admin
        final requestId = _firestore.collection('withdrawal_requests').doc().id;
        transaction.set(_firestore.collection('withdrawal_requests').doc(requestId), {
          'id': requestId,
          'workerId': uid,
          'workerName': userDoc.data()?['name'] ?? 'Worker',
          'amount': amount,
          'upiId': upiId,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Log transaction
        final transactionRef = _firestore.collection('transactions').doc();
        transaction.set(transactionRef, {
          'requestId': requestId,
          'workerId': uid,
          'amount': amount,
          'type': 'withdrawal',
          'status': 'pending',
          'upiId': upiId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      rethrow;
    }
  }
}
