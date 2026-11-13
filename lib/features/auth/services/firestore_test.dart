
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreTest {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> testConnection() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        debugPrint('Please login first!');
        return;
      }

      // Write test data
      await _db.collection('Users').doc(user.uid).set({
        'name': 'Firebase Test',
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Firestore write successful!');

      // Read test data
      final document =
          await _db.collection('Users').doc(user.uid).get();

      debugPrint('Firestore read successful!');
      debugPrint('Data: ${document.data()}');
    } catch (e) {
      debugPrint('Firestore connection failed: $e');
    }
  }
}
