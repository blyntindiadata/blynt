import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'aboutuser.dart';
import 'phone_mail.dart';
import 'main_homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(MyApp2());
}

class MyApp2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'blynt',
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData) {
          return PhoneMailVerify();
        }

        final user = snapshot.data!;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return const Scaffold(
                body: Center(child: Text('Error loading user data')),
              );
            }

            final userDoc = userSnapshot.data;
            if (userDoc != null && userDoc.exists) {
              final data = userDoc.data() as Map<String, dynamic>;
              final username = data['username'] ?? 'unknown';
              final firstName = data['firstName'] ?? 'unknown';
              final lastName = data['lastName'] ?? 'unknown';

              return MainHomepage(
                uid: user.uid,
                username: username,
                firstName: firstName,
                lastName: lastName,
                email: user.email??'',
              );
            } else {
              return Aboutuser(
                uid: user.uid,
                email: user.email ?? '',
              );
            }
          },
        );
      },
    );
  }
}
