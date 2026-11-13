
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add a document to a collection
  Future<void> addDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection(collection).doc(documentId).set(data);
  }

  // Get a document from a collection
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(
    String collection,
    String documentId,
  ) async {
    return await _db.collection(collection).doc(documentId).get();
  }

  // Update an existing document
  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _db.collection(collection).doc(documentId).update(data);
  }

  // Delete a document
  Future<void> deleteDocument(
    String collection,
    String documentId,
  ) async {
    await _db.collection(collection).doc(documentId).delete();
  }
}
