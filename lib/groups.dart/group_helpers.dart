// ✅ FILE 1: group_helpers.dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<bool> doesUsernameExist(String username) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('username', isEqualTo: username)
      .limit(1)
      .get();
  return snap.docs.isNotEmpty;
}

Future<String?> getUserIdFromUsername(String username) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('username', isEqualTo: username)
      .limit(1)
      .get();
  return snap.docs.isNotEmpty ? snap.docs.first.id : null;
}

Future<String?> getUsernameFromUid(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  return doc.data()?['username'];
}

Future<String> getNextGroupId() async {
  final ref = FirebaseFirestore.instance.collection('meta').doc('groupCounter');
  final doc = await ref.get();
  int current = doc.exists ? doc.data()!['count'] ?? 0 : 0;
  await ref.set({'count': current + 1});
  return current.toString().padLeft(6, '0');
}
