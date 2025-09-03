import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class PerfectTimerGame extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const PerfectTimerGame({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<PerfectTimerGame> createState() => _PerfectTimerGameState();
}

class _PerfectTimerGameState extends State<PerfectTimerGame>
    with TickerProviderStateMixin {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  double _elapsedSeconds = 0.0;
  String _message = "Hit exactly 10.00 seconds!";
  bool _gameStarted = false;
  bool _gameEnded = false;
  int _pointsEarned = 0;
  
  // Ad-related variables
 RewardedAd? _rewardedAd;
int totalAttempts = 0;
int lastAdAttempt = 0; 
bool _isAdLoaded = false;
bool _showingAd = false;

  // Replace with your actual Ad Unit ID from AdMob
  static const String _rewardedAdUnitId  = 'ca-app-pub-3940256099942544/5224354917'; 

  // Animation controllers for smooth interactions
  late AnimationController _buttonAnimationController;  
  late AnimationController _pulseAnimationController;
  late AnimationController _scaleAnimationController;
  
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  // Responsive design helpers with improved calculations
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
  
  double get timerFontSize {
    if (isExtraLarge) return 72;
    if (isTablet) return 64;
    if (isCompact) return 32;
    if (isSmallDevice) return 36;
    return 48;
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
    if (isTablet) return 18;
    if (isCompact) return 13;
    if (isSmallDevice) return 14;
    return 16;
  }
  
  double get smallFontSize {
    if (isExtraLarge) return 16;
    if (isTablet) return 14;
    if (isCompact) return 9;
    if (isSmallDevice) return 10;
    return 12;
  }
  
  double get buttonFontSize {
    if (isExtraLarge) return 18;
    if (isTablet) return 16;
    if (isCompact) return 11;
    if (isSmallDevice) return 12;
    return 14;
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
    if (isTablet) return const EdgeInsets.all(28);
    if (isCompact) return const EdgeInsets.all(16);
    if (isSmallDevice) return const EdgeInsets.all(18);
    return const EdgeInsets.all(24);
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
  
  double get spacingXLarge {
    if (isExtraLarge) return 64;
    if (isTablet) return 48;
    if (isCompact) return 16;
    if (isSmallDevice) return 24;
    return 32;
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTotalAttempts();
    _loadRewardedAd();
  }

  void _initializeAnimations() {
    _buttonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimationController.repeat(reverse: true);
  }

  // Load interstitial ad
  void _loadRewardedAd() {
  RewardedAd.load(
    adUnitId: _rewardedAdUnitId,
    request: const AdRequest(),
    rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (RewardedAd ad) {
        _rewardedAd = ad;
        _isAdLoaded = true;
      },
      onAdFailedToLoad: (LoadAdError error) {
        print('RewardedAd failed to load: $error');
        _isAdLoaded = false;
        Timer(const Duration(seconds: 5), () {
          _loadRewardedAd();
        });
      },
    ),
  );
}

Future<void> _loadTotalAttempts() async {
  int retryCount = 0;
  while (retryCount < 3) {
    try {
      final totalDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('user_stats')
          .doc('${widget.username}_timer_total_attempts')
          .get();

      if (totalDoc.exists) {
        final data = totalDoc.data() as Map<String, dynamic>;
        setState(() {
          totalAttempts = data['totalAttempts'] ?? 0;
          lastAdAttempt = data['lastAdAttempt'] ?? 0; // Load last ad attempt
        });
      }
      return;
    } catch (e) {
      retryCount++;
      print('Error loading attempts (attempt $retryCount): $e');
      if (retryCount < 3) {
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }
}
Future<void> _updateAttempts() async {
  try {
    final totalRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('user_stats')
        .doc('${widget.username}_timer_total_attempts');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final totalDoc = await transaction.get(totalRef);
      final currentData = totalDoc.exists ? totalDoc.data() as Map<String, dynamic> : {};
      
      final newTotalAttempts = (currentData['totalAttempts'] ?? 0) + 1;
      final currentLastAdAttempt = currentData['lastAdAttempt'] ?? 0;

      // Check if we should show ad (every 3 attempts since last ad)
      bool shouldShowAd = (newTotalAttempts - currentLastAdAttempt) >= 3;
      int newLastAdAttempt = shouldShowAd ? newTotalAttempts : currentLastAdAttempt;

      transaction.set(totalRef, {
        'username': widget.username,
        'totalAttempts': newTotalAttempts,
        'lastAdAttempt': newLastAdAttempt,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        totalAttempts = newTotalAttempts;
        lastAdAttempt = newLastAdAttempt;
      });

      // Show ad if needed
      if (shouldShowAd) {
        _showRewardedAd();
      }
    });
  } catch (e) {
    print('Error updating attempts: $e');
  }
}

void _showRewardedAd() {
  if (_isAdLoaded && _rewardedAd != null && !_showingAd) {
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

  // Show ad if available and conditions are met
  

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
          final currentTimerPoints = currentData['timerPoints'] ?? 0;
          final currentTotalPoints = currentData['totalPoints'] ?? 0;
          
          transaction.update(scoreRef, {
            'timerPoints': currentTimerPoints + points,
            'totalPoints': currentTotalPoints + points,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(scoreRef, {
            'username': widget.username,
            'timerPoints': points,
            'puzzlePoints': 0,
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

  void _start() {
    _stopwatch.reset();
    _stopwatch.start();
    
    setState(() {
      _message = "Timer running... Stop when you hit 10 seconds!";
      _gameStarted = true;
      _gameEnded = false;
      _pointsEarned = 0;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      setState(() {
        _elapsedSeconds = _stopwatch.elapsedMicroseconds / 1000000.0;
      });
    });
  }

  void _stop() async {
    if (!_gameStarted || _gameEnded) return;
    
    _stopwatch.stop();
    _timer?.cancel();
    
    setState(() {
      _gameEnded = true;
    });

    double diff = (_elapsedSeconds - 10.0).abs();
    String result;
    int points = 0;

    // Check for exact match first (within microsecond precision)
    if (diff < 0.005) { // Less than 1 millisecond difference
      result = "🎯 BEYOND MAGIC - EXACTLY 10.00 SECONDS!";
      points = 1000;
    } else if (diff <= 0.01) { // Within 10 milliseconds
      result = "🔥 ON GOD";
      points = 800;
    } else if (diff <= 0.05) { // Within 50 milliseconds
      result = "⚡ YOUR FINGERS SEEM CRAZY";
      points = 600;
    } else if (diff <= 0.1) {
      result = "⭐ fair enough";
      points = 400;
    } else if (diff <= 0.2) {
      result = "👍 c\'mon you can do it faster";
      points = 200;
    } else if (diff <= 0.5) {
      result = "✅ you don\'t deserve even these 100 points ";
      points = 100;
    } else {
      result = "what even";
      points = 0;
    }

    setState(() {
      _message = result;
      _pointsEarned = points;
    });

    // Show ad if needed (every 3 games)
    await _updateAttempts();

    if (points > 0) {
      await _updateScore(points);
    }
  }

  void _reset() {
  // Don't update attempts on reset, only on actual game completion
  _stopwatch.reset();
  _timer?.cancel();
  
  setState(() {
    _elapsedSeconds = 0.0;
    _message = "Hit exactly 10.00 seconds!";
    _gameStarted = false;
    _gameEnded = false;
    _pointsEarned = 0;
  });
}
  @override
  void dispose() {
    _timer?.cancel();
    _buttonAnimationController.dispose();
    _pulseAnimationController.dispose();
    _scaleAnimationController.dispose();
    _rewardedAd?.dispose();
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
          minHeight: constraints.maxHeight - 120, // Account for header
        ),
        child: isLandscape && !isTablet && !isSmallDevice
          ? _buildLandscapeLayout()
          : _buildPortraitLayout(),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side - Timer and target
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTimerDisplay(),
              SizedBox(height: spacingLarge),
              _buildTargetIndicator(),
            ],
          ),
        ),
        SizedBox(width: spacingLarge),
        // Right side - Controls and feedback
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMessageCard(),
              SizedBox(height: spacingMedium),
              if (_pointsEarned > 0) ...[
                _buildPointsDisplay(),
                SizedBox(height: spacingMedium),
              ],
              _buildControlButtons(),
              SizedBox(height: spacingMedium),
              // _buildGameCounter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: spacingMedium),
        
        // Timer Display
        _buildTimerDisplay(),
        
        SizedBox(height: spacingLarge),
        
        // Target indicator
        _buildTargetIndicator(),
        
        SizedBox(height: spacingLarge),
        
        // Message Card
        _buildMessageCard(),
        
        SizedBox(height: spacingMedium),
        
        // Points display
        if (_pointsEarned > 0) ...[
          _buildPointsDisplay(),
          SizedBox(height: spacingMedium),
        ],
        
        // Control buttons
        _buildControlButtons(),
        
        SizedBox(height: spacingMedium),
        
        // Game counter
        // _buildGameCounter(),
        
        SizedBox(height: spacingXLarge),
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
              Icons.timer, 
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
                    'lord of the ticks',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                Text(
                'attempts: $totalAttempts',
                  style: GoogleFonts.poppins(
                    fontSize: subHeaderFontSize,
                    color: const Color(0xFFE91E63),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

 

  Widget _buildTimerDisplay() {
    double circleSize = isExtraLarge ? 280 : (isTablet ? 240 : (isCompact ? 140 : (isSmallDevice ? 160 : 200)));
    
    return AnimatedBuilder(
      animation: _gameStarted ? _pulseAnimation : kAlwaysCompleteAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _gameStarted ? _pulseAnimation.value : 1.0,
          child: Container(
            width: circleSize,
            height: circleSize,
            padding: EdgeInsets.all(isExtraLarge ? 60 : (isTablet ? 50 : (isCompact ? 25 : (isSmallDevice ? 30 : 40)))),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE91E63).withOpacity(0.3),
                  const Color(0xFF8B2635).withOpacity(0.2),
                  const Color(0xFF4A1625).withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: _gameStarted 
                  ? const Color(0xFFE91E63) 
                  : const Color(0xFFE91E63).withOpacity(0.5),
                width: isTablet ? 4 : 3,
              ),
              boxShadow: [
                if (_gameStarted) BoxShadow(
                  color: const Color(0xFFE91E63).withOpacity(0.4),
                  blurRadius: isTablet ? 40 : 30,
                  spreadRadius: isTablet ? 4 : 2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _elapsedSeconds.toStringAsFixed(2),
                    style: GoogleFonts.poppins(
                      fontSize: timerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: isTablet ? 3 : 2,
                    ),
                  ),
                ),
                SizedBox(height: spacingSmall),
                Text(
                  "seconds",
                  style: GoogleFonts.poppins(
                    fontSize: smallFontSize,
                    color: Colors.white70,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTargetIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isExtraLarge ? 40 : (isTablet ? 32 : (isCompact ? 16 : (isSmallDevice ? 20 : 24))),
        vertical: isExtraLarge ? 20 : (isTablet ? 18 : (isCompact ? 10 : (isSmallDevice ? 12 : 14))),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8B2635).withOpacity(0.4),
            const Color(0xFF4A1625).withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 35 : 30),
        border: Border.all(
          color: const Color(0xFF8B2635).withOpacity(0.6),
          width: isTablet ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B2635).withOpacity(0.2),
            blurRadius: isTablet ? 18 : 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isExtraLarge ? 12 : (isTablet ? 10 : (isCompact ? 4 : (isSmallDevice ? 6 : 8)))),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag,
              color: const Color(0xFFE91E63),
              size: isExtraLarge ? 26 : (isTablet ? 22 : (isCompact ? 14 : (isSmallDevice ? 16 : 18))),
            ),
          ),
          SizedBox(width: spacingMedium),
          Text(
            "TARGET: 10.00s",
            style: GoogleFonts.poppins(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE91E63),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 500 : double.infinity,
      ),
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
                        const Color(0xFF4A1625).withOpacity(0.5),
            const Color(0xFF2D0F1A).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 30 : 24),
        border: Border.all(
          color: const Color(0xFF8B2635).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        _message,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: bodyFontSize,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPointsDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isExtraLarge ? 40 : (isTablet ? 30 : 20),
        vertical: isExtraLarge ? 20 : (isTablet ? 16 : 12),
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        "+$_pointsEarned Points!",
        style: GoogleFonts.poppins(
          fontSize: titleFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    // Always use the same layout pattern to avoid rendering issues
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      child: isLandscape && !isTablet && !isSmallDevice
        ? _buildVerticalButtons() // Vertical for landscape phones
        : _buildHorizontalButtons(), // Horizontal for everything else
    );
  }

  Widget _buildVerticalButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildControlButton(
          onPressed: !_gameStarted && !_gameEnded ? _start : null,
          icon: Icons.play_arrow,
          label: "START",
          color: const Color(0xFF4CAF50),
        ),
        SizedBox(height: spacingSmall),
        _buildControlButton(
          onPressed: _gameStarted && !_gameEnded ? _stop : null,
          icon: Icons.stop,
          label: "STOP",
          color: const Color(0xFFE91E63),
        ),
        SizedBox(height: spacingSmall),
        _buildControlButton(
          onPressed: _gameEnded ? _reset : null,
          icon: Icons.refresh,
          label: "RESET",
          color: const Color(0xFF8B2635),
        ),
      ],
    );
  }

  Widget _buildHorizontalButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildControlButton(
            onPressed: !_gameStarted && !_gameEnded ? _start : null,
            icon: Icons.play_arrow,
            label: "START",
            color: const Color(0xFF4CAF50),
          ),
        ),
        SizedBox(width: spacingSmall),
        Expanded(
          child: _buildControlButton(
            onPressed: _gameStarted && !_gameEnded ? _stop : null,
            icon: Icons.stop,
            label: "STOP",
            color: const Color(0xFFE91E63),
          ),
        ),
        SizedBox(width: spacingSmall),
        Expanded(
          child: _buildControlButton(
            onPressed: _gameEnded ? _reset : null,
            icon: Icons.refresh,
            label: "RESET",
            color: const Color(0xFF8B2635),
          ),
        ),
      ],
    );
  }

  // Animated button wrapper for press animation
  Widget _buildAnimatedButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, _) {
        return GestureDetector(
          onTapDown: (_) => _scaleAnimationController.forward(),
          onTapUp: (_) {
            _scaleAnimationController.reverse();
            onTap();
          },
          onTapCancel: () => _scaleAnimationController.reverse(),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isEnabled = onPressed != null;

    return _buildAnimatedButton(
      onTap: onPressed ?? () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          vertical: isExtraLarge ? 24 : (isTablet ? 20 : (isCompact ? 12 : (isSmallDevice ? 14 : 16))),
          horizontal: isExtraLarge ? 16 : (isTablet ? 12 : (isCompact ? 6 : (isSmallDevice ? 8 : 10))),
        ),
        decoration: BoxDecoration(
          gradient: isEnabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withOpacity(0.8)],
                )
              : LinearGradient(
                  colors: [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.2)],
                ),
          borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: isTablet ? 16 : 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
          border: Border.all(
            color: isEnabled ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isExtraLarge ? 12 : (isTablet ? 10 : (isCompact ? 4 : (isSmallDevice ? 6 : 8)))),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isEnabled ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.white.withOpacity(isEnabled ? 1.0 : 0.5),
                size: isExtraLarge ? 28 : (isTablet ? 24 : (isCompact ? 16 : (isSmallDevice ? 18 : 20))),
              ),
            ),
            SizedBox(height: spacingSmall),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: buttonFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(isEnabled ? 1.0 : 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


 
}
