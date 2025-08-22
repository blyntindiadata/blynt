import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:startup/home.dart';
import 'package:startup/home_components/home.dart';
import 'package:startup/location_info.dart';
import 'package:startup/main_homepage.dart';
import 'package:startup/searchpageoutlets.dart';
import 'package:startup/signuptextfield.dart';

class Aboutuser extends StatefulWidget {
  final String uid;
  final String email;
  const Aboutuser({super.key, required this.uid, required this.email});

  @override
  State<Aboutuser> createState() => _AboutuserState();
}

class _AboutuserState extends State<Aboutuser> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  final FocusNode dayFocus = FocusNode();
  final FocusNode monthFocus = FocusNode();
  final FocusNode yearFocus = FocusNode();

  bool isInvalidDate = false;
  bool firstnameEmpty = false;
  bool lastnameEmpty = false;
  bool usernameEmpty = false;
  bool usernameTaken = false;
  Timer? debounceTimer;

  @override
  void initState() {
    super.initState();
    usernameController.addListener(_onUsernameChanged);
  }

  void _onUsernameChanged() {
    debounceTimer?.cancel();
    final username = usernameController.text.trim();
    if (username.isEmpty) {
      setState(() {
        usernameEmpty = true;
        usernameTaken = false;
      });
      return;
    }
    debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final taken = await isUsernameTaken(username);
      setState(() {
        usernameTaken = taken;
        usernameEmpty = false;
      });
    });
  }

  Future<bool> isUsernameTaken(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  void validateDate() {
    final int? day = int.tryParse(dayController.text);
    final int? month = int.tryParse(monthController.text);
    final int? year = int.tryParse(yearController.text);
    bool invalid = false;

    if (day == null || month == null || year == null) {
      invalid = true;
    } else {
      if (month < 1 || month > 12) invalid = true;
      final currentYear = DateTime.now().year;
      if (year < 1950 || year > currentYear) invalid = true;

      int maxDays = 31;
      if ([4, 6, 9, 11].contains(month)) {
        maxDays = 30;
      } else if (month == 2) {
        if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)) {
          maxDays = 29;
        } else {
          maxDays = 28;
        }
      }

      if (day < 1 || day > maxDays) invalid = true;
    }

    setState(() => isInvalidDate = invalid);
  }

  Future<void> storeUserData({
    required String uid,
    required String email,
    required String username,
    required String firstName,
    required String lastName,
    required DateTime dob,
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'dob': dob.toIso8601String(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  InputDecoration buildInputDecoration(String label) {
    return InputDecoration(
      counterText: '',
      labelText: label,
      labelStyle: const TextStyle(
        fontFamily: 'Poppins_Regular',
        letterSpacing: 1.4,
        color: Colors.white12,
        fontSize: 14,
      ),
      fillColor: Colors.grey[900],
      filled: true,
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide.none),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.amberAccent),
      ),
    );
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    usernameController.dispose();
    firstnameController.dispose();
    lastnameController.dispose();
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    dayFocus.dispose();
    monthFocus.dispose();
    yearFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorTextStyle = const TextStyle(
      color: Colors.red,
      fontFamily: 'Poppins_Regular',
      fontSize: 11,
      letterSpacing: 1.2,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.amber[300],
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              background: Container(color: Colors.amber[400]),
              title: const Text(
                'about you',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 25,
                  fontFamily: 'DMSerif',
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 35, top: 25),
              child: Text(
                'CREATE USERNAME',
                style: TextStyle(
                  fontFamily: 'Poppins_Medium',
                  fontSize: 14,
                  letterSpacing: 2.0,
                  color: Colors.white38,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SignUpTextField(
                prefixIcon: const ImageIcon(
                  AssetImage('icons/username.png'),
                  color: Colors.white12,
                ),
                controller: usernameController,
                hintText: 'username',
                obscureText: false,
                suffixIcon: (!usernameEmpty && !usernameTaken && usernameController.text.trim().isNotEmpty)
                    ? const Icon(Icons.check_circle, color: Colors.green, size: 17)
                    : null,
              ),
            ),
          ),
          if (usernameTaken)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 35, bottom: 10),
                child: Text('this username is already taken', style: errorTextStyle),
              ),
            ),

          // First & Last Name
          _buildNameFields(errorTextStyle),

          // Date of Birth
          _buildDOBFields(errorTextStyle),

          // Confirm Button
          _buildConfirmButton(),
        ],
      ),
    );
  }

  Widget _buildNameFields(TextStyle errorTextStyle) {
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SignUpTextField(
            prefixIcon: const ImageIcon(
              AssetImage('icons/first_lastname.png'),
              color: Colors.white12,
            ),
            controller: firstnameController,
            hintText: 'first name',
            obscureText: false,
          ),
        ),
        if (firstnameEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 35),
            child: Text('please enter your first name', style: errorTextStyle),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: SignUpTextField(
            prefixIcon: const ImageIcon(
              AssetImage('icons/first_lastname.png'),
              color: Colors.white12,
            ),
            controller: lastnameController,
            hintText: 'last name',
            obscureText: false,
          ),
        ),
        if (lastnameEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 35),
            child: Text('please enter your last name', style: errorTextStyle),
          ),
      ]),
    );
  }

  Widget _buildDOBFields(TextStyle errorTextStyle) {
    return SliverList(
      delegate: SliverChildListDelegate([
        const Padding(
          padding: EdgeInsets.only(left: 35, top: 25),
          child: Text(
            'DATE OF BIRTH',
            style: TextStyle(
              fontFamily: 'Poppins_Medium',
              fontSize: 14,
              letterSpacing: 2.0,
              color: Colors.white38,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
          child: Row(
            children: [
              _buildDateField(dayController, 'DD', dayFocus, monthFocus),
              const SizedBox(width: 8),
              _buildDateField(monthController, 'MM', monthFocus, yearFocus),
              const SizedBox(width: 8),
              _buildDateField(yearController, 'YYYY', yearFocus, null, flex: 2),
            ],
          ),
        ),
        if (isInvalidDate)
          Padding(
            padding: const EdgeInsets.only(left: 35),
            child: Text('invalid date', style: errorTextStyle),
          ),
      ]),
    );
  }

  Widget _buildDateField(
    TextEditingController controller,
    String label,
    FocusNode focus,
    FocusNode? nextFocus, {
    int flex = 1,
  }) {
    return Flexible(
      flex: flex,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: label == 'YYYY' ? 4 : 2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: Colors.yellowAccent,
        style: const TextStyle(color: Colors.yellow, fontFamily: 'Poppins_Regular', fontSize: 16),
        decoration: buildInputDecoration(label),
        focusNode: focus,
        onChanged: (val) {
          if ((label == 'YYYY' && val.length == 4) || (label != 'YYYY' && val.length == 2)) {
            if (nextFocus != null) FocusScope.of(context).requestFocus(nextFocus);
            else FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }

  Widget _buildConfirmButton() {
  return SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
      child: ElevatedButton(
        onPressed: () async {
          final username = usernameController.text.trim();
          final firstName = firstnameController.text.trim();
          final lastName = lastnameController.text.trim();

          setState(() {
            firstnameEmpty = firstName.isEmpty;
            lastnameEmpty = lastName.isEmpty;
            usernameEmpty = username.isEmpty;
          });

          validateDate();

          if (usernameEmpty || firstnameEmpty || lastnameEmpty || isInvalidDate || usernameTaken) return;

          final dob = DateTime(
            int.parse(yearController.text),
            int.parse(monthController.text),
            int.parse(dayController.text),
          );

          try {
            await storeUserData(
              uid: widget.uid,
              email: widget.email,
              username: username,
              firstName: firstName,
              lastName: lastName,
              dob: dob,
            );

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('username', username); // ✅ STORE USERNAME HERE
            await prefs.setString('firstName', firstName);
            await prefs.setString('lastName', lastName);

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => Home(
                  uid: widget.uid,
                  email: widget.email,
                  username: username,
                  firstName: firstName,
                  lastName: lastName,
                ),
              ),
            );
          } catch (e) {
            print('Error storing user data: $e');
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amberAccent[400],
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text(
          "CONTINUE",
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins_Regular',
            letterSpacing: 2.3,
          ),
        ),
      ),
    ),
  );
}

}
