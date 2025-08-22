import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class _PerfectTimerGameState extends State<PerfectTimerGame> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  double _elapsedSeconds = 0.0;
  String _message = "Hit exactly 10.00 seconds!";
  bool _gameStarted = false;
  bool _gameEnded = false;
  int _attemptsToday = 0;
  int _pointsEarned = 0;
  bool _canPlay = true;

  // Responsive design helpers
  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;
  bool get isLandscape => MediaQuery.of(context).orientation == Orientation.landscape;
  bool get isSmallDevice => MediaQuery.of(context).size.height < 600;
  bool get isCompact => MediaQuery.of(context).size.width < 400;
  bool get isExtraLarge => MediaQuery.of(context).size.shortestSide >= 900;
  
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  double get safeAreaHeight => screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
  
  // Dynamic sizing based on screen size and device type
  double get headerFontSize => isExtraLarge ? 32 : (isTablet ? 28 : (isSmallDevice ? 18 : 20));
  double get subHeaderFontSize => isExtraLarge ? 16 : (isTablet ? 14 : (isSmallDevice ? 10 : 12));
  double get timerFontSize => isExtraLarge ? 72 : (isTablet ? 64 : (isSmallDevice ? 36 : 54));
  double get titleFontSize => isExtraLarge ? 24 : (isTablet ? 20 : (isSmallDevice ? 14 : 18));
  double get bodyFontSize => isExtraLarge ? 20 : (isTablet ? 18 : (isSmallDevice ? 14 : 16));
  double get smallFontSize => isExtraLarge ? 16 : (isTablet ? 14 : (isSmallDevice ? 10 : 12));
  double get buttonFontSize => isExtraLarge ? 18 : (isTablet ? 16 : (isSmallDevice ? 12 : 14));
  
  EdgeInsets get screenPadding => EdgeInsets.all(isExtraLarge ? 32 : (isTablet ? 24 : (isSmallDevice ? 12 : 16)));
  EdgeInsets get containerPadding => EdgeInsets.all(isExtraLarge ? 32 : (isTablet ? 28 : (isSmallDevice ? 18 : 24)));
  EdgeInsets get compactPadding => EdgeInsets.all(isExtraLarge ? 24 : (isTablet ? 20 : (isSmallDevice ? 12 : 16)));
  
  double get spacingSmall => isExtraLarge ? 16 : (isTablet ? 12 : (isSmallDevice ? 6 : 8));
  double get spacingMedium => isExtraLarge ? 28 : (isTablet ? 20 : (isSmallDevice ? 12 : 16));
  double get spacingLarge => isExtraLarge ? 40 : (isTablet ? 32 : (isSmallDevice ? 16 : 24));
  double get spacingXLarge => isExtraLarge ? 64 : (isTablet ? 48 : (isSmallDevice ? 24 : 32));

  @override
  void initState() {
    super.initState();
    _loadTodayAttempts();
  }

  Future<void> _loadTodayAttempts() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_attempts')
          .doc('${widget.username}_timer_$todayString')
          .get();

      if (doc.exists) {
        setState(() {
          _attemptsToday = doc.data()?['attempts'] ?? 0;
          _canPlay = _attemptsToday < 5;
        });
      } else {
        setState(() {
          _attemptsToday = 0;
          _canPlay = true;
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
          .doc('${widget.username}_timer_$todayString')
          .set({
        'username': widget.username,
        'game': 'timer',
        'attempts': _attemptsToday + 1,
        'date': todayString,
        'lastAttempt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _attemptsToday++;
        _canPlay = _attemptsToday < 5;
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
    if (!_canPlay) return;
    
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
    if (diff < 0.001) { // Less than 1 millisecond difference
      result = "🎯 PERFECT! Exactly 10.00 seconds!";
      points = 1000;
    } else if (diff <= 0.01) { // Within 10 milliseconds
      result = "🔥 Incredible! Within 0.01 seconds!";
      points = 800;
    } else if (diff <= 0.05) { // Within 50 milliseconds
      result = "⚡ Fantastic! Within 0.05 seconds!";
      points = 600;
    } else if (diff <= 0.1) {
      result = "⭐ Amazing! Within 0.1 seconds!";
      points = 400;
    } else if (diff <= 0.2) {
      result = "👍 Great! Within 0.2 seconds!";
      points = 200;
    } else if (diff <= 0.5) {
      result = "✅ Good! Within 0.5 seconds!";
      points = 100;
    } else {
      result = "😅 Try again! Too far off.";
      points = 0;
    }

    setState(() {
      _message = result;
      _pointsEarned = points;
    });

    await _updateAttempts();
    if (points > 0) {
      await _updateScore(points);
    }
  }

  void _reset() {
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
          minHeight: constraints.maxHeight - (isTablet ? 120 : 100), // Account for header
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
              if (!_canPlay) _buildDailyLimitWarning(),
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
        
        // Daily limit warning
        if (!_canPlay) _buildDailyLimitWarning(),
        
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
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                  ).createShader(bounds),
                  child: Text(
                    'perfect timer',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                Text(
                  'attempts: $_attemptsToday/5',
                  style: GoogleFonts.poppins(
                    fontSize: subHeaderFontSize,
                    color: _canPlay ? const Color(0xFFE91E63) : Colors.red,
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
    double circleSize = isExtraLarge ? 280 : (isTablet ? 240 : (isSmallDevice ? 160 : 200));
    
    return Container(
      width: circleSize,
      height: circleSize,
      padding: EdgeInsets.all(isExtraLarge ? 60 : (isTablet ? 50 : (isSmallDevice ? 30 : 40))),
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
              "${_elapsedSeconds.toStringAsFixed(2)}",
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
    );
  }

  Widget _buildTargetIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isExtraLarge ? 40 : (isTablet ? 32 : (isSmallDevice ? 20 : 24)),
        vertical: isExtraLarge ? 20 : (isTablet ? 18 : (isSmallDevice ? 12 : 14)),
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
            padding: EdgeInsets.all(isExtraLarge ? 12 : (isTablet ? 10 : (isSmallDevice ? 6 : 8))),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flag,
              color: const Color(0xFFE91E63),
              size: isExtraLarge ? 26 : (isTablet ? 22 : (isSmallDevice ? 16 : 18)),
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
            const Color(0xFF4A1625).withOpacity(0.3),
            const Color(0xFF2D0F1A).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        border: Border.all(
          color: const Color(0xFF4A1625).withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: isTablet ? 18 : 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        _message,
        style: GoogleFonts.poppins(
          fontSize: bodyFontSize,
          color: Colors.white,
          height: 1.5,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPointsDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isExtraLarge ? 32 : (isTablet ? 28 : (isSmallDevice ? 20 : 24)),
        vertical: isExtraLarge ? 20 : (isTablet ? 18 : (isSmallDevice ? 12 : 14)),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 22 : 18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.5),
            blurRadius: isTablet ? 24 : 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isExtraLarge ? 12 : (isTablet ? 10 : (isSmallDevice ? 6 : 8))),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.star,
              color: Colors.white,
              size: isExtraLarge ? 28 : (isTablet ? 24 : (isSmallDevice ? 18 : 20)),
            ),
          ),
          SizedBox(width: spacingMedium),
          Text(
            "+$_pointsEarned points",
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

  Widget _buildControlButtons() {
    if (isLandscape && !isTablet && !isSmallDevice) {
      // Vertical layout for landscape on phones
      return Column(
        children: [
          _buildControlButton(
            onPressed: _canPlay && !_gameStarted && !_gameEnded ? _start : null,
            icon: Icons.play_arrow,
            label: "START",
            color: const Color(0xFF4CAF50),
            isFullWidth: true,
          ),
          SizedBox(height: spacingSmall),
          _buildControlButton(
            onPressed: _gameStarted && !_gameEnded ? _stop : null,
            icon: Icons.stop,
            label: "STOP",
            color: const Color(0xFFE91E63),
            isFullWidth: true,
          ),
          SizedBox(height: spacingSmall),
          _buildControlButton(
            onPressed: _gameEnded ? _reset : null,
            icon: Icons.refresh,
            label: "RESET",
            color: const Color(0xFF8B2635),
            isFullWidth: true,
          ),
        ],
      );
    } else {
      // Horizontal layout for portrait and tablets
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            onPressed: _canPlay && !_gameStarted && !_gameEnded ? _start : null,
            icon: Icons.play_arrow,
            label: "START",
            color: const Color(0xFF4CAF50),
          ),
          _buildControlButton(
            onPressed: _gameStarted && !_gameEnded ? _stop : null,
            icon: Icons.stop,
            label: "STOP",
            color: const Color(0xFFE91E63),
          ),
          _buildControlButton(
            onPressed: _gameEnded ? _reset : null,
            icon: Icons.refresh,
            label: "RESET",
            color: const Color(0xFF8B2635),
          ),
        ],
      );
    }
  }

  Widget _buildControlButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isFullWidth = false,
  }) {
    final isEnabled = onPressed != null;
    
    double buttonWidth = isFullWidth 
      ? double.infinity 
      : (isExtraLarge ? 120 : (isTablet ? 105 : (isSmallDevice ? 75 : 85)));
    
    Widget button = Container(
      width: isFullWidth ? null : buttonWidth,
      constraints: isFullWidth ? BoxConstraints(maxWidth: 300) : null,
      padding: EdgeInsets.symmetric(
        vertical: isExtraLarge ? 26 : (isTablet ? 22 : (isSmallDevice ? 16 : 18)),
        horizontal: isFullWidth ? spacingLarge : 0,
      ),
      decoration: BoxDecoration(
        gradient: isEnabled ? LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color, color.withOpacity(0.8)],
        ) : LinearGradient(
          colors: [Colors.grey.withOpacity(0.5), Colors.grey.withOpacity(0.3)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 22 : 18),
        boxShadow: isEnabled ? [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: isTablet ? 18 : 15,
            offset: const Offset(0, 6),
          ),
        ] : [],
        border: Border.all(
          color: isEnabled 
            ? color.withOpacity(0.3) 
            : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isExtraLarge ? 14 : (isTablet ? 12 : (isSmallDevice ? 8 : 10))),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(isEnabled ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isExtraLarge ? 32 : (isTablet ? 28 : (isSmallDevice ? 20 : 24)),
            ),
          ),
          SizedBox(height: isExtraLarge ? 14 : (isTablet ? 12 : (isSmallDevice ? 8 : 10))),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: buttonFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: onPressed,
      child: isFullWidth ? button : Expanded(child: button),
    );
  }

  Widget _buildDailyLimitWarning() {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 400 : double.infinity,
      ),
      padding: EdgeInsets.all(isExtraLarge ? 24 : (isTablet ? 22 : (isSmallDevice ? 16 : 18))),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.3), Colors.red.withOpacity(0.2)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 22 : 18),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: isTablet ? 18 : 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isExtraLarge ? 12 : (isTablet ? 10 : (isSmallDevice ? 6 : 8))),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time,
              color: Colors.red,
              size: isExtraLarge ? 26 : (isTablet ? 22 : (isSmallDevice ? 16 : 20)),
            ),
          ),
          SizedBox(width: spacingMedium),
          Expanded(
            child: Text(
              "Daily limit reached (5/5). Try again tomorrow!",
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