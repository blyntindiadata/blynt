import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const WordLadderAppFinal());

class WordLadderAppFinal extends StatelessWidget {
  const WordLadderAppFinal({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A1A1A),
            elevation: 8,
            shadowColor: Colors.amber.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: const DifficultySelectionScreen(),
    );
  }
}

class DifficultySelectionScreen extends StatefulWidget {
  const DifficultySelectionScreen({super.key});

  @override
  State<DifficultySelectionScreen> createState() => _DifficultySelectionScreenState();
}

class _DifficultySelectionScreenState extends State<DifficultySelectionScreen> 
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> easyWords = [ "cat", "cot", "dot", "dog", "cog", "bat", 
      "bot", "but", "bug", "bun", "fun", "fan", "fat", "fit", "fig", "fog", 
      "log", "lag", "bag", "bog", "big", "bit", "sit", "sat", "set", "pet", 
      "pen", "pan", "man", "men", "den", "dan", "ran", "can", "car", "bar", 
      "ban", "bad", "dad", "did"];
    final List<String> hardWords = [  "cold", "cord", "card", "ward", "warm", 
      "wood", "good", "gold", "goad", "load", "mood", "food", "fold", "farm", 
      "form", "foam", "roam", "road", "read", "real", "veal", "zeal", "zoom", 
      "room", "bomb", "boom", "boot", "boat", "coat", "goat", "moat", "meat", 
      "peat", "beat", "beta", "meta", "data", "math", "path", "bath", "back", 
      "pack", "pick", "lick", "like", "bike", "hike", "mike", "make", "bake", 
      "cake", "cane", "cone", "bone", "zone", "none", "node", "mode", "made", 
      "mace", "face", "race", "rack", "rock", "lock", "look", "book", "cook", 
      "nook", "hook", "duck", "luck", "suck", "tuck", "muck", "sick", "kick", 
      "tick", "dick", "rick", "rink", "rank", "tank", "task", "mask", "bask", 
      "hack", "zack", "quad", "quit", "quiz", "quip", "zing", "king", "sing", 
      "ring", "ping", "ding", "fang", "bang", "hang", "hand", "land", "band", 
      "sand", "send", "bend", "tend", "lend", "mend", "mint", "mind", "wind", 
      "find", "fine", "fire", "wire", "tire", "dire", "dive", "live", "love", 
      "move", "give", "hive"];

    final Map<String, String> easyLadders = {"cat": "dog", "fan": "fit", 
      "bat": "but", "fog": "log", "sit": "set", "bar": "ban", "did": "dad", 
      "bag": "bit", "fat": "fun", "car": "can"};
    final Map<String, String> hardLadders = {"cold": "warm", "wood": "farm", 
      "mood": "road", "food": "real", "bomb": "zoom", "node": "zone", 
      "make": "bike", "pack": "kick", "move": "dive"};

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 2.0,
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Enhanced animated title
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28, 
                                  vertical: 24
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(35),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2A2A2A), 
                                      Color(0xFF1A1A1A)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.3),
                                      blurRadius: 25,
                                      spreadRadius: 3,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.6),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Colors.amber.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.extension,
                                            color: Colors.amber,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        ShaderMask(
                                          shaderCallback: (bounds) => const LinearGradient(
                                            colors: [
                                              Color(0xFFFFD700), 
                                              Color(0xFFCD7F32), 
                                              Color(0xFFDAA520)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ).createShader(bounds),
                                          child: Text(
                                            "Word Bridge",
                                            style: GoogleFonts.poppins(
                                              fontSize: 36,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "Connect • Transform • Conquer",
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.amber.withOpacity(0.8),
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 50),
                  
                  // Game modes section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.gamepad,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Choose Your Challenge",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        
                        _buildDifficultyCard(
                          label: "Gentle Mode",
                          subtitle: "3 letter words • Perfect for beginners",
                          icon: Icons.star_border_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFDAA520), Color(0xFFB8860B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          accentColor: const Color(0xFFFFD700),
                          onTap: () {
                            final entry = (easyLadders.entries.toList()..shuffle()).first;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    WordLadderGameScreen(
                                  title: "Gentle",
                                  wordLength: 3,
                                  validWords: easyWords,
                                  startWord: entry.key,
                                  goalWord: entry.value,
                                ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return SlideTransition(
                                    position: animation.drive(
                                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                                    ),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        _buildDifficultyCard(
                          label: "Master Mode",
                          subtitle: "4 letter words • For word wizards",
                          icon: Icons.flash_on_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCD7F32), Color(0xFF8B4513)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          accentColor: const Color(0xFFFF8C00),
                          onTap: () {
                            final entry = (hardLadders.entries.toList()..shuffle()).first;
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    WordLadderGameScreen(
                                  title: "Master",
                                  wordLength: 4,
                                  validWords: hardWords,
                                  startWord: entry.key,
                                  goalWord: entry.value,
                                ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return SlideTransition(
                                    position: animation.drive(
                                      Tween(begin: const Offset(1.0, 0.0), end: Offset.zero),
                                    ),
                                    child: child,
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // How to play section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.help_outline_rounded,
                              color: Colors.amber,
                              size: 20,
                            ),
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
                        _buildHowToPlayItem(
                          "1", 
                          "Transform one word into another", 
                          Icons.transform_rounded
                        ),
                        const SizedBox(height: 8),
                        _buildHowToPlayItem(
                          "2", 
                          "Change only one letter at a time", 
                          Icons.edit_rounded
                        ),
                        const SizedBox(height: 8),
                        _buildHowToPlayItem(
                          "3", 
                          "Each step must be a valid word", 
                          Icons.check_circle_outline_rounded
                        ),
                        const SizedBox(height: 8),
                        _buildHowToPlayItem(
                          "4", 
                          "Complete faster for better rewards!", 
                          Icons.timer_rounded
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyCard({
    required String label,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowToPlayItem(String number, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Icon(
          icon,
          color: Colors.amber.withOpacity(0.7),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ),
      ],
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
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    currentWord = widget.startWord.toLowerCase();
    goalWord = widget.goalWord.toLowerCase();
    stopwatch = Stopwatch()..start();
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
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    timer?.cancel();
    _messageController.dispose();
    _progressController.dispose();
    _focusNode.dispose();
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
      _messageController.forward().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _messageController.reverse();
          }
        });
      });
      return;
    }
    if (!isOneLetterDifferent(currentWord, word)) {
      setState(() => message = "⚠️ Must change exactly one letter!");
      _messageController.forward().then((_) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _messageController.reverse();
          }
        });
      });
      return;
    }
    setState(() {
      currentWord = word;
      validEnteredWords.add(word);
      _progressController.forward().then((_) {
        _progressController.reverse();
      });
      
      if (word == goalWord) {
        stopwatch.stop();
        timer?.cancel();
        final seconds = stopwatch.elapsed.inSeconds;
        if (widget.title == "Gentle") {
          if (seconds <= 8) {
            discount = "🎉 Incredible! 80% discount earned!";
          } else if (seconds <= 12) {
            discount = "🎉 Great job! 50% discount earned!";
          } else if (seconds <= 18) {
            discount = "🎉 Well done! 30% discount earned!";
          } else {
            discount = "🎯 Challenge completed!";
          }
        } else {
          if (seconds <= 30) {
            discount = "🎉 Amazing! 80% discount earned!";
          } else if (seconds <= 60) {
            discount = "🎉 Excellent! 50% discount earned!";
          } else if (seconds <= 90) {
            discount = "🎉 Good work! 30% discount earned!";
          } else {
            discount = "🎯 Challenge completed!";
          }
        }
        message = "🏆 Victory! $discount";
      } else {
        message = "✨ Perfect step forward!";
      }
    });
    
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
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
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFCD7F32)],
              ).createShader(bounds),
              child: Text(
                '${widget.title} Challenge',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.white,
                ),
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
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timer and goal section
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
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Timer row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.timer_rounded, color: Colors.amber, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Time Elapsed",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.amber.withOpacity(0.8),
                                    ),
                                  ),
                                  Text(
                                    "${elapsedSeconds}s",
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${validEnteredWords.length} steps",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Start and goal words
                        Row(
                          children: [
                            Expanded(
                              child: _buildWordCard("🚩 Start", widget.startWord, Colors.green),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _buildWordCard("🎯 Goal", widget.goalWord, Colors.red),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        // Current word
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber.withOpacity(0.2), Colors.amber.withOpacity(0.1)],
                            ),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.amber.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.my_location_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                "Current: ${currentWord.toUpperCase()}",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  // Input field
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: "Enter your next word",
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.amber,
                          fontSize: 16,
                        ),
                        prefixIcon: const Icon(Icons.edit_rounded, color: Colors.amber),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.amber),
                          onPressed: () {
                            if (_controller.text.isNotEmpty) {
                              handleSubmit(_controller.text);
                              _controller.clear();
                            }
                          },
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.amber.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.amber, width: 2),
                          borderRadius: BorderRadius.circular(20),
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
                  const SizedBox(height: 20),
                  
                  // Message
                  if (message.isNotEmpty)
                    AnimatedBuilder(
                      animation: _messageAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _messageAnimation.value,
                          child: Opacity(
                            opacity: _messageAnimation.value,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: message.contains("Victory")
                                    ? const LinearGradient(
                                        colors: [Color(0xFF228B22), Color(0xFF32CD32)],
                                      )
                                    : message.contains("❌") || message.contains("⚠️")
                                        ? const LinearGradient(
                                            colors: [Color(0xFFDC143C), Color(0xFFB22222)],
                                          )
                                        : const LinearGradient(
                                            colors: [Color(0xFFDAA520), Color(0xFFCD7F32)],
                                          ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
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
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  
                  // Progress section
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
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timeline_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Your Journey",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        if (validEnteredWords.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: [
                                _buildJourneyStep(widget.startWord, true),
                                ...validEnteredWords.map((word) => _buildJourneyStep(word, false)),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "Start typing to begin your journey!",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  // Available words
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
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.library_books_rounded, color: Colors.amber, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Available Words",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "${validEnteredWords.length}/${widget.validWords.length}",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: widget.validWords.map((word) {
                                final isEntered = validEnteredWords.contains(word.toLowerCase());
                                return AnimatedBuilder(
                                  animation: _progressAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: isEntered ? 1.0 + (_progressAnimation.value * 0.1) : 1.0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: isEntered
                                              ? const LinearGradient(
                                                  colors: [Color(0xFFDAA520), Color(0xFFCD7F32)],
                                                )
                                              : const LinearGradient(
                                                  colors: [Color(0xFF3A3A3A), Color(0xFF2A2A2A)],
                                                ),
                                          borderRadius: BorderRadius.circular(15),
                                          boxShadow: isEntered
                                              ? [
                                                  BoxShadow(
                                                    color: Colors.amber.withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isEntered) ...[
                                              const Icon(Icons.check_circle_rounded, 
                                                  color: Colors.white, size: 12),
                                              const SizedBox(width: 4),
                                            ],
                                            Text(
                                              word,
                                              style: GoogleFonts.poppins(
                                                color: isEntered ? Colors.white : Colors.grey,
                                                fontWeight: isEntered ? FontWeight.w600 : FontWeight.w400,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Quit button
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDC143C), Color(0xFFB22222)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          stopwatch.stop();
                          timer?.cancel();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.exit_to_app_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'End Challenge',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWordCard(String label, String word, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            word.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyStep(String word, bool isStart) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: isStart
            ? const LinearGradient(colors: [Color(0xFF228B22), Color(0xFF32CD32)])
            : const LinearGradient(colors: [Color(0xFFDAA520), Color(0xFFCD7F32)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isStart) ...[
            const Icon(Icons.flag_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ] else ...[
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            word.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}