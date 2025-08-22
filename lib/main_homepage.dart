import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/home.dart';

class MainHomepage extends StatefulWidget {
  final String uid;
  final String username;
  final String firstName;
  final String lastName;
  final String email;

  const MainHomepage({super.key, required this.uid, required this.username, required this.firstName, required this.lastName, required this.email});

  @override
  State<MainHomepage> createState() => _MainHomepageState();
}

class _MainHomepageState extends State<MainHomepage> {
  bool _isReady = false;
  String? username;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    username = userDoc.data()?['username'];

    setState(() {
      _isReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isReady
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Home(
              username: widget.username, 
              uid: widget.uid, 
              email: widget.email,
              firstName: widget.firstName,
              lastName: widget.lastName,
            ),
    );
  }
}