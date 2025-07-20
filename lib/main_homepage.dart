import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/chaos/tender_tabs.dart';
import 'package:startup/events/events_option.dart';
import 'package:startup/groups.dart/groupscreen.dart';
import 'package:startup/home_components/bottom_nav_bar.dart';
import 'package:startup/home_components/home.dart';
import 'package:startup/chaos/tender_screen.dart';

class MainHomepage extends StatefulWidget {
  final String uid;
  final String username;
  final String firstName;
  final String lastName;

  const MainHomepage({super.key, required this.uid, required this.username, required this.firstName, required this.lastName});

  @override
  State<MainHomepage> createState() => _MainHomepageState();
}

class _MainHomepageState extends State<MainHomepage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  bool _isReady = false;
  String? username;

  @override
  void initState() {
    super.initState();
    _initializePages();
  }

  Future<void> _initializePages() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    username = userDoc.data()?['username'];

    _pages = [
      Home(username: widget.username, uid: widget.uid, ),
      GroupScreen(username: widget.username, uid: widget.uid,),
      TenderTabsScreen(),
      ChooseEventScreen(username:widget.username, uid:widget.uid, firstName:widget.firstName, lastName:widget.lastName)
      // Add other pages like Explore, Profile, etc.
    ];

    setState(() {
      _isReady = true;
    });
  }

  void navigateBottomBar(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_isReady
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _pages[_selectedIndex],
      bottomNavigationBar: _isReady
          ? SafeArea(
              top: false,
              child: BottomNavBar(onTabChange: navigateBottomBar),
            )
          : null,
    );
  }
}
