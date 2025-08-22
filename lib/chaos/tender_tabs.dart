import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/chaos/Word_Ladder_Easy.dart';
import 'package:startup/chaos/finalword.dart';
import 'package:startup/chaos/puzzle.dart';
// import 'package:startup/chaos/tap_to_win.dart'; // your game 1
import 'package:startup/chaos/timer.dart';
import 'package:startup/chaos/word_ladder.dart';
// import 'package:startup/chaos/word_ladder_app.dart'; // your game 2

import 'package:startup/chaos/tender_screen.dart';
import 'package:startup/chaos/word_ladder_final.dart';

class TenderTabsScreen extends StatelessWidget {
  const TenderTabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 65,
          centerTitle: true,
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              'the chaos',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.8),
                      offset: const Offset(4, 4),
                      blurRadius: 8,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.05),
                      offset: const Offset(-2, -2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amberAccent.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                  tabs: const [
                    Tab(child: Center(child: Text("TENDER"))),
                    Tab(child: Center(child: Text("FREE"))),
                    Tab(child: Center(child: Text("CANCEL"))),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: const TabBarView(
          physics: BouncingScrollPhysics(),
          children: [
            BiddingScreen(),
            FreeGamesTab(),
            CancellationScreen(),
          ],
        ),
      ),
    );
  }
}

// ✅ REPLACED: Real FreeGamesTab
class FreeGamesTab extends StatelessWidget {
  const FreeGamesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 24),
          
          // Tab selector with same styling as TenderTabsScreen
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    offset: const Offset(4, 4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    offset: const Offset(-2, -2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.black87,
                unselectedLabelColor: const Color.fromARGB(255, 161, 157, 145),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
                unselectedLabelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
                splashFactory: NoSplash.splashFactory,
                overlayColor: MaterialStateProperty.all(Colors.transparent),
                tabs: const [
                  Tab(child: Center(child: Text("THE TIMER"))),
                  Tab(child: Center(child: Text("THE LADDER"))),
                  Tab(child: Center(child: Text("THE PUZZLE"))),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // TabBarView with smooth transitions
          const Expanded(
            child: TabBarView(
              physics: BouncingScrollPhysics(),
              children: [
                TapToWin(),
                WordLadderAppFinal(),
                StackTheCodeGame(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ComingSoonPlaceholder extends StatelessWidget {
  const ComingSoonPlaceholder({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "🧩 A new game is cooking!\nStay tuned!",
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white60,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ✅ Cancellation placeholder
class CancellationScreen extends StatelessWidget {
  const CancellationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 300),
      child: Center(
        key: ValueKey('CancelScreen'),
        child: Text(
          'Cancellation Tab Content',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
