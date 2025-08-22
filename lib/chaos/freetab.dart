import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/chaos/Word_Ladder_Easy.dart';
import 'package:startup/chaos/finalword.dart';
import 'package:startup/chaos/gamewrapper.dart';
import 'package:startup/chaos/puzzle.dart';
import 'package:startup/chaos/timer.dart';
import 'package:startup/chaos/tries_manager.dart';
import 'package:startup/chaos/word_ladder.dart';
import 'package:startup/chaos/word_ladder_final.dart';
// import 'package:your_app_path/tap_to_win.dart'; // Replace with actual path
// import 'package:your_app_path/word_ladder_app.dart'; // Replace with actual path

class FreeGamesTab extends StatefulWidget {
  const FreeGamesTab({super.key});

  @override
  State<FreeGamesTab> createState() => _FreeGamesTabState();
}

class _FreeGamesTabState extends State<FreeGamesTab> {
  final PageController _pageController = PageController();
  int selectedGameIndex = 0;

  final List<String> gameNames = ["Tap To Win", "Word Ladder", "The Puzzle"];

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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
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
              onPageChanged: (index) =>
                  setState(() => selectedGameIndex = index),
             children: [
  GameWrapper(child: const TapToWin()),
  GameWrapper(child: WordLadderAppFinal()),
  GameWrapper(child: const StackTheCodeGame()),
],

            ),
          ),
        ],
      ),
    );
  }
}


