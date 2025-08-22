import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'dart:math' as math;

class StackTheCodeGame extends StatefulWidget {
  const StackTheCodeGame({super.key});

  @override
  State<StackTheCodeGame> createState() => _StackTheCodeGameState();
}

class _StackTheCodeGameState extends State<StackTheCodeGame> 
    with SingleTickerProviderStateMixin {
  final List<String> blocks = List.generate(10, (i) => String.fromCharCode(65 + i));
  List<String> selectedBlocks = [];
  List<String> inputs = List.filled(6, '');
  List<Rule> rules = [];
  int elapsed = 0;
  Timer? timer;
  String feedback = '';
  bool gameStarted = false;
  bool timeUp = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final FirebaseAuth _uid = FirebaseAuth.instance;
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
late ConfettiController _confettiController;
late List<FocusNode> focusNodes;
late List<TextEditingController> controllers;

static const Color deepBlack = Color(0xFF0B0B0B);
static const Color charcoalBlack = Color(0xFF1A1A1A);
static const Color darkGrey = Color(0xFF2A2A2A);
static const Color mediumGrey = Color(0xFF4A4A4A);
static const Color lightGrey = Color(0xFF6A6A6A);
static const Color elegantGold = Color(0xFFD4AF37);
static const Color refinedBronze = Color(0xFFB08D57);
static const Color subtleAmber = Color(0xFFE6B800);

@override
void initState() {
  super.initState();
  _prepareGame();
  
  // Animation controller setup
  _controller = AnimationController(
    vsync: this, 
    duration: const Duration(seconds: 95)
  );
  
  _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
  );
  
  _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
  );
  
  _controller.addStatusListener((status) {
    if (status == AnimationStatus.completed && gameStarted) {
      setState(() {
        timeUp = true;
        feedback = "use your talented fingers faster next time😏";
        timer?.cancel();
      });
    }
  });
  
  // Confetti controller
  _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  
  // Input boxes setup
  focusNodes = List.generate(6, (index) => FocusNode());
  controllers = List.generate(6, (index) => TextEditingController());
  
  // Add focus listeners for UI updates
  for (int i = 0; i < 6; i++) {
    focusNodes[i].addListener(() {
      setState(() {}); // Rebuild to update focus state
    });
    
    // Sync controllers with inputs array
    controllers[i].addListener(() {
      if (i < inputs.length) {
        final text = controllers[i].text.toUpperCase();
        if (inputs[i] != text) {
          setState(() {
            inputs[i] = text;
          });
        }
      }
    });
  }
}

@override
void dispose() {
  // Cancel timer
  timer?.cancel();
  
  // Dispose animation controllers
  _controller.dispose();
  _confettiController.dispose();
  
  // Dispose input box focus nodes and controllers
  for (var node in focusNodes) {
    node.dispose();
  }
  for (var controller in controllers) {
    controller.dispose();
  }
  
  super.dispose();
}

  void _prepareGame() {
    selectedBlocks = blocks..shuffle();
    selectedBlocks = selectedBlocks.sublist(0, 6);
    rules = generateRules(selectedBlocks);
  }

 void _startGame() async {
  // Get current user
  final User? currentUser = _uid.currentUser;
  if (currentUser == null) {
    // Handle no user logged in
    setState(() {
      feedback = "Please log in to play";
    });
    return;
  }

  // Update Firestore before starting the game
  try {
    await _firestore
        .collection('users')
        .doc(currentUser.uid)  // Dynamic UID
        .collection('games')
        .doc('triesTracker')
        .set({
      'triesUsed': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));  // merge: true to update existing doc or create new one
  } catch (e) {
    print('Error updating Firestore: $e');
    // Optionally show error to user or continue anyway
  }

  // Your existing _startGame logic
  setState(() {
    gameStarted = true;
    timeUp = false; 
    elapsed = 0;
    feedback = '';
    inputs = List.filled(6, '');
    _controller.forward(from: 0);
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsed++);
    });
  });
}

  void _resetGame() {
    timer?.cancel();
    _controller.reset();
    setState(() {
      gameStarted = false;
      timeUp = false;
      inputs = List.filled(6, '');
      _prepareGame();
      feedback = '';
    });
  }

  void checkAnswer() {
    if (timeUp) return;
    
    final guess = inputs.map((x) => x.toUpperCase()).toList();
    if (Set.from(guess).length != 6 || 
        !selectedBlocks.every(guess.contains)) {
      setState(() => feedback = 
          "❌ use each block exactly once from the given set.");
      return;
    }

    final violations = rules
        .where((rule) => !rule.validate(guess))
        .map((rule) => rule.description)
        .toList();

    if (violations.isEmpty) {
      timer?.cancel();
      _controller.stop();
      _showSuccessDialog();
    } else {
      setState(() => feedback = 
          "❌ rule violations:\n${violations.map((v) => '• $v').join('\n')}");
    }
  }

void _showSuccessDialog() {
  String reward = elapsed <= 10
      ? "🎉 100% DISCOUNT UNLOCKED!"
      : elapsed <= 15
          ? "🎉 20% DISCOUNT UNLOCKED!"
          : "⏰ No discount this time.";

  // Start confetti when dialog opens
  _confettiController.play();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _buildSuccessDialog(reward),
  );
}

Widget _buildSuccessDialog(String reward) {
  bool hasDiscount = elapsed <= 15; // Only show confetti if user gets discount
  
  // Start confetti only if user gets discount
  if (hasDiscount) {
    _confettiController.play();
  }

  return Material(
    color: Colors.transparent,
    child: Stack(
      children: [
        // Subtle backdrop blur
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: deepBlack.withOpacity(0.4),
          ),
        ),
        
        // Main Dialog
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 700),
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF2A1810).withOpacity(0.9),
                  charcoalBlack,
                  darkGrey.withOpacity(0.95),
                  deepBlack,
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
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
                  // Enhanced Trophy
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [elegantGold, refinedBronze],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: elegantGold.withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: subtleAmber.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: 55,
                      color: deepBlack,
                    ),
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Enhanced Success Title
                  Text(
                    "PUZZLE SOLVED!",
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: elegantGold,
                      letterSpacing: 1.2,
                      // shadows: [
                      //   Shadow(
                      //     color: elegantGold.withOpacity(0.8),
                      //     blurRadius: 12,
                      //     offset: const Offset(0, 2),
                      //   ),
                      //   Shadow(
                      //     color: subtleAmber.withOpacity(0.4),
                      //     blurRadius: 25,
                      //   ),
                      // ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Enhanced Completion Time
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          elegantGold.withOpacity(0.15),
                          subtleAmber.withOpacity(0.08),
                        ],
                      ),
                      border: Border.all(
                        color: elegantGold.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: lightGrey,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Completed in $elapsed seconds",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: lightGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Enhanced Reward Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          elegantGold.withOpacity(0.25),
                          refinedBronze.withOpacity(0.15),
                          subtleAmber.withOpacity(0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Column(
                      children: [
                        // Enhanced Gift Icon
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [elegantGold, subtleAmber],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: elegantGold.withOpacity(0.4),
                                blurRadius: 15,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
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
                            color: hasDiscount ? elegantGold : lightGrey,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Play Again Button - Match Start Challenge exactly
                  _buildActionButton(
                    onPressed: () {
                      _confettiController.stop();
                      Navigator.of(context).pop();
                      _resetGame();
                    },
                    label: "PLAY AGAIN",
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Confetti only when user gets discount
        if (hasDiscount)
          Positioned.fill(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: -math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 25,
              minBlastForce: 10,
              emissionFrequency: 0.03,
              numberOfParticles: 60,
              gravity: 0.4,
              shouldLoop: false,
              colors: const [
                Color(0xFFFFD700), // elegantGold
                Color(0xFFE6B800), // subtleAmber  
                Color(0xFFB08D57), // refinedBronze
                Color(0xFFFFC107),
              ],
            ),
          ),
      ],
    ),
  );
}
  List<Rule> generateRules(List<String> blocks) {
    final result = <Rule>[];
    final used = <String>{};
    final sample = blocks..shuffle();

    if (sample.length >= 3) {
      final m = sample[0], n = sample[1], p = sample[2];
      used.addAll([m, n, p]);
      result.add(Rule("$m must be between $n and $p", (order) {
        final indexM = order.indexOf(m);
        final indexN = order.indexOf(n);
        final indexP = order.indexOf(p);
        return (indexN < indexM && indexM < indexP) || 
               (indexP < indexM && indexM < indexN);
      }));
    }

    var rem = blocks.where((x) => !used.contains(x)).toList();
    if (rem.length >= 2) {
      final a = rem[0], b = rem[1];
      used.addAll([a, b]);
      result.add(Rule("$a cannot be beside $b", (order) {
        final indexA = order.indexOf(a);
        final indexB = order.indexOf(b);
        return (indexA - indexB).abs() > 1;
      }));
    }

    rem = blocks.where((x) => !used.contains(x)).toList();
    if (rem.length >= 2) {
      final c = rem[0], d = rem[1];
      used.addAll([c, d]);
      result.add(Rule("$c must come after $d", (order) {
        final indexC = order.indexOf(c);
        final indexD = order.indexOf(d);
        return indexC > indexD;
      }));
    }

    rem = blocks.where((x) => !used.contains(x)).toList();
    if (rem.isNotEmpty) {
      final x = rem[0];
      used.add(x);
      result.add(Rule("$x must not be first", (order) => order.first != x));
    }

    if (sample.length >= 5) {
      final y = sample[3], z = sample[4];
      result.add(Rule("$y must come before $z", (order) {
        final indexY = order.indexOf(y);
        final indexZ = order.indexOf(z);
        return indexY < indexZ;
      }));
    }

    if (sample.length >= 6) {
      final w = sample[5];
      result.add(Rule("$w must not be last", (order) => order.last != w));
    }

    return result;
  }

Widget _buildActionButton({
  required VoidCallback? onPressed, 
  required String label, 
  bool isPrimary = false,
  bool disabled = false
}) {
  return GestureDetector(
    onTap: disabled ? null : onPressed,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        gradient: disabled
            ? const LinearGradient(colors: [Colors.grey, Colors.grey])
            : (isPrimary 
                ? const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB77200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB77200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )),
        borderRadius: BorderRadius.circular(16),
        boxShadow: disabled
            ? []
            : [
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
              ],
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
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    ),
  );
}

// 2. Replace _buildInputBoxes method with enhanced glowing inputs:


Widget _buildInputBoxes() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final screenWidth = MediaQuery.of(context).size.width;
      final horizontalPadding = screenWidth*0.00000005; // Reduced padding
      final availableWidth = screenWidth - (horizontalPadding * 2);
      
      // Calculate optimal size with generous spacing
      final minSpacing = 8.0; // Minimum spacing between boxes
      final maxSize = 70.0;
      final minSize = 40.0;
      
      // Try to fit 6 boxes with good spacing
      double calculatedSize = (availableWidth - (minSpacing * 5)) / 6;
      final clampedSize = calculatedSize.clamp(minSize, maxSize);
      
      // Recalculate actual spacing with the clamped size
      final totalBoxWidth = clampedSize * 100;
      final remainingSpace = availableWidth - totalBoxWidth;
      final actualSpacing = (remainingSpace / 5).clamp(minSpacing, 20.0);

      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (i) {
              final bool hasInput = inputs[i].isNotEmpty;
              final bool isFocused = focusNodes[i].hasFocus;
              
              return Container(
                margin: EdgeInsets.only(right: i < 5 ? actualSpacing : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: clampedSize,
                  height: clampedSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), // Reduced radius
                    gradient: LinearGradient(
                      colors: hasInput 
                          ? [const Color(0xFF2A2A2A), const Color(0xFF1A1A1A)]
                          : isFocused
                              ? [?Colors.grey[900], ?Colors.grey[900]]
                              : [?Colors.grey[900], ?Colors.grey[900]],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: hasInput 
                          ? const Color.fromARGB(255, 249, 175, 28)
                          : isFocused
                              ? const Color.fromARGB(255, 249, 175, 28)
                              : const Color(0xFF444444),
                      width: hasInput ? 2.0 : isFocused ? 1.8 : 1.2, // Reduced border width
                    ),
                    boxShadow: [
                      if (hasInput) ...[
                        BoxShadow(
                          color: const Color.fromARGB(255, 249, 175, 28).withOpacity(0.05), // Reduced opacity
                          blurRadius: 5, // Reduced blur
                          spreadRadius: 0, // Reduced spread
                          offset: const Offset(0, 1),
                        ),
                      ] else if (isFocused) ...[
                        BoxShadow(
                          color: const Color.fromARGB(255, 249, 175, 28).withOpacity(0.25),
                          blurRadius: 5,
                          spreadRadius: 0,
                          offset: const Offset(0, 1),
                        ),
                      ] else ...[
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          spreadRadius: 0,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ],
                  ),
                  child: TextField(
                    focusNode: focusNodes[i],
                    controller: controllers[i],
                    enabled: !timeUp,
                    onChanged: (val) {
                      setState(() {
                        inputs[i] = val.toUpperCase();
                      });
                      
                      if (val.isNotEmpty && i < 5) {
                        FocusScope.of(context).requestFocus(focusNodes[i + 1]);
                      }
                    },
                    onTap: () {
                      if (controllers[i].text.isNotEmpty) {
                        controllers[i].clear();
                        setState(() {
                          inputs[i] = '';
                        });
                      }
                    },
                    maxLength: 1,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    style: GoogleFonts.poppins(
                      fontSize: clampedSize * 0.4, // Reduced font size slightly
                      color: hasInput 
                          ? const Color.fromARGB(255, 249, 175, 28)
                          : const Color(0xFFCCCCCC),
                      fontWeight: FontWeight.w700, // Reduced weight
                      shadows: hasInput ? [
                        // Shadow(
                        //   color: const Color.fromARGB(255, 249, 175, 28).withOpacity(0.5),
                        //   // blurRadius: 1, // Reduced blur
                        //   // offset: const Offset(0, 1),
                        // ),
                      ] : [],
                      letterSpacing: 0.3, // Reduced letter spacing
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                    cursorColor: const Color(0xFFFFD700),
                    cursorWidth: 2.0, // Reduced cursor width
                    cursorHeight: clampedSize * 0.45, // Reduced cursor height
                    cursorRadius: const Radius.circular(1),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    },
  );
}

// 3. Replace _buildRuleCard method with enhanced gradients:

Widget _buildRuleCard() {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 20),
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        colors: [
          charcoalBlack,
          darkGrey.withOpacity(0.9),
          charcoalBlack.withOpacity(0.8)
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.0, 0.5, 1.0],
      ),
      border: Border.all(color: refinedBronze.withOpacity(0.6), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: refinedBronze.withOpacity(0.1),
          blurRadius: 20,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: elegantGold.withOpacity(0.05),
          blurRadius: 40,
          spreadRadius: 5,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [elegantGold, subtleAmber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: elegantGold.withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.rule,
                color: deepBlack,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "Rules",
              style: GoogleFonts.poppins(
                color: elegantGold,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                shadows: [
                  Shadow(
                    color: elegantGold.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...rules.map((rule) => Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 8, right: 16),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [subtleAmber, elegantGold, refinedBronze],
                        stops: [0.0, 0.7, 1.0],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: subtleAmber.withOpacity(0.6),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rule.description,
                      style: GoogleFonts.poppins(
                        color: lightGrey,
                        fontSize: 16,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    ),
  );
}

// 4. Replace _buildProgressBar method with enhanced glowing progress bar:

Widget _buildProgressBar() {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        // Background container
        Container(
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [darkGrey, charcoalBlack],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(color: refinedBronze.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: darkGrey.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return Align(
                  alignment: Alignment.centerLeft, // This ensures left alignment
                  child: FractionallySizedBox(
                    widthFactor: _controller.value, // Progress from 0.0 to 1.0
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [elegantGold, subtleAmber, refinedBronze],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: [0.0, 0.6, 1.0],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: elegantGold.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTimeLabel("0s", elegantGold),
              _buildTimeLabel("8s", subtleAmber),
              _buildTimeLabel("15s", refinedBronze),
            ],
          ),
        ),
      ],
    ),
  );
}

// 5. Replace _buildTimeLabel method with enhanced glowing labels:

Widget _buildTimeLabel(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: LinearGradient(
        colors: [
          color.withOpacity(0.2),
          color.withOpacity(0.1),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: color.withOpacity(0.6), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.2),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ],
    ),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        shadows: [
          Shadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
          ),
        ],
      ),
    ),
  );
}

// 6. Replace _buildWelcomeScreen background and main container:

Widget _buildWelcomeScreen() {
  return Scaffold(
    backgroundColor: deepBlack,
    body: Container(
       decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF2A1810).withOpacity(0.9),
        const Color(0xFF3D2914).withOpacity(0.7),
        const Color(0xFF4A3218).withOpacity(0.5),
        Colors.black,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
  ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [elegantGold, subtleAmber, refinedBronze],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(color: elegantGold.withOpacity(0.4), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: elegantGold.withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                    BoxShadow(
                      color: subtleAmber.withOpacity(0.2),
                      blurRadius: 45,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 65,
                  color: deepBlack,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "stack the code",
                style: GoogleFonts.poppins(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: elegantGold,
                  letterSpacing: 1.0,
                  // shadows: [
                  //   Shadow(
                  //     color: elegantGold.withOpacity(0.4),
                  //     blurRadius: 5,
                  //     offset: const Offset(2, 2),
                  //   ),
                  // ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "want things to be free right? solve this shit🧱",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: lightGrey,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
             
Container(
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: LinearGradient(
      colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 12,
        spreadRadius: 2,
      ),
    ],
  ),
  child: Column(
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [elegantGold, subtleAmber],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: elegantGold.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.timer,
          color: deepBlack,
          size: 32,
        ),
      ),
      const SizedBox(height: 16),
      
      Text(
        "instructions for you",
        style: GoogleFonts.poppins(
          color: elegantGold,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 20),
      
      Text(
        "• Arrange 6 blocks following the given rules\n"
        "• You have 15 seconds to complete\n"
        "• Faster completion = Better discount!\n"
        "• Rules will be revealed when you start",
        style: GoogleFonts.poppins(
          color: const Color.fromARGB(255, 100, 99, 99),
          fontSize: 13,
          height: 1.6,
        ),
        textAlign: TextAlign.start,
      ),
      const SizedBox(height: 20),
      
      Container(
        height: 1,
        width: double.infinity,
        color: elegantGold.withOpacity(0.3),
      ),
      const SizedBox(height: 20),
      
      Text(
        "Discounts",
        style: GoogleFonts.poppins(
          color: elegantGold,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: elegantGold.withOpacity(0.4)),
              color: elegantGold.withOpacity(0.1),
            ),
            child: Column(
              children: [
                Text(
                  "≤ 8s",
                  style: GoogleFonts.poppins(
                    color: elegantGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "100% OFF",
                  style: GoogleFonts.poppins(
                    color: elegantGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: elegantGold.withOpacity(0.4)),
              color: elegantGold.withOpacity(0.1),
            ),
            child: Column(
              children: [
                Text(
                  "≤ 15s",
                  style: GoogleFonts.poppins(
                    color: elegantGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "20% OFF",
                  style: GoogleFonts.poppins(
                    color: elegantGold,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
  ],
),
              const SizedBox(height: 50),
              _buildActionButton(
                onPressed: _startGame,
                label: "START CHALLENGE",
                isPrimary: true,
              ),
              const SizedBox(height: 60),
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

  Widget _buildGameScreen() {
    return Scaffold(
      backgroundColor: deepBlack,
      body: Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF2A1810).withOpacity(0.9),
        const Color(0xFF3D2914).withOpacity(0.7),
        const Color(0xFF4A3218).withOpacity(0.5),
        Colors.black,
      ],
      stops: const [0.0, 0.3, 0.6, 1.0],
    ),
  ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: ScrollController(), // Add this
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
  padding: const EdgeInsets.symmetric(vertical: 20),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        "Stack the Code",
        style: GoogleFonts.poppins(
          color: elegantGold,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: elegantGold.withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [charcoalBlack, darkGrey.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: subtleAmber.withOpacity(0.7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: subtleAmber.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          "${elapsed}s",
          style: GoogleFonts.poppins(
            color: subtleAmber,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            shadows: [
              Shadow(
                color: subtleAmber.withOpacity(0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    ],
  ),
),
                _buildProgressBar(),
                _buildRuleCard(),
                const SizedBox(height: 32),
                Text(
                  "Available blocks: ${selectedBlocks.join(', ')}",
                  style: GoogleFonts.poppins(
                    color: refinedBronze,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Arrange the blocks in order:",
                  style: GoogleFonts.poppins(
                    color: lightGrey,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputBoxes(),
                const SizedBox(height: 40),
                _buildActionButton(
                  onPressed: checkAnswer,
                  label: timeUp ? "TIME IS UP!" : "SUBMIT ANSWER",
                  isPrimary: true,
                  disabled: timeUp,
                ),
                if (feedback.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [Colors.red.shade900.withOpacity(0.3), Colors.red.shade800.withOpacity(0.2)],
                      ),
                      border: Border.all(color: Colors.red.shade600.withOpacity(0.7), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade600.withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      feedback,
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade300,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return gameStarted ? _buildGameScreen() : _buildWelcomeScreen();
  }
}

class Rule {
  final String description;
  final bool Function(List<String>) validate;
  Rule(this.description, this.validate);
}