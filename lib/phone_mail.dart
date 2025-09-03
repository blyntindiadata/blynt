import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/aboutuser.dart';
import 'package:startup/homepage.dart';

class PhoneMailVerify extends StatefulWidget {
  const PhoneMailVerify({super.key});

  @override
  State<PhoneMailVerify> createState() => PhoneMailVerifyState();
}

class PhoneMailVerifyState extends State<PhoneMailVerify> with SingleTickerProviderStateMixin {
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

   @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));
    
    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> login() async {
  setState(() => isLoading = true);
  
  try {
    await GoogleSignIn().signOut();
    final user = await GoogleSignIn().signIn();
    
    if (user == null) {
      setState(() => isLoading = false);
      return false;
    }
    
    GoogleSignInAuthentication userAuth = await user.authentication;
    var credential = GoogleAuthProvider.credential(
      idToken: userAuth.idToken, 
      accessToken: userAuth.accessToken
    );

    await FirebaseAuth.instance.signInWithCredential(credential);
    
    // Add a small delay for smooth transition
    if (FirebaseAuth.instance.currentUser != null) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    return FirebaseAuth.instance.currentUser != null;
  } catch (e) {
    setState(() => isLoading = false);
    print('Google Sign-In failed: $e');
    return false;
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Color(0xFFF9B233),
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF9B233), Color(0xFFFF8008)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              title: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF101010), Color(0xFF222222)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  'verify',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 20),
              child: Center(
                child: Text(
                  'AUTHENTICATE WITH GOOGLE',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: Text(
                  'sign in or sign up to be a part of blynt',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 30),
              child: isLoading
                  ? Column(
                      children: [
                        const CircularProgressIndicator(
                          color: Colors.amber,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'one step away from paradise',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () async {
                        bool success = await login();
                        if (!success) {
                          print('Google Sign-In cancelled or failed');
                        }
                        // AuthGate handles navigation on success
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color.fromARGB(255, 233, 202, 30), Color.fromARGB(255, 159, 98, 0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amberAccent.withOpacity(0.6),
                              blurRadius: 10,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 0),
                            ),
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.2),
                              blurRadius: 4,
                              spreadRadius: 1,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'icons/google.png',
                              height: 24,
                              width: 24,
                            ),
                            const SizedBox(width: 12),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFF101010), Color(0xFF222222)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                "SIGN IN WITH GOOGLE",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 30),
              child: Row(
                children: [
                 
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: Text(
                  'by signing in, you agree to our terms of service and privacy policy',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white38,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}