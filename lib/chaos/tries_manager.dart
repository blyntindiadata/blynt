import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GameTriesManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String get _uid {
  final uid = _auth.currentUser?.uid;
  print("🔥 GameTriesManager using UID: $uid");
  return uid!;
}


  static Future<int> getCurrentTries() async {
    final docRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('games')
        .doc('triesTracker');

    final doc = await docRef.get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!['triesUsed'] ?? 0;
    }
    return 0;
  }

  static Future<bool> incrementTry() async {
    final docRef = _firestore
        .collection('users')
        .doc(_uid)
        .collection('games')
        .doc('triesTracker');

    final triesUsed = await getCurrentTries();

    if (triesUsed >= 5) return false;

    await docRef.set({'triesUsed': triesUsed + 1}, SetOptions(merge: true));
    return true;
  }
}
