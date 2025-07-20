import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:startup/aboutuser.dart';
import 'package:startup/homepage.dart';
import 'package:startup/verify_otp.dart';

class PhoneMailVerify extends StatefulWidget {
  const PhoneMailVerify({super.key});

  @override
  State<PhoneMailVerify> createState() => PhoneMailVerifyState();
}

class PhoneMailVerifyState extends State<PhoneMailVerify> {
  final TextEditingController phoneController = TextEditingController();
  bool showError = false;

  void sendOTP() async {
    String phoneNumber = '+91${phoneController.text.trim()}';

    if (phoneController.text.trim().length == 10) {
      setState(() => showError = false);

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) {},
        verificationFailed: (FirebaseAuthException ex) {
          print('Verification failed: ${ex.message}');
        },
        codeSent: (String verificationId, int? resendToken) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyOtp(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } else {
      setState(() => showError = true);
    }
  }

  Future<bool> login() async{
    await GoogleSignIn().signOut();
      final user = await GoogleSignIn().signIn();
      GoogleSignInAuthentication userAuth = await user!.authentication;

      var credential = GoogleAuthProvider.credential(idToken: userAuth.idToken, accessToken: userAuth.accessToken);

      FirebaseAuth.instance.signInWithCredential(credential);

      return FirebaseAuth.instance.currentUser != null;

      
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.amber[300],
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              background: Container(color: Colors.amber[400]),
              title: const Text(
                'verify',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 25,
                  fontFamily: 'DMSerif',
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 25),
              child: Center(
                child: Text(
                  'AUTHENTICATE VIA PHONE',
                  style: TextStyle(
                    fontFamily: 'Poppins_Medium',
                    fontSize: 14,
                    letterSpacing: 2.0,
                    color: Colors.white38,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 35, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IntlPhoneField(
                    controller: phoneController,
                    cursorColor: Colors.yellowAccent,
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontFamily: 'Poppins_Regular',
                      fontSize: 14,
                    ),
                    
                    decoration: InputDecoration(
                      errorStyle: TextStyle(
                        fontFamily: 'Poppins_Regular'
                      ),
                      labelText: 'phone number',
                      labelStyle: const TextStyle(
                        fontFamily: 'Poppins_Regular',
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.amber),
                      ),
                      fillColor: Colors.grey[900],
                      filled: true,
                    ),
                    
                    initialCountryCode: 'IN',
                    dropdownTextStyle: const TextStyle(color: Colors.white38),
                    onChanged: (phone) {
                      if (phone.completeNumber.length > 0) {
                        setState(() => showError = false);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Visibility(
                    visible: showError,
                    child: const Text(
                      'please enter a valid 10-digit phone number',
                      style: TextStyle(
                        color: Colors.red,
                        fontFamily: 'Poppins_Regular',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 10),
              child: ElevatedButton(
                onPressed: sendOTP,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent[400]),
                child:
                    const Text("GET OTP", style: TextStyle(color: Colors.black,
                    fontFamily: 'Poppins_Regular',
                    letterSpacing: 2.3)),
              ),
            ),
          ),


          SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsetsGeometry.all(40.0),
                child: Row(
                  children: [
                    Expanded(child: Divider(
                      thickness: 0.5, color: Colors.grey[400], endIndent: 8,
                    )),
                
                    Text('OR', style: TextStyle(
                      color: Colors.grey[400],
                      letterSpacing: 1.5,
                      fontFamily: 'Poppins_Regular'
                    ),),
                
                    Expanded(child: Divider(
                      thickness: 0.5, color: Colors.grey[400],indent: 8,
                    )),
                  ],
                ),
              ),
          ),

          // SliverToBoxAdapter(
          //   child: Padding(
          //     padding: const EdgeInsets.only(top: 0, bottom: 20),
          //     child: Center(
          //       child: Text(
          //         'AUTHENTICATE VIA GOOGLE',
          //         style: TextStyle(
          //           fontFamily: 'Poppins_Medium',
          //           fontSize: 14,
          //           letterSpacing: 2.0,
          //           color: Colors.white38,
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          SliverToBoxAdapter(
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      GestureDetector(
        onTap: () async {
          bool? user = await login(); // Call your login function here
          if (user == null) {
            print('Google Sign-In cancelled or failed');
            return;
          }
          // No navigation needed — AuthGate handles it
        },
        child: Container(
          padding: EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black54),
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[900],
          ),
          child: Image.asset('icons/google.png', height: 40, width: 40,),
        ),
      ),
    ],
  ),
),


  //         SliverToBoxAdapter(
  //           child: Padding(
  //             padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
  //             child: ElevatedButton(
  //               onPressed: () async {
  // bool user = await login();
  // if (user == null) {
  //   print('Google Sign-In cancelled or failed');
  //   return;
  // }
  // // NO navigation here - AuthGate will handle routing on auth state change
  //               },
  //               style: ElevatedButton.styleFrom(    
  //                   backgroundColor: Colors.amberAccent[400]
  //                   ),
  //               child: const Text("SIGN IN WITH GOOGLE",
  //                   style: TextStyle(color: Colors.black,
  //                   fontFamily: 'Poppins_Regular',
  //                   letterSpacing: 2.3
  //                   )),
  //             ),
  //           ),
  //         ),
        ],
      ),
    );
  }
}
