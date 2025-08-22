import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

class LogicStackGame extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const LogicStackGame({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<LogicStackGame> createState() => _LogicStackGameState();
}

class _LogicStackGameState extends State<LogicStackGame> 
    with TickerProviderStateMixin {
  final List<String> blocks = List.generate(10, (i) => String.fromCharCode(65 + i));
  List<String> selectedBlocks = [];
  List<String> inputs = List.filled(6, '');
  List<TextEditingController> controllers = [];
  List<Rule> rules = [];
  int elapsed = 0;
  Timer? timer;
  String feedback = '';
  bool gameStarted = false;
  bool gameCompleted = false;
  int attemptsToday = 0;
  int pointsEarned = 0;
  bool canPlay = true;

  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  // Responsive design helpers
  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;
  bool get isLandscape => MediaQuery.of(context).orientation == Orientation.landscape;
  bool get isSmallDevice => MediaQuery.of(context).size.height < 600;
  bool get isCompact => MediaQuery.of(context).size.width < 400;
  
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  double get safeAreaHeight => screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
  
  // Dynamic sizing based on screen size
  double get headerFontSize => isTablet ? 28 : (isSmallDevice ? 18 : 22);
  double get subHeaderFontSize => isTablet ? 14 : (isSmallDevice ? 10 : 12);
  double get titleFontSize => isTablet ? 20 : (isSmallDevice ? 14 : 16);
  double get bodyFontSize => isTablet ? 16 : (isSmallDevice ? 12 : 14);
  double get smallFontSize => isTablet ? 14 : (isSmallDevice ? 10 : 12);
  double get buttonFontSize => isTablet ? 18 : (isSmallDevice ? 14 : 16);
  double get inputFontSize => isTablet ? 24 : (isSmallDevice ? 16 : 20);
  
  EdgeInsets get screenPadding => EdgeInsets.all(isTablet ? 24 : (isSmallDevice ? 12 : 16));
  EdgeInsets get containerPadding => EdgeInsets.all(isTablet ? 24 : (isSmallDevice ? 16 : 20));
  EdgeInsets get compactPadding => EdgeInsets.all(isTablet ? 20 : (isSmallDevice ? 12 : 16));
  
  double get spacingSmall => isTablet ? 12 : (isSmallDevice ? 6 : 8);
  double get spacingMedium => isTablet ? 20 : (isSmallDevice ? 12 : 16);
  double get spacingLarge => isTablet ? 32 : (isSmallDevice ? 16 : 24);

  @override
  void initState() {
    super.initState();
    controllers = List.generate(6, (_) => TextEditingController());
    _initAnimations();
    _loadTodayAttempts();
    _initializeGame();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  Future<void> _loadTodayAttempts() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_attempts')
          .doc('${widget.username}_puzzle_$todayString')
          .get();

      if (doc.exists) {
        setState(() {
          attemptsToday = doc.data()?['attempts'] ?? 0;
          canPlay = attemptsToday < 10;
        });
      } else {
        setState(() {
          attemptsToday = 0;
          canPlay = true;
        });
      }
    } catch (e) {
      print('Error loading attempts: $e');
    }
  }

  Future<void> _updateAttempts() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_attempts')
          .doc('${widget.username}_puzzle_$todayString')
          .set({
        'username': widget.username,
        'game': 'puzzle',
        'attempts': attemptsToday + 1,
        'date': todayString,
        'lastAttempt': FieldValue.serverTimestamp(),
      });

      setState(() {
        attemptsToday++;
        canPlay = attemptsToday < 10;
      });
    } catch (e) {
      print('Error updating attempts: $e');
    }
  }

  Future<void> _updateScore(int points) async {
    try {
      final scoreRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_scores')
          .doc(widget.username);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final scoreDoc = await transaction.get(scoreRef);
        
        if (scoreDoc.exists) {
          final currentData = scoreDoc.data() as Map<String, dynamic>;
          final currentPuzzlePoints = currentData['puzzlePoints'] ?? 0;
          final currentTotalPoints = currentData['totalPoints'] ?? 0;
          
          transaction.update(scoreRef, {
            'puzzlePoints': currentPuzzlePoints + points,
            'totalPoints': currentTotalPoints + points,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(scoreRef, {
            'username': widget.username,
            'timerPoints': 0,
            'puzzlePoints': points,
            '2048Points': 0,
            'birdPoints': 0,
            'totalPoints': points,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error updating score: $e');
    }
  }

  void _initializeGame() {
    selectedBlocks = blocks.toList()..shuffle();
    selectedBlocks = selectedBlocks.sublist(0, 6);
    rules = generateRules(selectedBlocks);
    
    for (var controller in controllers) {
      controller.clear();
    }
    
    setState(() {
      inputs = List.filled(6, '');
      feedback = '';
      gameStarted = false;
      gameCompleted = false;
      elapsed = 0;
      pointsEarned = 0;
    });
  }

  void _startGame() {
    if (!canPlay) return;
    
    setState(() {
      gameStarted = true;
      elapsed = 0;
    });
    
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => elapsed++);
    });
  }

  void checkAnswer() async {
    if (!gameStarted || gameCompleted) return;
    
    List<String> guess = List.from(inputs.map((x) => x.toUpperCase()));
    
    if (Set.from(guess).length != 6 || !selectedBlocks.every(guess.contains)) {
      _shakeController.forward().then((_) => _shakeController.reset());
      setState(() => feedback = "❌ Invalid input. Use each block exactly once.");
      return;
    }

    List<String> violations = rules
        .where((rule) => !rule.validate(guess))
        .map((rule) => rule.description)
        .toList();

    if (violations.isEmpty) {
      timer?.cancel();
      
      int points = 0;
      String reward = "";
      
      if (elapsed <= 8) {
        points = 500;
        reward = "🎉 Lightning fast! +500 points!";
      } else if (elapsed <= 15) {
        points = 100;
        reward = "👍 Well done! +100 points!";
      } else {
        reward = "✅ Solved! No points (too slow)";
      }

      setState(() {
        gameCompleted = true;
        feedback = "🎯 Correct! Solved in ${elapsed}s\n$reward";
        pointsEarned = points;
      });

      await _updateAttempts();
      if (points > 0) {
        await _updateScore(points);
      }
    } else {
      _shakeController.forward().then((_) => _shakeController.reset());
      setState(() => feedback = "❌ Violations:\n• ${violations.join("\n• ")}");
    }
  }

  List<Rule> generateRules(List<String> blocks) {
    List<Rule> result = [];
    Set<String> used = {};

    List<String> sample = blocks.toList()..shuffle();
    var m = sample[0], n = sample[1], p = sample[2];
    used.addAll([m, n, p]);
    result.add(Rule(
        "$m must be between $n and $p",
        (order) => (order.indexOf(n) < order.indexOf(m) && order.indexOf(m) < order.indexOf(p)) ||
            (order.indexOf(p) < order.indexOf(m) && order.indexOf(m) < order.indexOf(n))));

    var rem = blocks.where((x) => !used.contains(x)).toList();
    if (rem.length >= 2) {
      var a = rem[0], b = rem[1];
      used.addAll([a, b]);
      result.add(Rule("$a can't be next to $b",
          (order) => (order.indexOf(a) - order.indexOf(b)).abs() > 1));
    }

    rem = blocks.where((x) => !used.contains(x)).toList();
    if (rem.length >= 2) {
      var c = rem[0], d = rem[1];
      used.addAll([c, d]);
      result.add(Rule("$c must come after $d",
          (order) => order.indexOf(c) > order.indexOf(d)));
    }

    rem = blocks.where((x) => !used.contains(x)).toList();
    if (rem.isNotEmpty) {
      var x = rem[0];
      used.add(x);
      result.add(Rule("$x must not be first", (order) => order.first != x));
    }

    var y = sample[3], z = sample[4];
    result.add(Rule("$y must come before $z",
        (order) => order.indexOf(y) < order.indexOf(z)));

    var w = sample[5];
    result.add(Rule("$w must not be last", (order) => order.last != w));

    return result;
  }

  @override
  void dispose() {
    timer?.cancel();
    _pulseController.dispose();
    _shakeController.dispose();
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4A1625),
              const Color(0xFF2D0F1A),
              const Color(0xFF1A0B11),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildScrollableContent(constraints),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableContent(BoxConstraints constraints) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: screenPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight - 120, // Account for header
        ),
        child: isLandscape && !isTablet
          ? _buildLandscapeLayout()
          : _buildPortraitLayout(),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Instructions and blocks
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildInstructions(),
              SizedBox(height: spacingMedium),
              _buildAvailableBlocks(),
              if (gameStarted) ...[
                SizedBox(height: spacingMedium),
                _buildRules(),
              ],
            ],
          ),
        ),
        SizedBox(width: spacingLarge),
        // Right column - Input and controls
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildInputFields(),
              SizedBox(height: spacingLarge),
              _buildActionButtons(),
              if (feedback.isNotEmpty) ...[
                SizedBox(height: spacingMedium),
                _buildFeedback(),
              ],
              if (pointsEarned > 0) ...[
                SizedBox(height: spacingMedium),
                _buildPointsDisplay(),
              ],
              if (!canPlay) ...[
                SizedBox(height: spacingMedium),
                _buildDailyLimitMessage(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInstructions(),
        SizedBox(height: spacingMedium),
        _buildAvailableBlocks(),
        SizedBox(height: spacingMedium),
        if (gameStarted) ...[
          _buildRules(),
          SizedBox(height: spacingLarge),
        ],
        _buildInputFields(),
        SizedBox(height: spacingLarge),
        _buildActionButtons(),
        if (feedback.isNotEmpty) ...[
          SizedBox(height: spacingMedium),
          _buildFeedback(),
        ],
        if (pointsEarned > 0) ...[
          SizedBox(height: spacingMedium),
          _buildPointsDisplay(),
        ],
        if (!canPlay) ...[
          SizedBox(height: spacingMedium),
          _buildDailyLimitMessage(),
        ],
        SizedBox(height: spacingMedium), // Bottom padding
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        screenPadding.left,
        screenPadding.top,
        screenPadding.right,
        spacingMedium,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A1625).withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
  children: [
    GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 10 : 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
          border: Border.all(
            color: const Color(0xFF8B2635).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: isTablet ? 22 : 18,
        ),
      ),
    ),
    Container(
      margin: EdgeInsets.only(left: 15),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF8B2635), const Color(0xFF4A1625)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 18 : 15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B2635).withOpacity(0.4),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.extension, 
        color: Colors.white, 
        size: isTablet ? 28 : 24,
      ),
    ),
          SizedBox(width: spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                  ).createShader(bounds),
                  child: Text(
                    'logic stack',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                Text(
                  'attempts: $attemptsToday/10',
                  style: GoogleFonts.poppins(
                    fontSize: subHeaderFontSize,
                    color: canPlay ? const Color(0xFFE91E63) : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          if (gameStarted && !gameCompleted)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8B2635), const Color(0xFF4A1625)],
                ),
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    color: Colors.white,
                    size: isTablet ? 18 : 14,
                  ),
                  SizedBox(width: spacingSmall),
                  Text(
                    '${elapsed}s',
                    style: GoogleFonts.poppins(
                      fontSize: bodyFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A1625).withOpacity(0.2),
            const Color(0xFF2D0F1A).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xFF4A1625).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFFE91E63),
                size: isTablet ? 24 : 20,
              ),
              SizedBox(width: spacingSmall),
              Text(
                'Instructions',
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE91E63),
                ),
              ),
            ],
          ),
          SizedBox(height: spacingSmall),
          Text(
            'Arrange the blocks to satisfy all logic rules:',
            style: GoogleFonts.poppins(
              fontSize: bodyFontSize,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableBlocks() {
    return Container(
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B2635).withOpacity(0.2),
            const Color(0xFF4A1625).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xFF8B2635).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Blocks:',
            style: GoogleFonts.poppins(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE91E63),
            ),
          ),
          SizedBox(height: spacingSmall),
          Wrap(
            spacing: spacingSmall,
            runSpacing: spacingSmall,
            children: selectedBlocks.map((block) => Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                ),
                borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withOpacity(0.3),
                    blurRadius: isTablet ? 6 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                block,
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRules() {
    return Container(
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFC2185B).withOpacity(0.2),
            const Color(0xFF8B2635).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xFFC2185B).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rules:',
            style: GoogleFonts.poppins(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE91E63),
            ),
          ),
          SizedBox(height: spacingSmall),
          ...rules.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: spacingSmall),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: isTablet ? 24 : 20,
                    height: isTablet ? 24 : 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: smallFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: spacingSmall),
                  Expanded(
                    child: Text(
                      entry.value.description,
                      style: GoogleFonts.poppins(
                        fontSize: bodyFontSize,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInputFields() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: Container(
            padding: containerPadding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF880E4F).withOpacity(0.2),
                  const Color(0xFF4A1625).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              border: Border.all(
                color: const Color(0xFF880E4F).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Solution:',
                  style: GoogleFonts.poppins(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE91E63),
                  ),
                ),
                SizedBox(height: spacingMedium),
                isLandscape && !isTablet
                  ? Column(
                      children: [
                        Row(
                          children: List.generate(3, (index) => _buildInputField(index)).toList(),
                        ),
                        SizedBox(height: spacingSmall),
                        Row(
                          children: List.generate(3, (index) => _buildInputField(index + 3)).toList(),
                        ),
                      ],
                    )
                  : Row(
                      children: List.generate(6, (index) => _buildInputField(index)).toList(),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputField(int index) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: TextField(
          controller: controllers[index],
          onChanged: (value) {
            inputs[index] = value;
            if (value.isNotEmpty && index < 5) {
              FocusScope.of(context).nextFocus();
            }
          },
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: inputFontSize,
            fontWeight: FontWeight.bold,
          ),
          maxLength: 1,
          enabled: canPlay && !gameCompleted,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF1A0B11).withOpacity(0.5),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
              borderSide: BorderSide(
                color: const Color(0xFFE91E63).withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
              borderSide: BorderSide(
                color: const Color(0xFFE91E63),
                width: isTablet ? 3 : 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
              borderSide: BorderSide(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: isTablet ? 20 : 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF4CAF50), const Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              boxShadow: (!gameStarted && canPlay) || (gameStarted && !gameCompleted) ? [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: isTablet ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            child: ElevatedButton(
              onPressed: !gameStarted && canPlay ? _startGame : 
                         (gameStarted && !gameCompleted ? checkAnswer : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 20 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                ),
              ),
              child: Text(
                !gameStarted ? "START GAME" : "SUBMIT",
                style: GoogleFonts.poppins(
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: spacingMedium),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF8B2635), const Color(0xFF4A1625)],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
          ),
          child: ElevatedButton(
            onPressed: gameCompleted || !gameStarted ? _initializeGame : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 20 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
            ),
            child: Icon(
              Icons.refresh,
              color: Colors.white,
              size: isTablet ? 24 : 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback() {
    return Container(
      width: double.infinity,
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: feedback.startsWith('❌') ? [
            Colors.red.withOpacity(0.2),
            Colors.red.withOpacity(0.1),
          ] : [
            Colors.green.withOpacity(0.2),
            Colors.green.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: feedback.startsWith('❌') 
              ? Colors.red.withOpacity(0.5)
              : Colors.green.withOpacity(0.5),
        ),
      ),
      child: Text(
        feedback,
        style: GoogleFonts.poppins(
          fontSize: bodyFontSize,
          color: Colors.white,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPointsDisplay() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: containerPadding.horizontal,
        vertical: spacingMedium,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.4),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star,
            color: Colors.white,
            size: isTablet ? 26 : 22,
          ),
          SizedBox(width: spacingSmall),
          Text(
            "+$pointsEarned points earned!",
            style: GoogleFonts.poppins(
              fontSize: titleFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLimitMessage() {
    return Container(
      width: double.infinity,
      padding: containerPadding,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.access_time,
            color: Colors.red,
            size: isTablet ? 26 : 22,
          ),
          SizedBox(width: spacingSmall),
          Expanded(
            child: Text(
              "Daily limit reached (10/10). Try again tomorrow!",
              style: GoogleFonts.poppins(
                fontSize: bodyFontSize,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Rule {
  final String description;
  final bool Function(List<String>) validate;
  Rule(this.description, this.validate);
}