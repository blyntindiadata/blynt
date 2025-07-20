import 'dart:ui';
import 'package:flutter/material.dart';
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
class FreeGamesTab extends StatefulWidget {
  const FreeGamesTab({super.key});

  @override
  State<FreeGamesTab> createState() => _FreeGamesTabState();
}

class _FreeGamesTabState extends State<FreeGamesTab> {
  final PageController _pageController = PageController();
  int selectedGameIndex = 0;

  final List<String> gameNames = ["Tap To Win", "Word Ladder", "Coming Soon"];

  void _changeGame(int index) {
    setState(() => selectedGameIndex = index);
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  Widget _buildGameChip(int index, String label) {
    final isSelected = index == selectedGameIndex;
    return GestureDetector(
      onTap: () => _changeGame(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                )
              : null,
          color: isSelected ? null : Colors.white10,
          borderRadius: BorderRadius.circular(24),
          border: isSelected
              ? null
              : Border.all(color: Colors.amber.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.black : Colors.amber,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(
              gameNames.length,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildGameChip(index, gameNames[index]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => selectedGameIndex = index),
            children: [
              const TapToWin(),
              WordLadderAppFinal(),
              const StackTheCodeGame(),
            ],
          ),
        ),
      ],
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
