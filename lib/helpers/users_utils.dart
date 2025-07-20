import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<String?> getOrFetchUsername() async {
  final prefs = await SharedPreferences.getInstance();
  final storedUsername = prefs.getString('username');

  if (storedUsername != null && storedUsername.isNotEmpty) {
    return storedUsername;
  }

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final fetchedUsername = doc.data()?['username'];
      if (fetchedUsername != null && fetchedUsername is String) {
        await prefs.setString('username', fetchedUsername);
        return fetchedUsername;
      }
    } catch (e) {
      print("🔥 Error fetching username from Firestore: $e");
    }
  }

  return null;
}
