import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';

class HostSuccessScreen extends StatefulWidget {
  const HostSuccessScreen({super.key});

  @override
  State<HostSuccessScreen> createState() => _HostSuccessScreenState();
}

class _HostSuccessScreenState extends State<HostSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _controller.forward();

    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _scaleAnim,
              builder: (context, child) => Transform.scale(
                scale: _scaleAnim.value,
                child: Container(
                  height: 130,
                  width: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF9B233), Color(0xFFFF8008)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8008).withOpacity(0.6),
                        blurRadius: 25,
                        spreadRadius: 3,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              "Event Hosted Successfully!",
              style: GoogleFonts.poppins(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "You're all set. We’ll let the vibe flow!",
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
