import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const List<String> EASY_WORDS = [
  "CAT", "COT", "DOT", "DOG", "LOG", "LAG", "LAD", "BAD", "BAT", "BOT",
  "BOY", "TOY", "TRY", "TRI", "TOP", "TIP", "SIP", "SIT", "SAT", "MAT",
  "MAN", "PAN", "PEN", "PIN", "PIT", "BIT", "BIG", "BUG", "RUG", "RUN"
];

const List<List<String>> EASY_LADDERS = [
  ["CAT", "DOG"], ["MAN", "BIT"], ["BOY", "TRY"], ["PAN", "RUN"],
  ["TOP", "SIP"], ["TIP", "BIG"], ["SAT", "RUG"],
  ["LAD", "PEN"], ["COT", "PIT"]
];

const List<String> HARD_VALID_WORDS = [
  "COLD", "CORD", "CARD", "WARD", "WARM", "WOOD", "GOOD", "GOLD", "GOAD", "LOAD",
  "MOOD", "FOOD", "FOLD", "FARM", "FORM", "FOAM", "ROAM", "ROAD", "READ", "REAL",
  "BOMB", "BOOM", "ROOM", "ZOOM", "ZING", "KING", "SING", "PING", "DING", "FINE",
  "FIND", "MIND", "WIND", "WINE", "LINE", "LIKE", "BIKE", "HIKE", "MAKE", "TAKE",
  "BAKE", "CAKE", "FATE", "DATE", "MATE", "RATE", "LATE", "GATE", "HATE", "LOVE",
  "MOVE", "DOVE", "DIVE", "LIVE", "GIVE", "NODE", "CODE", "MODE", "RODE", "LICK",
  "PICK", "PACK", "BACK", "BARK", "BARD"
];

const List<List<String>> HARD_LADDERS = [
  ["COLD", "WARM"], ["FOOD", "BARK"], ["CORD", "READ"], ["ROOM", "PING"],
  ["LOAD", "FATE"], ["FIND", "DOVE"], ["LOVE", "CODE"], ["WOOD", "GATE"],
  ["MODE", "HIKE"], ["MAKE", "WIND"]
];

void main() => runApp(const WordLadderApp());

class WordLadderApp extends StatelessWidget {
  const WordLadderApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Ladder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const WordLadderHome(),
    );
  }
}

class WordLadderHome extends StatefulWidget {
  const WordLadderHome({super.key});
  @override
  State<WordLadderHome> createState() => _WordLadderHomeState();
}

class _WordLadderHomeState extends State<WordLadderHome> {
  List<String> currentLadder = [];
  List<String> guessedWords = [];
  bool isEasy = true;

  @override
  void initState() {
    super.initState();
    loadNewLadder();
  }

  void loadNewLadder() {
    final ladderList = isEasy ? EASY_LADDERS : HARD_LADDERS;
    final selectedLadder = ladderList[Random().nextInt(ladderList.length)];
    currentLadder = selectedLadder;
    guessedWords = [selectedLadder.first];
  }

  void onGuess(String guess) {
    setState(() {
      if ((isEasy ? EASY_WORDS : HARD_VALID_WORDS).contains(guess) &&
          guess.length == currentLadder.first.length) {
        guessedWords.add(guess);
      }
    });
  }

  Widget buildWordTile(String word, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: isCurrent
                    ? [Colors.amber.shade700, Colors.orangeAccent.shade400]
                    : [Colors.black.withOpacity(0.4), Colors.grey.withOpacity(0.2)],
              ),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Text(
              word,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                shadows: isCurrent
                    ? [const Shadow(color: Colors.amber, blurRadius: 10)]
                    : [],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validWords = isEasy ? EASY_WORDS : HARD_VALID_WORDS;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🧠 Word Ladder"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                loadNewLadder();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert_circle_outlined),
            onPressed: () {
              setState(() {
                isEasy = !isEasy;
                loadNewLadder();
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Text(
              "Start: ${currentLadder.first} → End: ${currentLadder.last}",
              style: const TextStyle(
                fontSize: 18,
                color: Colors.amberAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.white10),
            Expanded(
              child: ListView.builder(
                itemCount: guessedWords.length,
                itemBuilder: (_, index) {
                  final word = guessedWords[index];
                  final isCurrent = index == guessedWords.length - 1;
                  return buildWordTile(word, isCurrent);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              onSubmitted: onGuess,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                hintText: "Enter next word...",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: validWords.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, index) {
                  return Chip(
                    label: Text(
                      validWords[index],
                      style: const TextStyle(color: Colors.black),
                    ),
                    backgroundColor: Colors.amber.shade300,
                    elevation: 4,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
