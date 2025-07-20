import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:startup/aboutuser.dart';
import 'package:startup/homepage.dart';

class VerifyOtp extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  

  const VerifyOtp({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  State<VerifyOtp> createState() => _VerifyOtpState();
}

class _VerifyOtpState extends State<VerifyOtp> {
  final TextEditingController otpController = TextEditingController();
  bool showError = false;
  
  void verifyOTP() async {
    if (otpController.text.trim().length == 6) {
      try {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: otpController.text.trim(),
        );

        await FirebaseAuth.instance.signInWithCredential(credential);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RecommendationScreen(userId: "ehooo",)),
        );
      } catch (e) {
        setState(() => showError = true);
        print('OTP verification error: $e');
      }
    } else {
      setState(() => showError = true);
    }
  }

  String maskPhone(String number) {
    String digits = number.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12) digits = digits.substring(2); // remove +91
    if (digits.length != 10) return number;
    return '+91 ${digits.replaceRange(2, 7, '*****')}';
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 56,
      textStyle: const TextStyle(fontSize: 17, color: Colors.amber, fontFamily: 'Poppins_Regular'),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          const SizedBox(height: 150),
          const Text(
            'OTP SENT',
            style: TextStyle(fontSize: 20, color: Colors.amber, fontFamily: 'Poppins_Regular', letterSpacing: 2.3),
          ),
          const SizedBox(height: 12),
          Text(
            'A verification code has been sent on',
            style: TextStyle(fontSize: 16, color: Colors.amber[300], fontFamily: 'Poppins_Regular'),
          ),
          const SizedBox(height: 10),
          Text(
            maskPhone(widget.phoneNumber),
            style: const TextStyle(fontSize: 16, color: Colors.amber, fontFamily: 'Poppins_Regular'),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Pinput(
                  length: 6,
                  controller: otpController,
                  defaultPinTheme: defaultPinTheme,

                  focusedPinTheme: defaultPinTheme.copyWith(
                    decoration: defaultPinTheme.decoration!.copyWith(
                      border: Border.all(color: Colors.amber),
                      
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Visibility(
                  visible: showError,
                  child: const Text(
                    'please enter a valid 6-digit OTP',
                    style: TextStyle(color: Colors.red, fontSize: 14, fontFamily: 'Poppins_Regular'),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: verifyOTP,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent[400]),
            child: const Text("CONFIRM OTP", style: TextStyle(color: Colors.black, fontFamily: 'Poppins_Regular',
            letterSpacing: 2.3)),
          ),
        ],
      ),
    );
  }
}
