import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const WordLadderAppFinal());
}

class WordLadderAppFinal extends StatelessWidget {
  const WordLadderAppFinal({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const GameModeScreen(),
    );
  }
}

class GameModeScreen extends StatefulWidget {
  const GameModeScreen({super.key});

  @override
  State<GameModeScreen> createState() => _GameModeScreenState();
}

class _GameModeScreenState extends State<GameModeScreen> {
  String? selectedMode;

  @override
  void initState() {

    super.initState();
    fetchUserTries();
  }

  final List<String> easyWords = ["cat", "cot", "dot", "dog", "cog", "bat", 
    "bot", "but", "bug", "bun", "fun", "fan", "fat", "fit", "fig", "fog", 
    "log", "lag", "bag", "bog", "big", "bit", "sit", "sat", "set", "pet", 
    "pen", "pan", "man", "men", "den", "dan", "ran", "can", "car", "bar", 
    "ban", "bad", "dad", "did"];
  
  final List<String> hardWords = ["cold", "cord", "card", "ward", "warm", 
    "wood", "good", "gold", "goad", "load", "mood", "food", "fold", "farm", 
    "form", "foam", "roam", "road", "read", "real", "veal", "zeal", "zoom", 
    "room", "bomb", "boom", "boot", "boat", "coat", "goat", "moat", "meat", 
    "peat", "beat", "beta", "meta", "data", "math", "path", "bath", "back", 
    "pack", "pick", "lick", "like", "bike", "hike", "mike", "make", "bake", 
    "cake", "cane", "cone", "bone", "zone", "none", "node", "mode", "made", 
    "mace", "face", "race", "rack", "rock", "lock", "look", "book", "cook"];

  final Map<String, String> easyLadders = {"cat": "dog", "fan": "fit", 
    "bat": "but", "fog": "log", "sit": "set", "bar": "ban", "did": "dad", 
    "bag": "bit", "fat": "fun", "car": "can"};
  
final Map<String, String> hardLadders = {"cold": "warm", "wood": "farm", 
    "mood": "road", "food": "real", "bomb": "zoom", "node": "zone", 
    "make": "bike", "pack": "kick", "move": "dive"};

int userTries = 0;
bool isLoadingTries = true;

// Add this method to ensure user is signed in
// Add this method to fetch user tries
Future<void> fetchUserTries() async {
  try {
    await ensureUserSignedIn();
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc('triesTracker')
        .get();
    
    if (doc.exists && doc.data() != null) {
      final data = doc.data() as Map<String, dynamic>;
      setState(() {
        userTries = (data['triesUsed'] as int?) ?? 0;
        isLoadingTries = false;
      });
    } else {
      setState(() {
        userTries = 0;
        isLoadingTries = false;
      });
    }
  } catch (e) {
    print('Error fetching tries: $e');
    setState(() {
      isLoadingTries = false;
    });
  }
}

// Add this method to ensure user is signed in
Future<void> ensureUserSignedIn() async {
}

// Updated incrementTriesUsed with better error handling
Future<void> incrementTriesUsed() async {
  try {
    await ensureUserSignedIn();
    
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Still no user after sign-in attempt');
      return;
    }
    
    print('Using user ID: ${user.uid}');
    
    // Firestore reference instead of Realtime Database
    final DocumentReference docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc('triesTracker');
    
    print('Firestore document path: users/${user.uid}/games/triesTracker');
    
    // Use Firestore transaction to safely increment
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      
      int currentTries = 0;
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        currentTries = (data['triesUsed'] as int?) ?? 0;
        print('Current tries from Firestore: $currentTries');
      } else {
        print('No existing tries data, starting from 0');
      }
      
      final newTries = currentTries + 1;
      print('Setting tries to: $newTries');
      
      transaction.set(docRef, {
        'triesUsed': newTries,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    
    print('Successfully incremented tries to new value');
    
  } catch (e) {
    print('Error incrementing tries: $e');
    print('Error type: ${e.runtimeType}');
  }
}

void startGame() async {
  print('=== startGame() called ===');
  print('selectedMode: $selectedMode');
  print('userTries: $userTries');
  
  if (selectedMode == null) {
    print('ERROR: Cannot start game - selectedMode: $selectedMode');
    return;
  }
  
  // Start navigation immediately, don't wait for Firebase
  if (selectedMode == "gentle") {
    print('Navigating to Gentle mode');
    final entry = (easyLadders.entries.toList()..shuffle()).first;
    print('Selected entry: ${entry.key} -> ${entry.value}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordLadderGameScreen(
          title: "Gentle",
          wordLength: 3,
          validWords: easyWords,
          startWord: entry.key,
          goalWord: entry.value,
        ),
      ),
    );
  } else {
    print('Navigating to Master mode');
    final entry = (hardLadders.entries.toList()..shuffle()).first;
    print('Selected entry: ${entry.key} -> ${entry.value}');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WordLadderGameScreen(
          title: "Master",
          wordLength: 4,
          validWords: hardWords,
          startWord: entry.key,
          goalWord: entry.value,
        ),
      ),
    );
  }
  
  // Try Firebase in background after navigation
  print('Attempting to increment tries in background...');
  incrementTriesUsed().then((_) {
    print('Background Firebase call completed');
  }).catchError((error) {
    print('Background Firebase error: $error');
  });
  
  print('=== startGame() completed ===');
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 2.5,
            colors: [
              Color(0xFF2A1810),
              Color(0xFF1A1A1A), 
              Color(0xFF0A0A0A)
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
  children: [
    RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          TextSpan(
            text: "word",
            style: GoogleFonts.poppins(
              fontSize: 35,
              fontWeight: FontWeight.w900,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
              letterSpacing: 2,
            ),
          ),
          TextSpan(
            text: "ladder",
            style: GoogleFonts.poppins(
              fontSize: 35,
              fontWeight: FontWeight.w300,
              color: const Color(0xFFE5E5E5),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 8),
    Container(
      width: 100,
      height: 2,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFCD7F32)],
        ),
        borderRadius: BorderRadius.circular(1),
      ),
    ),
    const SizedBox(height: 12),
    Text(
      "show that english speaking baddie who is the goat 🐐",
      style: GoogleFonts.poppins(
       fontSize: 13,
                  color: Color(0xFF6A6A6A),
                  fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.center,
    ),
  ],
),
                const SizedBox(height: 25),
                
              Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xFF1A1A1A),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xFF2A2A2A),
      width: 1,
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Choose Your Challenge",
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFFFD700),
        ),
      ),
      const SizedBox(height: 20),
      
      _buildModeOption(
        "gentle",
        "Gentle Mode",
        "3 letter words • 20% discount",
        Icons.star_border_rounded,
        const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
        ),
      ),
      const SizedBox(height: 15),
      
      _buildModeOption(
        "master",
        "Master Mode", 
        "4 letter words • 100% discount",
        Icons.flash_on_rounded,
        const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFFB8860B)],
        ),
      ),
    ],
  ),
),
                const SizedBox(height: 30),
                
                AnimatedContainer(
  duration: const Duration(milliseconds: 400),
  width: double.infinity,
  height: selectedMode != null ? 60 : 0,
  child: selectedMode != null
      ? Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFDAA520), Color(0xFFB8860B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () {
              print('Start Challenge button pressed!');
              print('Current selectedMode: $selectedMode');
              startGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_arrow_rounded, 
                     color: Color(0xFF0A0A0A), size: 22),
                const SizedBox(width: 8),
                Text(
                  "START CHALLENGE",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    // fontWeight: FontWeight.w700,
                    color: const Color(0xFF0A0A0A),
                  ),
                ),
              ],
            ),
          ),
        )
      : const SizedBox.shrink(),
),
                const SizedBox(height: 30),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.help_outline_rounded, 
                               color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            "How to Play",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildHowToPlayItem("Transform one word into another"),
                      _buildHowToPlayItem("Change only one letter at a time"),
                      _buildHowToPlayItem("Each step must be a valid word"),
                      _buildHowToPlayItem("Complete faster for better rewards!"),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
    );
  }

Widget _buildModeOption(
  String mode,
  String title,
  String subtitle,
  IconData icon,
  LinearGradient gradient,
) {
  bool isSelected = selectedMode == mode;
  
  return GestureDetector(
    onTap: () {
      print('Mode tapped: $mode');
      setState(() {
        selectedMode = mode;
        print('selectedMode set to: $selectedMode');
      });
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2A2A2A) : const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected 
            ? const Color(0xFFFFD700)
            : const Color(0xFF333333),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: isSelected ? gradient : null,
              color: isSelected ? null : const Color(0xFF333333),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon, 
              color: Colors.white, 
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected 
                      ? const Color(0xFFFFD700) 
                      : const Color(0xFFE5E5E5),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFFB0B0B0),
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check, 
                color: Color(0xFF0A0A0A), 
                size: 16,
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildHowToPlayItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.circle, color: Colors.amber, size: 6),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WordLadderGameScreen extends StatefulWidget {
  final String title;
  final int wordLength;
  final List<String> validWords;
  final String startWord;
  final String goalWord;

  const WordLadderGameScreen({
    super.key,
    required this.title,
    required this.wordLength,
    required this.validWords,
    required this.startWord,
    required this.goalWord,
  });

  @override
  State<WordLadderGameScreen> createState() => _WordLadderGameScreenState();
}

class _WordLadderGameScreenState extends State<WordLadderGameScreen> 
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final List<String> validEnteredWords = [];
  final FocusNode _focusNode = FocusNode();
  late String currentWord;
  late String goalWord;
  String message = "";
  late Stopwatch stopwatch;
  String discount = "";
  Timer? timer;
  int elapsedSeconds = 0;
  late AnimationController _messageController;
  late Animation<double> _messageAnimation;
  bool _gameStarted = false;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    currentWord = widget.startWord.toLowerCase();
    goalWord = widget.goalWord.toLowerCase();
    stopwatch = Stopwatch()..start();
    
    _gameStarted = true;
    
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        elapsedSeconds = stopwatch.elapsed.inSeconds;
      });
    });
    
    _messageController = AnimationController(
  duration: const Duration(milliseconds: 500),
  vsync: this,
);
_messageAnimation = Tween<double>(
  begin: 0.0,
  end: 1.0,
).animate(CurvedAnimation(
  parent: _messageController,
  curve: Curves.elasticOut,
));

_confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
void dispose() {
  timer?.cancel();
  _messageController.dispose();
  _confettiController.dispose();
  _focusNode.dispose();
  _controller.dispose();
  super.dispose();
}

  bool isOneLetterDifferent(String a, String b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toLowerCase() != b[i].toLowerCase()) diff++;
    }
    return diff == 1;
  }

  void handleSubmit(String input) {
    final word = input.trim().toLowerCase();
    if (word.length != widget.wordLength || !widget.validWords.contains(word)) {
      setState(() => message = "❌ Invalid word - try again!");
      _showMessage();
      return;
    }
    if (!isOneLetterDifferent(currentWord, word)) {
      setState(() => message = "⚠️ Must change exactly one letter!");
      _showMessage();
      return;
    }
    
    setState(() {
      currentWord = word;
      validEnteredWords.add(word);
      
      if (word == goalWord) {
        stopwatch.stop();
        timer?.cancel();
        final seconds = stopwatch.elapsed.inSeconds;
        
        bool showSuccessDialog = false;
if (widget.title == "Gentle") {
  if (seconds <= 100) {
    discount = "🎉 Amazing! 20% discount earned!";
    showSuccessDialog = true;
  } else {
    discount = "🎯 Challenge completed!";
  }
} else {
  if (seconds <= 18) {
    discount = "🎉 Incredible! 100% discount earned!";
    showSuccessDialog = true;
  } else {
    discount = "🎯 Challenge completed!";
  }
}

if (showSuccessDialog) {
  _showSuccessDialog();
}
        message = "🏆 Victory! $discount";
      } else {
        message = "✨ Perfect step forward!";
      }
    });
    
    _showMessage();
  }
void _showSuccessDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return _buildSuccessDialog(discount);
    },
  );
}

  void _showMessage() {
    _messageController.forward().then((_) {
      if (!message.contains("Victory")) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _messageController.reverse();
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.amber),
          onPressed: () {
            stopwatch.stop();
            timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.title == "Gentle" ? Icons.star_border_rounded : Icons.flash_on_rounded,
                color: Colors.amber,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.title} Challenge',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
  children: [
    // Confetti
    Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirection: pi / 2,
        maxBlastForce: 5,
        minBlastForce: 2,
        emissionFrequency: 0.05,
        numberOfParticles: 50,
        gravity: 0.05,
        shouldLoop: false,
        colors: const [
          Color(0xFFFFD700),
          Color(0xFFDAA520),
          Color(0xFFB8860B),
          Color(0xFFCD7F32),
        ],
      ),
    ),
    
    // Game info
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInfoCard("Timer", "${elapsedSeconds}s", Icons.timer),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildInfoCard("Steps", "${validEnteredWords.length}", Icons.stairs),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildWordCard("Start", widget.startWord, Colors.green),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildWordCard("Goal", widget.goalWord, Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.my_location, color: Color(0xFF0A0A0A), size: 18),
                const SizedBox(width: 10),
                Text(
                  "Current: ${currentWord.toUpperCase()}",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A0A0A),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    
    // Dictionary section
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.book_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                "Available ${widget.wordLength}-Letter Words",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 120,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.validWords.map((word) {
                  bool isUsed = validEnteredWords.contains(word) || 
                               word == widget.startWord;
                  bool isCurrent = word == currentWord;
                  bool isGoal = word == widget.goalWord;
                  
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrent 
                          ? Colors.amber
                          : isGoal
                              ? Colors.red.withOpacity(0.8)
                              : isUsed
                                  ? Colors.green.withOpacity(0.3)
                                  : const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent || isGoal
                            ? Colors.white
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      word.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isCurrent
                            ? const Color(0xFF0A0A0A)
                            : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    
    // Input
    Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
          decoration: InputDecoration(
            labelText: "Enter your next word",
            labelStyle: GoogleFonts.poppins(
              color: Colors.amber,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(Icons.edit_rounded, color: Colors.amber),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFDAA520)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Color(0xFF0A0A0A)),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    handleSubmit(_controller.text);
                    _controller.clear();
                  }
                },
              ),
            ),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(16),
            ),
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: const EdgeInsets.all(20),
          ),
          onSubmitted: (value) {
            handleSubmit(value);
            _controller.clear();
          },
        ),
      ),
    ),
    const SizedBox(height: 20),
    
    // Message
    if (message.isNotEmpty)
      AnimatedBuilder(
        animation: _messageAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _messageAnimation.value,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: message.contains("Victory")
                    ? const LinearGradient(colors: [Color(0xFF228B22), Color(0xFF32CD32)])
                    : message.contains("❌") || message.contains("⚠️")
                        ? const LinearGradient(colors: [Color(0xFFDC143C), Color(0xFFB22222)])
                        : const LinearGradient(colors: [Color(0xFFDAA520), Color(0xFFCD7F32)]),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: message.contains("Victory")
                        ? Colors.green.withOpacity(0.3)
                        : Colors.amber.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      ),
    const SizedBox(height: 20),
    
    // Progress
    if (validEnteredWords.isNotEmpty)
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Your Journey",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildJourneyStep(widget.startWord, true),
                ...validEnteredWords.map((word) => _buildJourneyStep(word, false)),
              ],
            ),
          ],
        ),
      ),
  ],
),
          ),
        ),
      ),
    );
  }
Widget _buildSuccessDialog(String reward) {
  bool hasDiscount = elapsedSeconds <= (widget.title == "Gentle" ? 100 : 18);
  
  // Start confetti only if user gets discount
  if (hasDiscount) {
    _confettiController.play();
  }

 return Material(
  color: Colors.transparent,
  child: Stack(
    children: [
      // Backdrop blur
      BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: const Color(0xFF0A0A0A).withOpacity(0.4),
        ),
      ),
      
      // Main Dialog
      Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380, maxHeight: 700),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2A1810),
                Color(0xFF1A1A1A),
                Color(0xFF333333),
                Color(0xFF0A0A0A),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFCD7F32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: const Color(0xFFE6B800).withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 55,
                    color: Color(0xFF0A0A0A),
                  ),
                ),
                
                const SizedBox(height: 28),
                
                // Success Title
                Text(
                  "PUZZLE SOLVED!",
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFD700),
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Completion Time
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700).withOpacity(0.15),
                        const Color(0xFFE6B800).withOpacity(0.08),
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: Color(0xFFE5E5E5),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Completed in $elapsedSeconds seconds",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFE5E5E5),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Reward Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700).withOpacity(0.25),
                        const Color(0xFFCD7F32).withOpacity(0.15),
                        const Color(0xFFE6B800).withOpacity(0.12),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Gift Icon
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFE6B800)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Text(
                          "🎁",
                          style: TextStyle(fontSize: 28),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Reward Text
                      Text(
                        reward,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: hasDiscount ? const Color(0xFFFFD700) : const Color(0xFFE5E5E5),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Single Redeem Button
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFDAA520), Color(0xFFB8860B)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _confettiController.stop();
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      "REDEEM",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: const Color(0xFF0A0A0A),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      
      // Confetti in front of everything
      if (hasDiscount)
        Positioned.fill(
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: -pi / 2,
            blastDirectionality: BlastDirectionality.explosive,
            maxBlastForce: 25,
            minBlastForce: 10,
            emissionFrequency: 0.03,
            numberOfParticles: 60,
            gravity: 0.4,
            shouldLoop: false,
            colors: const [
              Color(0xFFFFD700),
              Color(0xFFE6B800),
              Color(0xFFB08D57),
              Color(0xFFFFC107),
            ],
          ),
        ),
    ],
  ),
);
}
  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.amber)),
              Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWordCard(String label, String word, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 10, color: color)),
          Text(word.toUpperCase(), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildJourneyStep(String word, bool isStart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: isStart
            ? const LinearGradient(colors: [Color(0xFF228B22), Color(0xFF32CD32)])
            : const LinearGradient(colors: [Color(0xFFDAA520), Color(0xFFCD7F32)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        word.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
