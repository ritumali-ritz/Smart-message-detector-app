import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> submitFeedback({
    required int rating,
    required String comment,
    required String name,
    required String email,
  }) async {
    try {
      final user = _auth.currentUser;
      await _firestore.collection('feedback').add({
        'rating': rating,
        'comment': comment,
        'name': name,
        'email': email,
        'userId': user?.uid ?? 'anonymous',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
}
