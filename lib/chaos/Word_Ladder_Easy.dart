// Dart (Flutter) version of 3-letter Word Ladder Game

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(WordLadderApp3());

class WordLadderApp3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WordLadderGame(),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
    );
  }
}

class WordLadderGame extends StatefulWidget {
  @override
  _WordLadderGameState createState() => _WordLadderGameState();
}

class _WordLadderGameState extends State<WordLadderGame> {
  final validWords = Set<String>.from([
    "CAT", "COT", "CUT", "CUP", "CAP", "CAR", "BAR", "BAT", "BAD", "BED",
    "BIG", "DOG", "DOT", "HOT", "HIT", "HAT", "HOP", "HIP", "TIP", "TOP",
    "POT", "PIT", "PAN", "MAN", "MAP", "NAP", "NIP", "NET", "PET", "PEN",
    "TEN", "TIN", "WIN", "WET", "JET", "GET", "GOT", "ROD", "RED", "RAT",
    "RUN", "FUN", "FIN", "FIG", "FAT", "FAN", "BAN", "BUN", "BAG", "BUG",
    "MUG", "MOP", "COP", "COG", "LOG"
  ]);

  final hardLadders = [
    ["CAT", "DOG"], ["PAN", "FUN"], ["BED", "RED"], ["HAT", "TOP"],
    ["MAN", "TIN"], ["PET", "RAT"], ["CUP", "LOG"], ["HIP", "GET"],
    ["BAT", "RUN"], ["MAP", "JET"]
  ];

  String currentWord = "";
  String targetWord = "";
  List<String> path = [];
  Stopwatch stopwatch = Stopwatch();
  Timer? timer;
  String elapsedTime = "Time: 0 seconds";

  final TextEditingController inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _startGame();
    timer = Timer.periodic(Duration(seconds: 1), (_) => _updateTime());
  }

  void _startGame() {
    final pair = hardLadders[Random().nextInt(hardLadders.length)];
    currentWord = pair[0];
    targetWord = pair[1];
    path = [currentWord];
    inputController.clear();
    stopwatch.reset();
    stopwatch.start();
    setState(() {});
  }

  void _updateTime() {
    setState(() {
      elapsedTime = "Time: ${stopwatch.elapsed.inSeconds} seconds";
    });
  }

  void _submitWord() {
    String next = inputController.text.trim().toUpperCase();
    if (next.length != 3 || !validWords.contains(next) || path.contains(next)) {
      _showMessage("Invalid Move", "Word must:\n- Be 3 letters\n- Exist in dictionary\n- Change exactly 1 letter\n- Not repeat");
      return;
    }

    int differences = 0;
    for (int i = 0; i < 3; i++) {
      if (currentWord[i] != next[i]) differences++;
    }
    if (differences != 1) {
      _showMessage("Invalid Move", "Only one letter can be changed.");
      return;
    }

    path.add(next);
    currentWord = next;
    inputController.clear();
    setState(() {});

    if (currentWord == targetWord) {
      stopwatch.stop();
      _evaluatePerformance();
    }
  }

  void _evaluatePerformance() {
    final seconds = stopwatch.elapsed.inSeconds;
    String reward;
    if (seconds <= 20) reward = "🎉 You earned a 100% discount!";
    else if (seconds <= 30) reward = "🎉 You earned an 80% discount!";
    else if (seconds <= 45) reward = "🎉 You earned a 60% discount!";
    else if (seconds <= 60) reward = "🎉 You earned a 50% discount!";
    else reward = "❌ No discount. Try to be faster next time.";

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text("Result", style: TextStyle(color: Colors.white)),
        content: Text(
          "You reached $targetWord in ${path.length - 1} steps!\nTime: $seconds seconds\n$reward",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close", style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => _quitGame(),
            child: Text("Quit", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _quitGame() {
    timer?.cancel();
    Navigator.of(context).pop();
  }

  void _showMessage(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(title, style: TextStyle(color: Colors.red)),
        content: Text(msg, style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("OK", style: TextStyle(color: Colors.orange)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("3-Letter Word Ladder"),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: _quitGame,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Your goal: Reach '$targetWord' from '$currentWord'",
                style: TextStyle(color: Colors.amber, fontSize: 16)),
            SizedBox(height: 10),
            Text("Current Word: $currentWord",
                style: TextStyle(color: Colors.white, fontSize: 20)),
            SizedBox(height: 10),
            TextField(
              controller: inputController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter next word",
                hintStyle: TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.grey[900],
              ),
              onSubmitted: (_) => _submitWord(),
              textCapitalization: TextCapitalization.characters,
            ),
            SizedBox(height: 10),
            Text("Path: ${path.join(" → ")}",
                style: TextStyle(color: Colors.greenAccent)),
            SizedBox(height: 10),
            Text(elapsedTime, style: TextStyle(color: Colors.orange)),
            SizedBox(height: 20),
            Text("Valid Words:", style: TextStyle(color: Colors.tealAccent)),
            SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  validWords.join("  "),
                  style: TextStyle(color: Colors.white60, fontFamily: "Courier"),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
