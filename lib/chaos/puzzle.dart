import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  static const Color deepBlack = Color(0xFF0A0A0A);
  static const Color richGrey = Color(0xFF2C2C2C);
  static const Color lightGrey = Color(0xFF6B6B6B);
  static const Color softGrey = Color(0xFF9E9E9E);
  static const Color pureGold = Color(0xFFFFD700);
  static const Color warmBronze = Color(0xFFCD7F32);
  static const Color glowingAmber = Color(0xFFFFC107);
  static const Color darkAmber = Color(0xFFFF8F00);

  @override
  void initState() {
    super.initState();
    _prepareGame();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 70)
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
          feedback = "⏰ Time's up! Better luck next time.";
          timer?.cancel();
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _prepareGame() {
    selectedBlocks = blocks..shuffle();
    selectedBlocks = selectedBlocks.sublist(0, 6);
    rules = generateRules(selectedBlocks);
  }

  void _startGame() {
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
          "❌ Use each block exactly once from the given set.");
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
          "❌ Rule violations:\n${violations.map((v) => '• $v').join('\n')}");
    }
  }

  void _showSuccessDialog() {
    String reward = elapsed <= 20
        ? "🎉 100% DISCOUNT UNLOCKED!"
        : elapsed <= 30
            ? "🎉 80% DISCOUNT UNLOCKED!"
            : elapsed <= 45
                ? "🎉 60% DISCOUNT UNLOCKED!"
                : elapsed <= 60
                    ? "🎉 50% DISCOUNT UNLOCKED!"
                    : "⏰ No discount this time.";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildSuccessDialog(reward),
    );
  }

  Widget _buildSuccessDialog(String reward) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [richGrey, deepBlack],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: pureGold.withOpacity(0.8), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: pureGold.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [pureGold, glowingAmber],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: pureGold.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.celebration,
                          size: 50,
                          color: deepBlack,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "PUZZLE SOLVED!",
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: pureGold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Completed in $elapsed seconds",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: softGrey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [glowingAmber.withOpacity(0.3), pureGold.withOpacity(0.3)],
                          ),
                          border: Border.all(color: glowingAmber.withOpacity(0.7)),
                          boxShadow: [
                            BoxShadow(
                              color: glowingAmber.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          reward,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: glowingAmber,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildActionButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetGame();
                        },
                        label: "Play Again",
                        isPrimary: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
    required VoidCallback onPressed, 
    required String label, 
    bool isPrimary = false,
    bool disabled = false
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: disabled 
            ? LinearGradient(colors: [lightGrey, richGrey])
            : LinearGradient(
                colors: isPrimary 
                    ? [pureGold, glowingAmber]
                    : [warmBronze, darkAmber],
              ),
        boxShadow: disabled ? [] : [
          BoxShadow(
            color: (isPrimary ? pureGold : warmBronze).withOpacity(0.6),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: disabled ? softGrey : deepBlack,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBoxes() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final horizontalPadding = screenWidth * 0.05;
        final availableWidth = screenWidth - (horizontalPadding * 2);
        final spacing = 10.0;
        final totalSpacing = spacing * 5;
        final itemWidth = (availableWidth - totalSpacing) / 6;
        final clampedSize = itemWidth.clamp(55.0, 75.0);

        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Wrap(
            spacing: spacing,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: List.generate(6, (i) {
              final bool hasInput = inputs[i].isNotEmpty;
              return Container(
                width: clampedSize,
                height: clampedSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: hasInput 
                        ? [richGrey, deepBlack]
                        : [lightGrey.withOpacity(0.2), richGrey.withOpacity(0.4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: hasInput ? pureGold : warmBronze.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (hasInput ? pureGold : warmBronze).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: TextField(
                  enabled: !timeUp,
                  onChanged: (val) {
                    setState(() {
                      inputs[i] = val.toUpperCase();
                    });
                  },
                  maxLength: 1,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: GoogleFonts.poppins(
                    fontSize: clampedSize * 0.45,
                    color: hasInput ? pureGold : glowingAmber,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildRuleCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [richGrey.withOpacity(0.95), deepBlack.withOpacity(0.98)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: warmBronze.withOpacity(0.7), width: 2),
        boxShadow: [
          BoxShadow(
            color: warmBronze.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [pureGold, glowingAmber],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: pureGold.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.rule,
                  color: deepBlack,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Rules",
                style: GoogleFonts.poppins(
                  color: pureGold,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...rules.map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 8, right: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [glowingAmber, pureGold],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: glowingAmber.withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rule.description,
                        style: GoogleFonts.poppins(
                          color: softGrey,
                          fontSize: 16,
                          height: 1.5,
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

  Widget _buildProgressBar() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: pureGold.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  return LinearProgressIndicator(
                    value: _controller.value,
                    minHeight: 16,
                    backgroundColor: richGrey,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.lerp(pureGold, Colors.red.shade600, _controller.value) ?? 
                          pureGold,
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
                _buildTimeLabel("0s", pureGold),
                _buildTimeLabel("20s", glowingAmber),
                _buildTimeLabel("45s", warmBronze),
                _buildTimeLabel("70s", Colors.red.shade400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Scaffold(
      backgroundColor: deepBlack,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [richGrey.withOpacity(0.3), deepBlack],
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [pureGold, glowingAmber],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: pureGold.withOpacity(0.6),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.extension,
                    size: 70,
                    color: deepBlack,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  "Stack the Code",
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: pureGold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Solve the puzzle to unlock amazing discounts!",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: softGrey,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [richGrey.withOpacity(0.5), deepBlack.withOpacity(0.8)],
                    ),
                    border: Border.all(color: warmBronze.withOpacity(0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: warmBronze.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.timer,
                        color: pureGold,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Challenge Instructions",
                        style: GoogleFonts.poppins(
                          color: pureGold,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "• Arrange 6 blocks following the given rules\n"
                        "• You have 70 seconds to complete\n"
                        "• Faster completion = Better discount!\n"
                        "• Rules will be revealed when you start",
                        style: GoogleFonts.poppins(
                          color: softGrey,
                          fontSize: 15,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                _buildActionButton(
                  onPressed: _startGame,
                  label: "Start Challenge",
                  isPrimary: true,
                ),
                const SizedBox(height: 60),
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
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [richGrey.withOpacity(0.3), deepBlack],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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
                          color: pureGold,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            colors: [glowingAmber.withOpacity(0.3), pureGold.withOpacity(0.3)],
                          ),
                          border: Border.all(color: glowingAmber.withOpacity(0.7), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: glowingAmber.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          "${elapsed}s",
                          style: GoogleFonts.poppins(
                            color: glowingAmber,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
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
                    color: warmBronze,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Arrange the blocks in order:",
                  style: GoogleFonts.poppins(
                    color: softGrey,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputBoxes(),
                const SizedBox(height: 40),
                _buildActionButton(
                  onPressed: checkAnswer,
                  label: timeUp ? "Time's Up!" : "Submit Answer",
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