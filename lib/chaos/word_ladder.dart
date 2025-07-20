import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const WordLadderApp2());

class WordLadderApp2 extends StatelessWidget {
  const WordLadderApp2({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Word Ladder Challenge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const WordLadderGame(),
    );
  }
}

class WordLadderGame extends StatefulWidget {
  const WordLadderGame({super.key});

  @override
  State<WordLadderGame> createState() => _WordLadderGameState();
}

class _WordLadderGameState extends State<WordLadderGame> {
  final TextEditingController controller = TextEditingController();
  Timer? timer;
  Stopwatch stopwatch = Stopwatch();

  List<String> path = [];
  String current = "";
  String target = "";
  int seconds = 0;

  bool gameStarted = false;

  List<List<String>> wordColumns = [];
  List<List<String>> ladders = List.from(HARD_LADDERS)..shuffle();

  @override
  void initState() {
    super.initState();
    _prepareGame();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (stopwatch.isRunning) {
        setState(() {
          seconds = stopwatch.elapsed.inSeconds;
        });
      }
    });
  }

  void _prepareGame() {
    if (ladders.isEmpty) ladders = List.from(HARD_LADDERS)..shuffle();
    final pair = ladders.removeLast();
    path = [pair[0]];
    current = pair[0];
    target = pair[1];
    controller.clear();
    seconds = 0;
    stopwatch.stop();
    stopwatch.reset();
    gameStarted = false;

    final sorted = [...VALID_WORDS]..sort();
    final int perCol = (sorted.length / 4).ceil();
    wordColumns = List.generate(4, (i) => sorted.skip(i * perCol).take(perCol).toList());

    setState(() {});
  }

  void _startGameConfirmed() {
    stopwatch.start();
    gameStarted = true;
    setState(() {});
  }

  void _submitWord() {
    final input = controller.text.trim().toUpperCase();
    if (!_isValidMove(input)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("❌ Invalid move!"),
          backgroundColor: Colors.red.shade400,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    path.add(input);
    current = input;
    controller.clear();

    if (input == target && path.length >= 5) {
      stopwatch.stop();
      _evaluatePerformance();
    } else {
      setState(() {});
    }
  }

  bool _isValidMove(String next) {
    if (next.length != 4 || !VALID_WORDS.contains(next) || path.contains(next)) return false;
    if (next.length != current.length) return false;

    int diffs = 0;
    for (int i = 0; i < 4; i++) {
      if (current[i] != next[i]) diffs++;
    }
    return diffs == 1;
  }

  void _evaluatePerformance() {
    String reward;
    if (seconds <= 30) {
      reward = "🎉 100% Discount!";
    } else if (seconds <= 60) {
      reward = "🎉 50% Discount!";
    } else if (seconds <= 90) {
      reward = "🎉 10% Discount!";
    } else {
      reward = "😢 No discount. Try faster next time.";
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("🎯 Completed!", style: TextStyle(color: Colors.amber)),
        content: Text(
            "Reached '$target' in ${path.length - 1} steps.\nTime: $seconds seconds\n$reward",
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _prepareGame();
            },
            child: const Text("Play Again", style: TextStyle(color: Colors.amber)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Word Ladder", style: TextStyle(color: Colors.amber)),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _crazyStatCard(),
                const SizedBox(height: 20),
                _wordInputBox(),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("🪜 Path: ${path.join(' → ')}",
                      style: const TextStyle(color: Colors.white70)),
                ),
                const SizedBox(height: 30),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("📚 Valid Words", style: TextStyle(fontSize: 16, color: Colors.amber)),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 300,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: wordColumns.map((col) {
                      return Expanded(
                        child: ListView.builder(
                          itemCount: col.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(col[i],
                                style: const TextStyle(fontSize: 13, color: Colors.white60)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Persistent confirmation panel
          if (!gameStarted)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.shade100, blurRadius: 10, spreadRadius: 0.5)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Ready to Begin?",
                        style: TextStyle(fontSize: 18, color: Colors.amber.shade300)),
                    const SizedBox(height: 8),
                    Text("Start from '${path.first}' and reach '$target'",
                        style: const TextStyle(fontSize: 15, color: Colors.white70)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _startGameConfirmed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade400,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      ),
                      child: const Text("Confirm & Start", style: TextStyle(fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _crazyStatCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade800.withOpacity(0.25), Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade400, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Column(
        children: [
          _infoRow("🎯 Goal", target),
          const Divider(color: Colors.white24),
          _infoRow("🧩 Current", current),
          const Divider(color: Colors.white24),
          _infoRow("⏱️ Timer", "$seconds sec"),
        ],
      ),
    );
  }

  Widget _wordInputBox() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(fontSize: 20, color: Colors.amber),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Enter next word",
          hintStyle: TextStyle(color: Colors.amber.shade200),
        ),
        onSubmitted: (_) => _submitWord(),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.amber)),
        Text(value,
            style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ---- Data ----

const List<String> VALID_WORDS = [
  "COLD", "CORD", "CARD", "WARD", "WARM", "WOOD", "GOOD", "GOLD", "GOAD", "LOAD",
  "MOOD", "FOOD", "FOLD", "FARM", "FORM", "FOAM", "ROAM", "ROAD", "READ", "REAL",
  "BOMB", "BOOM", "ROOM", "ZOOM", "ZING", "KING", "SING", "PING", "DING", "FINE",
  "FIND", "MIND", "WIND", "WINE", "LINE", "LIKE", "BIKE", "HIKE", "MAKE", "TAKE",
  "BAKE", "CAKE", "FATE", "DATE", "MATE", "RATE", "LATE", "GATE", "HATE", "LOVE",
  "MOVE", "DOVE", "DIVE", "LIVE", "GIVE", "NODE", "CODE", "MODE", "RODE", "LICK",
  "PICK", "PACK", "BACK", "BARK"
];

const List<List<String>> HARD_LADDERS = [
  ["COLD", "WARM"],
  ["FOOD", "BARK"],
  ["CORD", "READ"],
  ["ROOM", "PING"],
  ["LOAD", "FATE"],
  ["FIND", "DOVE"],
  ["LOVE", "CODE"],
  ["WOOD", "GATE"],
  ["MODE", "HIKE"],
  ["MAKE", "WIND"]
];
