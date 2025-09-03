import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

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

class _AboutuserState extends State<Aboutuser> with TickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController firstnameController = TextEditingController();
  final TextEditingController lastnameController = TextEditingController();
  final TextEditingController dayController = TextEditingController();
  final TextEditingController monthController = TextEditingController();
  final TextEditingController yearController = TextEditingController();

  final FocusNode usernameFocus = FocusNode();
  final FocusNode firstnameFocus = FocusNode();
  final FocusNode lastnameFocus = FocusNode();
  final FocusNode dayFocus = FocusNode();
  final FocusNode monthFocus = FocusNode();
  final FocusNode yearFocus = FocusNode();

  bool isInvalidDate = false;
  bool firstnameEmpty = false;
  bool lastnameEmpty = false;
  bool usernameEmpty = false;
  bool usernameTaken = false;
  bool isLoading = false;
  bool isUsernameChecking = false;
  Timer? debounceTimer;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    usernameController.addListener(_onUsernameChanged);
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    
    _fadeController.forward();
    _slideController.forward();
  }

  void _onUsernameChanged() {
    debounceTimer?.cancel();
    final username = usernameController.text.trim();
    
    if (username.isEmpty) {
      setState(() {
        usernameEmpty = true;
        usernameTaken = false;
        isUsernameChecking = false;
      });
      return;
    }
    
    setState(() {
      usernameEmpty = false;
      isUsernameChecking = true;
    });
    
    debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final taken = await isUsernameTaken(username);
      setState(() {
        usernameTaken = taken;
        isUsernameChecking = false;
      });
    });
  }

  Future<bool> isUsernameTaken(String username) async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
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

  InputDecoration buildInputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      counterText: '',
      labelText: label,
      labelStyle: GoogleFonts.poppins(
        color: Colors.grey[500],
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      suffixIcon: suffixIcon,
      fillColor: Colors.grey[900],
      filled: true,
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white12),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  @override
  void dispose() {
    debounceTimer?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    usernameController.dispose();
    firstnameController.dispose();
    lastnameController.dispose();
    dayController.dispose();
    monthController.dispose();
    yearController.dispose();
    usernameFocus.dispose();
    firstnameFocus.dispose();
    lastnameFocus.dispose();
    dayFocus.dispose();
    monthFocus.dispose();
    yearFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final horizontalPadding = isTablet ? screenSize.width * 0.2 : 24.0;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: Color(0xFFF9B233),
            expandedHeight: Platform.isIOS ? 220 : 200,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, 
                vertical: Platform.isIOS ? 16 : 10
              ),
              background: Container(
                decoration: const BoxDecoration(
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
                  'about you',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isTablet ? 28 : 25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // Introduction Text
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 20,
                  ),
                  child: Text(
                    'tell us a bit about yourself to personalize your experience',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: isTablet ? 15 : 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),

          // Username Section
          _buildUsernameSection(horizontalPadding, isTablet),

          // Name Fields
          _buildNameFields(horizontalPadding, isTablet),

          // Date of Birth
          _buildDOBFields(horizontalPadding, isTablet),

          // Continue Button
          _buildContinueButton(horizontalPadding, isTablet),

          // Bottom padding for safe area
          SliverToBoxAdapter(
            child: SizedBox(height: Platform.isIOS ? 30 : 20),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameSection(double horizontalPadding, bool isTablet) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CREATE USERNAME',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: usernameController,
                focusNode: usernameFocus,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTablet ? 16 : 14,
                ),
                cursorColor: const Color(0xFFFFD700),
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).requestFocus(firstnameFocus),
                decoration: buildInputDecoration(
                  'username',
                  suffixIcon: _buildUsernameStatusIcon(),
                ),
              ),
              if (usernameTaken || usernameEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  usernameTaken 
                    ? 'this username is already taken' 
                    : 'please enter a username',
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontSize: isTablet ? 12 : 11,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildUsernameStatusIcon() {
    if (isUsernameChecking) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.amber,
          ),
        ),
      );
    }
    
    if (usernameController.text.trim().isNotEmpty && !usernameTaken && !usernameEmpty) {
      return const Icon(
        Icons.check_circle,
        color: Colors.greenAccent,
        size: 20,
      );
    }
    
    return null;
  }

  Widget _buildNameFields(double horizontalPadding, bool isTablet) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PERSONAL DETAILS',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              
              // First Name
              TextField(
                controller: firstnameController,
                focusNode: firstnameFocus,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTablet ? 16 : 14,
                ),
                cursorColor: const Color(0xFFFFD700),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => FocusScope.of(context).requestFocus(lastnameFocus),
                decoration: buildInputDecoration('first name'),
              ),
              if (firstnameEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'please enter your first name',
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontSize: isTablet ? 12 : 11,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // Last Name
              TextField(
                controller: lastnameController,
                focusNode: lastnameFocus,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTablet ? 16 : 14,
                ),
                cursorColor: const Color(0xFFFFD700),
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => FocusScope.of(context).requestFocus(dayFocus),
                decoration: buildInputDecoration('last name'),
              ),
              if (lastnameEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'please enter your last name',
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontSize: isTablet ? 12 : 11,
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDOBFields(double horizontalPadding, bool isTablet) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DATE OF BIRTH',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 15 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  _buildDateField(
                    controller: dayController,
                    label: 'DD',
                    focus: dayFocus,
                    nextFocus: monthFocus,
                    flex: 2,
                    isTablet: isTablet,
                  ),
                  const SizedBox(width: 12),
                  _buildDateField(
                    controller: monthController,
                    label: 'MM',
                    focus: monthFocus,
                    nextFocus: yearFocus,
                    flex: 2,
                    isTablet: isTablet,
                  ),
                  const SizedBox(width: 12),
                  _buildDateField(
                    controller: yearController,
                    label: 'YYYY',
                    focus: yearFocus,
                    flex: 3,
                    isTablet: isTablet,
                  ),
                ],
              ),
              
              if (isInvalidDate) ...[
                const SizedBox(height: 8),
                Text(
                  'please enter a valid date',
                  style: GoogleFonts.poppins(
                    color: Colors.redAccent,
                    fontSize: isTablet ? 12 : 11,
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required FocusNode focus,
    FocusNode? nextFocus,
    required int flex,
    required bool isTablet,
  }) {
    return Expanded(
      flex: flex,
      child: TextField(
        controller: controller,
        focusNode: focus,
        keyboardType: TextInputType.number,
        maxLength: label == 'YYYY' ? 4 : 2,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        cursorColor: const Color(0xFFFFD700),
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: isTablet ? 18 : 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: buildInputDecoration(label),
        onChanged: (val) {
          if ((label == 'YYYY' && val.length == 4) || (label != 'YYYY' && val.length == 2)) {
            if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            } else {
              FocusScope.of(context).unfocus();
              validateDate();
            }
          }
        },
      ),
    );
  }

  Widget _buildContinueButton(double horizontalPadding, bool isTablet) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: isLoading
              ? Column(
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.amber,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'entering paradise',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  onTap: _handleContinue,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 18 : 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: _canProceed()
                          ? const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFB77200)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : const LinearGradient(
                              colors: [Colors.grey, Colors.grey],
                            ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _canProceed()
                          ? [
                              BoxShadow(
                                color: Colors.amberAccent.withOpacity(0.6),
                                blurRadius: 18,
                                spreadRadius: 1,
                                offset: const Offset(0, 0),
                              ),
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.2),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF101010), Color(0xFF222222)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          "CONTINUE",
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  bool _canProceed() {
    return usernameController.text.trim().isNotEmpty &&
           firstnameController.text.trim().isNotEmpty &&
           lastnameController.text.trim().isNotEmpty &&
           dayController.text.isNotEmpty &&
           monthController.text.isNotEmpty &&
           yearController.text.isNotEmpty &&
           !usernameTaken &&
           !isInvalidDate &&
           !isUsernameChecking;
  }

  Future<void> _handleContinue() async {
    if (!_canProceed() || isLoading) return;

    final username = usernameController.text.trim();
    final firstName = firstnameController.text.trim();
    final lastName = lastnameController.text.trim();

    setState(() {
      firstnameEmpty = firstName.isEmpty;
      lastnameEmpty = lastName.isEmpty;
      usernameEmpty = username.isEmpty;
      isLoading = true;
    });

    validateDate();

    if (usernameEmpty || firstnameEmpty || lastnameEmpty || isInvalidDate || usernameTaken) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final dob = DateTime(
        int.parse(yearController.text),
        int.parse(monthController.text),
        int.parse(dayController.text),
      );

      await storeUserData(
        uid: widget.uid,
        email: widget.email,
        username: username,
        firstName: firstName,
        lastName: lastName,
        dob: dob,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('firstName', firstName);
      await prefs.setString('lastName', lastName);

      if (mounted) {
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
      }
    } catch (e) {
      print('Error storing user data: $e');
      setState(() => isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to create profile. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}