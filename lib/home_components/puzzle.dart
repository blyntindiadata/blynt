import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  List<String> solution = List.filled(6, '');
  List<Rule> rules = [];
  int elapsed = 0;
  Timer? timer;
  String feedback = '';
  bool gameStarted = false;
  bool gameCompleted = false;
  // int attemptsToday = 0;
  int pointsEarned = 0;
  // bool canPlay = true;
int successfulCompletions = 0;

// Ad-related variables
RewardedAd? _rewardedAd;
bool _isAdLoaded = false;
bool _showingAd = false;



  // Animation controllers for smooth interactions
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _successController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _successAnimation;

  // Drag and drop state
  String? _draggingBlock;
  int? _draggedFromIndex;
  int? _hoveredIndex;

  // Enhanced responsive design helpers
  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;
  bool get isLandscape => MediaQuery.of(context).orientation == Orientation.landscape;
  bool get isSmallDevice => MediaQuery.of(context).size.height < 600;
  bool get isCompact => MediaQuery.of(context).size.width < 400;
  bool get isExtraLarge => MediaQuery.of(context).size.shortestSide >= 900;
  
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  double get safeAreaHeight => screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
  
  // Improved dynamic sizing with better scaling
  double get headerFontSize {
    if (isExtraLarge) return 32;
    if (isTablet) return 28;
    if (isCompact) return 16;
    if (isSmallDevice) return 18;
    return 22;
  }
  
  double get subHeaderFontSize {
    if (isExtraLarge) return 16;
    if (isTablet) return 14;
    if (isCompact) return 9;
    if (isSmallDevice) return 10;
    return 12;
  }
  
  double get titleFontSize {
    if (isExtraLarge) return 24;
    if (isTablet) return 20;
    if (isCompact) return 12;
    if (isSmallDevice) return 14;
    return 16;
  }
  
  double get bodyFontSize {
    if (isExtraLarge) return 20;
    if (isTablet) return 16;
    if (isCompact) return 12;
    if (isSmallDevice) return 13;
    return 14;
  }
  
  double get smallFontSize {
    if (isExtraLarge) return 16;
    if (isTablet) return 14;
    if (isCompact) return 9;
    if (isSmallDevice) return 10;
    return 12;
  }
  
  double get buttonFontSize {
    if (isExtraLarge) return 20;
    if (isTablet) return 18;
    if (isCompact) return 12;
    if (isSmallDevice) return 14;
    return 16;
  }
  
  double get blockFontSize {
    if (isExtraLarge) return 28;
    if (isTablet) return 24;
    if (isCompact) return 16;
    if (isSmallDevice) return 18;
    return 20;
  }
  
  EdgeInsets get screenPadding {
    if (isExtraLarge) return const EdgeInsets.all(32);
    if (isTablet) return const EdgeInsets.all(24);
    if (isCompact) return const EdgeInsets.all(10);
    if (isSmallDevice) return const EdgeInsets.all(12);
    return const EdgeInsets.all(16);
  }
  
  EdgeInsets get containerPadding {
    if (isExtraLarge) return const EdgeInsets.all(32);
    if (isTablet) return const EdgeInsets.all(24);
    if (isCompact) return const EdgeInsets.all(16);
    if (isSmallDevice) return const EdgeInsets.all(18);
    return const EdgeInsets.all(20);
  }
  
  double get spacingSmall {
    if (isExtraLarge) return 16;
    if (isTablet) return 12;
    if (isCompact) return 4;
    if (isSmallDevice) return 6;
    return 8;
  }
  
  double get spacingMedium {
    if (isExtraLarge) return 28;
    if (isTablet) return 20;
    if (isCompact) return 8;
    if (isSmallDevice) return 12;
    return 16;
  }
  
  double get spacingLarge {
    if (isExtraLarge) return 40;
    if (isTablet) return 32;
    if (isCompact) return 12;
    if (isSmallDevice) return 16;
    return 24;
  }
  
  double get blockSize {
    if (isExtraLarge) return 80;
    if (isTablet) return 70;
    if (isCompact) return 45;
    if (isSmallDevice) return 50;
    return 60;
  }

 @override
void initState() {
  super.initState();
  _initAnimations();
  
  // Load success data first, then ad
  _loadSuccessfulCompletions().then((_) {
    _loadRewardedAd();
  });
  
  // Initialize game WITHOUT counting as attempt on first load
  selectedBlocks = blocks.toList()..shuffle();
  selectedBlocks = selectedBlocks.sublist(0, 6);
  rules = generateRules(selectedBlocks);
  
  setState(() {
    solution = List.filled(6, '');
  });
}

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _successController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.1)).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );
    _successAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );

    _pulseController.repeat(reverse: true);
  }

 // Replace entire method with:
void _loadRewardedAd() {
  print('Loading Logic Stack rewarded ad...');
  RewardedAd.load(
    adUnitId: 'ca-app-pub-3940256099942544/5224354917', // Test ad ID
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (RewardedAd ad) {
        print('Logic Stack ad loaded successfully');
        setState(() {
          _rewardedAd = ad;
          _isAdLoaded = true;
        });
      },
      onAdFailedToLoad: (LoadAdError error) {
        print('Logic Stack ad failed to load: $error');
        setState(() {
          _isAdLoaded = false;
        });
        // Retry loading after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _loadRewardedAd();
          }
        });
      },
    ),
  );
}

// Replace entire method with:
void _showRewardedAd() {
  if (_isAdLoaded && _rewardedAd != null && !_showingAd) {
    print('Showing Logic Stack ad after successful completion');
    _showingAd = true;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _showingAd = false;
        _isAdLoaded = false;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _showingAd = false;
        _isAdLoaded = false;
        _loadRewardedAd();
      },
    );
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('User earned reward: ${reward.amount} ${reward.type}');
      },
    );
  }
}
Future<void> _loadSuccessfulCompletions() async {
  try {
    final successDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('user_stats')
        .doc('${widget.username}_puzzle_successes')
        .get();

    if (successDoc.exists) {
      final data = successDoc.data() as Map<String, dynamic>;
      setState(() {
        successfulCompletions = data['successfulCompletions'] ?? 0;
      });
    }
  } catch (e) {
    print('Error loading successful completions: $e');
  }
}

void _waitForAdThenShow() {
  // Check every 500ms if ad is loaded, up to 10 seconds
  int attempts = 0;
  Timer.periodic(const Duration(milliseconds: 500), (timer) {
    attempts++;
    if (_isAdLoaded && !_showingAd) {
      timer.cancel();
      print('Ad loaded, showing now');
      _showRewardedAd();
    } else if (attempts >= 20) { // 10 seconds timeout
      timer.cancel();
      print('Ad loading timeout, continuing without ad');
    }
  });
}

Future<void> _updateSuccessfulCompletions() async {
  try {
    final successRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('user_stats')
        .doc('${widget.username}_puzzle_successes');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final successDoc = await transaction.get(successRef);
      final currentData = successDoc.exists ? successDoc.data() as Map<String, dynamic> : {};
      
      final newSuccessfulCompletions = (currentData['successfulCompletions'] ?? 0) + 1;

      transaction.set(successRef, {
        'username': widget.username,
        'successfulCompletions': newSuccessfulCompletions,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      setState(() {
        successfulCompletions = newSuccessfulCompletions;
      });

      // Show ad every 3 successful completions
      if (successfulCompletions % 3 == 0) {
        print('Showing ad after $successfulCompletions successful completions');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            _showRewardedAd();
          }
        });
      }
    });
  } catch (e) {
    print('Error updating successful completions: $e');
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

void _initializeGame() async {
  // Cancel any running timer
  timer?.cancel();
  
  selectedBlocks = blocks.toList()..shuffle();
  selectedBlocks = selectedBlocks.sublist(0, 6);
  rules = generateRules(selectedBlocks);
  
  setState(() {
    solution = List.filled(6, '');
    feedback = '';
    gameStarted = false;
    gameCompleted = false;
    elapsed = 0;  // Reset elapsed time
    pointsEarned = 0;
    _draggingBlock = null;
    _draggedFromIndex = null;
    _hoveredIndex = null;
  });
}

void _startGame() async {
  // Cancel any existing timer first
  timer?.cancel();
  
  setState(() {
    gameStarted = true;
    elapsed = 0;
  });
  
  // Create new timer
  timer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) {
      setState(() => elapsed++);
    }
  });
}

  void _checkAnswer() async {
  if (!gameStarted || gameCompleted || solution.contains('')) return;
  
  List<String> violations = rules
      .where((rule) => !rule.validate(solution))
      .map((rule) => rule.description)
      .toList();

  if (violations.isEmpty) {
    timer?.cancel();
    
    int points = 0;
    String reward = "";

    if (elapsed < 8) {
      points = 800;
      reward = "no way dude! +800 points!";
    } else if (elapsed < 14) {
      points = 600;
      reward = "okay now that is competitive +600 points!";
    } else if (elapsed < 20) {
      points = 250;
      reward = "fair enough +250 points!";
    } else {
      reward = "you really thought we would give you points for this?";
    }

    _successController.forward();
    
    setState(() {
  gameCompleted = true;
  feedback = "Correct! Solved in ${elapsed}s\n$reward";
  pointsEarned = points;
});

    // Don't count completing the game as an additional attempt
    // The attempt was already counted when game started
    
  if (points > 0) {
  await _updateScore(points);
  await _updateSuccessfulCompletions(); // Track successful completion
}
  } else {
    _shakeController.forward().then((_) => _shakeController.reset());
    setState(() => feedback = "Violations:\n• ${violations.join("\n• ")}");
  }
}

  // Drag and drop handlers
  void _onBlockDragStart(String block, int? fromIndex) {
    setState(() {
      _draggingBlock = block;
      _draggedFromIndex = fromIndex;
    });
  }

  void _onBlockDragEnd() {
    setState(() {
      _draggingBlock = null;
      _draggedFromIndex = null;
      _hoveredIndex = null;
    });
  }

  void _onSlotDragAccept(String block, int slotIndex) {
    setState(() {
      // If there's already a block in the target slot, swap positions
      String existingBlock = solution[slotIndex];
      
      // Place the dragged block in the target slot
      solution[slotIndex] = block;
      
      // If block came from another slot, handle the swap
      if (_draggedFromIndex != null) {
        if (existingBlock.isNotEmpty) {
          // Swap: put the existing block in the source slot
          solution[_draggedFromIndex!] = existingBlock;
        } else {
          // Just move: clear the source slot
          solution[_draggedFromIndex!] = '';
        }
      }
      // If dragging from available blocks and target slot had a block,
      // the existing block stays in the available pool (no action needed)
    });
    
    _slideController.forward().then((_) => _slideController.reset());
  }

  void _onSlotDragEnter(int slotIndex) {
    setState(() {
      _hoveredIndex = slotIndex;
    });
  }

  void _onSlotDragLeave() {
    setState(() {
      _hoveredIndex = null;
    });
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
    _rewardedAd?.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A1625),
              Color(0xFF2D0F1A),
              Color(0xFF1A0B11),
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
          minHeight: constraints.maxHeight - 120,
        ),
        child: isLandscape && !isTablet && !isSmallDevice
          ? _buildLandscapeLayout()
          : _buildPortraitLayout(),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildSolutionSlots(),
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
              // if (!canPlay) ...[
              //   SizedBox(height: spacingMedium),
              //   _buildDailyLimitMessage(),
              // ],
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
        _buildSolutionSlots(),
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
        // if (!canPlay) ...[
        //   SizedBox(height: spacingMedium),
        //   _buildDailyLimitMessage(),
        // ],
        SizedBox(height: spacingMedium),
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
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //     colors: [
      //       const Color(0xFF4A1625).withOpacity(0.3),
      //       Colors.transparent,
      //     ],
      //   ),
      // ),
      child: Row(
        children: [
          _buildAnimatedButton(
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
            margin: const EdgeInsets.only(left: 15),
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B2635), Color(0xFF4A1625)],
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
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
                  ).createShader(bounds),
                  child: Text(
                    'letters of fury',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                  SizedBox(height: spacingSmall / 2),
_buildCompactScoringInfo(),
                
                // Text(
                //   'attempts: $attemptsToday/10',
                //   style: GoogleFonts.poppins(
                //     fontSize: subHeaderFontSize,
                //     color: canPlay ? const Color(0xFFE91E63) : Colors.red,
                //   ),
                // ),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B2635), Color(0xFF4A1625)],
                ),
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B2635).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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

  Widget _buildCompactScoringInfo() {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isTablet ? 12 : 8,
      vertical: isTablet ? 6 : 4,
    ),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.3),
      borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
      border: Border.all(
        color: const Color(0xFFE91E63).withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.flash_on,
          color: const Color(0xFFE91E63),
          size: isTablet ? 14 : 10,
        ),
        SizedBox(width: isTablet ? 4 : 2),
        Text(
          '<8s: 800pts',
          style: GoogleFonts.poppins(
            fontSize: isExtraLarge ? 11 : (isTablet ? 10 : (isCompact ? 7 : 8)),
            color: Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: isTablet ? 8 : 4),
        Container(
          width: 1,
          height: isTablet ? 12 : 8,
          color: Colors.white.withOpacity(0.3),
        ),
        SizedBox(width: isTablet ? 8 : 4),
        Text(
          '<14s: 600pts',
          style: GoogleFonts.poppins(
            fontSize: isExtraLarge ? 11 : (isTablet ? 10 : (isCompact ? 7 : 8)),
            color: Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: isTablet ? 8 : 4),
        Container(
          width: 1,
          height: isTablet ? 12 : 8,
          color: Colors.white.withOpacity(0.3),
        ),
        SizedBox(width: isTablet ? 8 : 4),
        Text(
          '<20s: 250pts',
          style: GoogleFonts.poppins(
            fontSize: isExtraLarge ? 11 : (isTablet ? 10 : (isCompact ? 7 : 8)),
            color: Colors.yellow,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

  Widget _buildAnimatedButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, _) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildInstructions() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
              Container(
                padding: EdgeInsets.all(isTablet ? 8 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline,
                  color: const Color(0xFFE91E63),
                  size: isTablet ? 20 : 16,
                ),
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
            'Drag blocks to arrange them and satisfy all logic rules. Start the game to begin!',
            style: GoogleFonts.poppins(
              fontSize: bodyFontSize,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableBlocks() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
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
          SizedBox(height: spacingMedium),
          if (!gameStarted)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(spacingLarge),
              decoration: BoxDecoration(
                color: const Color(0xFF1A0B11).withOpacity(0.3),
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                border: Border.all(
                  color: const Color(0xFFE91E63).withOpacity(0.2),
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.white.withOpacity(0.4),
                    size: isTablet ? 32 : 24,
                  ),
                  SizedBox(height: spacingSmall),
                  Text(
                    'Start the game to see blocks',
                    style: GoogleFonts.poppins(
                      fontSize: bodyFontSize,
                      color: Colors.white.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: spacingSmall,
              runSpacing: spacingSmall,
              children: selectedBlocks.map((block) => _buildDraggableBlock(block, null)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableBlock(String block, int? fromSlotIndex) {
    final isInUse = solution.contains(block) && fromSlotIndex == null;
    final isDragging = _draggingBlock == block;
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isInUse ? 0.3 : (isDragging ? 0.7 : 1.0),
      child: Draggable<String>(
        data: block,
        onDragStarted: () => _onBlockDragStart(block, fromSlotIndex),
        onDragEnd: (_) => _onBlockDragEnd(),
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.1,
            child: _buildBlockWidget(block, true),
          ),
        ),
        childWhenDragging: Container(
          width: blockSize,
          height: blockSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
            border: Border.all(
              color: const Color(0xFFE91E63).withOpacity(0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
        ),
        child: _buildBlockWidget(block, false),
      ),
    );
  }

  Widget _buildBlockWidget(String block, bool isDragFeedback) {
    return AnimatedContainer(
      duration: Duration(milliseconds: isDragFeedback ? 0 : 200),
      curve: Curves.easeOut,
      width: blockSize,
      height: blockSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE91E63),
            const Color(0xFF8B2635),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        boxShadow: isDragFeedback ? [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.6),
            blurRadius: isTablet ? 20 : 15,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ] : [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.3),
            blurRadius: isTablet ? 8 : 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          block,
          style: GoogleFonts.poppins(
            fontSize: blockFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSolutionSlots() {
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
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 8 : 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.tune,
                        color: const Color(0xFFE91E63),
                        size: isTablet ? 20 : 16,
                      ),
                    ),
                    SizedBox(width: spacingSmall),
                    Text(
                      'Your Solution:',
                      style: GoogleFonts.poppins(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE91E63),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: spacingMedium),
                _buildSolutionGrid(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSolutionGrid() {
    // Determine grid layout based on screen size
    bool useVerticalLayout = isCompact || (isLandscape && isSmallDevice);
    
    if (useVerticalLayout) {
      return Column(
        children: [
          Row(
            children: List.generate(3, (index) => _buildSolutionSlot(index)).toList(),
          ),
          SizedBox(height: spacingSmall),
          Row(
            children: List.generate(3, (index) => _buildSolutionSlot(index + 3)).toList(),
          ),
        ],
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(6, (index) => _buildSolutionSlot(index)).toList(),
        ),
      );
    }
  }

  Widget _buildSolutionSlot(int index) {
    final isHovered = _hoveredIndex == index;
    final hasBlock = solution[index].isNotEmpty;
    
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: spacingSmall / 2),
        child: AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return SlideTransition(
              position: hasBlock ? _slideAnimation : AlwaysStoppedAnimation(Offset.zero),
              child: DragTarget<String>(
                onAccept: (block) => _onSlotDragAccept(block, index),
                onMove: (_) => _onSlotDragEnter(index),
                onLeave: (_) => _onSlotDragLeave(),
                builder: (context, candidateData, rejectedData) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: blockSize,
                    height: blockSize,
                    decoration: BoxDecoration(
                      gradient: hasBlock ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE91E63),
                          const Color(0xFF8B2635),
                        ],
                      ) : LinearGradient(
                        colors: [
                          isHovered 
                            ? const Color(0xFFE91E63).withOpacity(0.3)
                            : const Color(0xFF1A0B11).withOpacity(0.5),
                          isHovered 
                            ? const Color(0xFF8B2635).withOpacity(0.2)
                            : const Color(0xFF0D0507).withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                      border: Border.all(
                        color: isHovered 
                          ? const Color(0xFFE91E63)
                          : const Color(0xFFE91E63).withOpacity(0.3),
                        width: isHovered ? 3 : 2,
                        style: hasBlock ? BorderStyle.solid : BorderStyle.solid,
                      ),
                      boxShadow: [
                        if (hasBlock) BoxShadow(
                          color: const Color(0xFFE91E63).withOpacity(0.3),
                          blurRadius: isTablet ? 8 : 6,
                          offset: const Offset(0, 3),
                        ),
                        if (isHovered) BoxShadow(
                          color: const Color(0xFFE91E63).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: hasBlock 
                      ? GestureDetector(
                          onLongPress: () {
                            // Provide haptic feedback for long press
                            setState(() {
                              solution[index] = '';
                            });
                          },
                          child: Draggable<String>(
                            data: solution[index],
                            onDragStarted: () => _onBlockDragStart(solution[index], index),
                            onDragEnd: (_) => _onBlockDragEnd(),
                            feedback: Material(
                              color: Colors.transparent,
                              child: Transform.scale(
                                scale: 1.2,
                                child: _buildBlockWidget(solution[index], true),
                              ),
                            ),
                            childWhenDragging: Container(
                              width: blockSize,
                              height: blockSize,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                                border: Border.all(
                                  color: const Color(0xFFE91E63).withOpacity(0.5),
                                  width: 3,
                                  style: BorderStyle.solid,
                                ),
                                color: const Color(0xFF1A0B11).withOpacity(0.3),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.open_with,
                                  color: const Color(0xFFE91E63).withOpacity(0.7),
                                  size: isTablet ? 24 : 20,
                                ),
                              ),
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: blockSize,
                              height: blockSize,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFE91E63),
                                    Color(0xFF8B2635),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFE91E63).withOpacity(0.4),
                                    blurRadius: isTablet ? 10 : 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Text(
                                      solution[index],
                                      style: GoogleFonts.poppins(
                                        fontSize: blockFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  // Visual indicator that block can be moved
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.drag_indicator,
                                        color: Colors.white.withOpacity(0.8),
                                        size: isTablet ? 12 : 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withOpacity(0.4),
                            ),
                          ),
                        ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRules() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
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
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 8 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.rule,
                  color: const Color(0xFFE91E63),
                  size: isTablet ? 20 : 16,
                ),
              ),
              SizedBox(width: spacingSmall),
              Text(
                'Rules:',
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFE91E63),
                ),
              ),
            ],
          ),
          SizedBox(height: spacingMedium),
          ...rules.asMap().entries.map((entry) {
            return AnimatedContainer(
              duration: Duration(milliseconds: 200 + (entry.key * 50)),
              margin: EdgeInsets.only(bottom: spacingSmall),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isTablet ? 28 : 22,
                    height: isTablet ? 28 : 22,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E63).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                  SizedBox(width: spacingMedium),
                  Expanded(
                    child: Text(
                      entry.value.description,
                      style: GoogleFonts.poppins(
                        fontSize: bodyFontSize,
                        color: Colors.white,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
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

  Widget _buildActionButtons() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _buildAnimatedButton(
              onTap: !gameStarted? _startGame : 
                     (gameStarted && !gameCompleted && !solution.contains('') ? _checkAnswer : () {}),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  vertical: isExtraLarge ? 24 : (isTablet ? 20 : (isCompact ? 14 : 16)),
                ),
                decoration: BoxDecoration(
                  gradient: (!gameStarted) || (gameStarted && !gameCompleted && !solution.contains('')) 
                    ? const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                      )
                    : LinearGradient(
                        colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)],
                      ),
                  borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
                  boxShadow: (!gameStarted) || (gameStarted && !gameCompleted && !solution.contains('')) ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withOpacity(0.4),
                      blurRadius: isTablet ? 16 : 12,
                      offset: const Offset(0, 6),
                    ),
                  ] : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 10 : 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        !gameStarted ? Icons.play_arrow : Icons.check,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                    ),
                    SizedBox(width: spacingSmall),
                    Text(
                      !gameStarted ? "START GAME" : "CHECK SOLUTION",
                      style: GoogleFonts.poppins(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: spacingMedium),
          _buildAnimatedButton(
  onTap: _initializeGame, // Always allow reset
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isExtraLarge ? 24 : (isTablet ? 20 : (isCompact ? 14 : 16))),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B2635), Color(0xFF4A1625)],
                ),
                borderRadius: BorderRadius.circular(isTablet ? 18 : 14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B2635).withOpacity(0.3),
                    blurRadius: isTablet ? 12 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: feedback.startsWith('Correct') ? [
            Colors.green.withOpacity(0.25),
            Colors.green.withOpacity(0.15),
          ] : [
            Colors.red.withOpacity(0.25),
            Colors.red.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: feedback.startsWith('Correct') 
              ? Colors.green.withOpacity(0.6)
              : Colors.red.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (feedback.startsWith('Correct') ? Colors.green : Colors.red).withOpacity(0.2),
            blurRadius: isTablet ? 15 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: (feedback.startsWith('Correct') ? Colors.green : Colors.red).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              feedback.startsWith('Correct') ? Icons.check_circle : Icons.error,
              color: feedback.startsWith('Correct') ? Colors.green : Colors.red,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: spacingMedium),
          Expanded(
            child: Text(
              feedback,
              style: GoogleFonts.poppins(
                fontSize: bodyFontSize,
                color: Colors.white,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsDisplay() {
    return AnimatedBuilder(
      animation: _successAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _successAnimation.value,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: containerPadding.horizontal,
              vertical: spacingMedium,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
              ),
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE91E63).withOpacity(0.5),
                  blurRadius: isTablet ? 20 : 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 12 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.white,
                    size: isTablet ? 28 : 24,
                  ),
                ),
                SizedBox(width: spacingMedium),
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
          ),
        );
      },
    );
  }

  Widget _buildDailyLimitMessage() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.25), Colors.red.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: Colors.red.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: isTablet ? 15 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time,
              color: Colors.red,
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(width: spacingMedium),
          Expanded(
            child: Text(
              "Daily limit reached (10/10). Try again tomorrow!",
              style: GoogleFonts.poppins(
                fontSize: bodyFontSize,
                color: Colors.red,
                fontWeight: FontWeight.w500,
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