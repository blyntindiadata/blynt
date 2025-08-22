import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/scheduler.dart';

class RubyPlaneGame extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const RubyPlaneGame({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<RubyPlaneGame> createState() => _RubyPlaneGameState();
}

class _RubyPlaneGameState extends State<RubyPlaneGame>
    with SingleTickerProviderStateMixin {
  
  // Responsive design helpers
  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;
  bool get isLandscape => MediaQuery.of(context).orientation == Orientation.landscape;
  bool get isSmallDevice => MediaQuery.of(context).size.height < 600;
  
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  double get safeAreaHeight => screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
  
  // Dynamic game constants based on screen size
  double get width => screenWidth;
  double get height => safeAreaHeight - (isTablet ? 120 : (isSmallDevice ? 80 : 100));
  
  double get buildingWidth => isTablet ? 100 : (isSmallDevice ? 60 : 80);
  double get buildingGap => isTablet ? 220 : (isSmallDevice ? 140 : 180);
  double get buildingSpeed => isTablet ? 2.2 : (isSmallDevice ? 1.4 : 1.8);
  double get baseBuildingSpeed => buildingSpeed;
  double get gravity => isTablet ? 0.6 : (isSmallDevice ? 0.4 : 0.5);
  double get flyStrength => isTablet ? -8.5 : (isSmallDevice ? -5.5 : -7);
  
  // Plane positioning
  double get planeX => isTablet ? 90 : (isSmallDevice ? 50 : 70);
  double get planeWidth => isTablet ? 60 : (isSmallDevice ? 35 : 45);
  double get planeHeight => isTablet ? 30 : (isSmallDevice ? 15 : 20);
  
  // Font sizes
  double get headerFontSize => isTablet ? 24 : (isSmallDevice ? 16 : 20);
  double get scoreFontSize => isTablet ? 22 : (isSmallDevice ? 16 : 18);
  double get gameTextFontSize => isTablet ? 32 : (isSmallDevice ? 20 : 24);
  double get instructionFontSize => isTablet ? 20 : (isSmallDevice ? 14 : 16);
  
  // Plane state
  double planeY = 300;
  double planeVelocity = 0;
  bool gameStarted = false;
  int score = 0;
  int attemptsToday = 0;
  bool canPlay = true;
  bool gameOver = false;
  int pointsEarned = 0;
  
  // Add flag to prevent double attempts counting
  bool attemptCounted = false;

  // Buildings: each = [x, gapCenterY, scoredFlag]
  List<List<dynamic>> buildings = [];

  late Ticker ticker;
  Random rand = Random();
  double lastGapY = 300;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(_update)..start();
    _loadTodayAttempts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reset plane position when screen size changes
    planeY = height / 2;
    lastGapY = height / 2;
  }

  Future<void> _loadTodayAttempts() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_attempts')
          .doc('${widget.username}_plane_$todayString')
          .get();

      if (doc.exists) {
        setState(() {
          attemptsToday = doc.data()?['attempts'] ?? 0;
          canPlay = attemptsToday < 200;
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
          .doc('${widget.username}_plane_$todayString')
          .set({
        'username': widget.username,
        'game': 'plane',
        'attempts': attemptsToday + 1,
        'date': todayString,
        'lastAttempt': FieldValue.serverTimestamp(),
      });

      setState(() {
        attemptsToday++;
        canPlay = attemptsToday < 200;
      });
    } catch (e) {
      print('Error updating attempts: $e');
    }
  }

  Future<void> _updateScore(int points) async {
    print('🎮 Attempting to update score: $points points for user: ${widget.username}');
    print('📍 Community ID: ${widget.communityId}');
    
    try {
      final scoreRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_scores')
          .doc(widget.username);

      print('📍 Document path: communities/${widget.communityId}/game_scores/${widget.username}');

      // Add timeout and retry logic
      await FirebaseFirestore.instance.runTransaction(
        (transaction) async {
          final scoreDoc = await transaction.get(scoreRef);
          
          print('📄 Document exists: ${scoreDoc.exists}');
          
          if (scoreDoc.exists) {
            final currentData = scoreDoc.data() as Map<String, dynamic>;
            
            // Ensure all game point fields exist with default values
            final currentTimerPoints = currentData['timerPoints'] ?? 0;
            final currentPuzzlePoints = currentData['puzzlePoints'] ?? 0;
            final current2048Points = currentData['2048Points'] ?? 0;
            final currentPlanePoints = currentData['planePoints'] ?? 0;
            
            // Calculate new plane points and total
            final newPlanePoints = currentPlanePoints + pointsEarned;
            final newTotalPoints = currentTimerPoints + currentPuzzlePoints + current2048Points + newPlanePoints;
            
            print('📊 Current plane points: $currentPlanePoints');
            print('📊 Current total points: ${currentData['totalPoints'] ?? 0}');
            print('➕ Adding: $pointsEarned points');
            print('📊 New plane points: $newPlanePoints');
            print('📊 New total points: $newTotalPoints');
            
            transaction.update(scoreRef, {
              'username': widget.username,
              'timerPoints': currentTimerPoints,
              'puzzlePoints': currentPuzzlePoints,
              '2048Points': current2048Points,
              'planePoints': newPlanePoints,
              'totalPoints': newTotalPoints,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            
            print('✅ Updated existing document');
          } else {
            // Create new document with all required fields
            transaction.set(scoreRef, {
              'username': widget.username,
              'timerPoints': 0,
              'puzzlePoints': 0,
              '2048Points': 0,
              'planePoints': points,
              'totalPoints': points,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
            
            print('✅ Created new document with score: $points');
          }
        },
        timeout: const Duration(seconds: 10), // Add timeout
      );
      
      print('🎉 Score update completed successfully!');
    } catch (e) {
      print('❌ Error updating score: $e');
      print('📋 Stack trace: ${StackTrace.current}');
      
      // ADDED: Retry logic for failed updates
      print('🔄 Retrying score update...');
      await Future.delayed(const Duration(milliseconds: 500));
      await _retryUpdateScore(points);
    }
  }

  Future<void> _retryUpdateScore(int points) async {
    try {
      final scoreRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_scores')
          .doc(widget.username);

      // Simpler approach for retry - just set/merge the data
      await scoreRef.set({
        'username': widget.username,
        'planePoints': FieldValue.increment(points),
        'totalPoints': FieldValue.increment(points),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('✅ Retry successful!');
    } catch (e) {
      print('❌ Retry also failed: $e');
      // Could show user a message that score saving failed
    }
  }

  void _update(Duration elapsed) {
    if (gameStarted && !gameOver && !attemptCounted) {
      // Gradually increase speed based on score with responsive scaling
      double currentBuildingSpeed = baseBuildingSpeed + (score / 150.0) * (isTablet ? 0.3 : 0.2);
      
      // Gravity
      planeVelocity += gravity;
      planeY += planeVelocity;

      // Move buildings
      for (var building in buildings) {
        building[0] -= currentBuildingSpeed;
        // Score - responsive points per building passed
        int pointsPerBuilding = isTablet ? 20 : 15;
        if (building[0] + buildingWidth < planeX && !building[2]) {
          score += pointsPerBuilding;
          building[2] = true;
        }
      }

      // Remove old buildings
      buildings.removeWhere((b) => b[0] + buildingWidth < 0);

      // Spawn new buildings with responsive spacing
      double spawnDistance = isTablet ? 280 : (isSmallDevice ? 180 : 220);
      if (buildings.isEmpty || buildings.last[0] < width - spawnDistance) {
        double maxChange = isTablet ? 110 : (isSmallDevice ? 70 : 90);
        double targetGapY = lastGapY + (rand.nextDouble() * 2 - 1) * maxChange;
        targetGapY = targetGapY.clamp(buildingGap / 2 + 50, height - buildingGap / 2 - 50);
        buildings.add([width, targetGapY, false]);
        lastGapY = targetGapY;
      }

      // Collision - check ONCE and immediately set flag
      if (_checkCollision()) {
        attemptCounted = true; // Set flag IMMEDIATELY
        _gameOver();
        return;
      }
    }

    setState(() {});
  }

  bool _checkCollision() {
    // Plane boundaries with responsive safe margins
    double planeMargin = isTablet ? 35 : (isSmallDevice ? 20 : 25);
    if (planeY - planeMargin < 0 || planeY + planeMargin > height) return true;

    for (var building in buildings) {
      double bx = building[0];
      double gapY = building[1];

      // Top building rect
      Rect topRect = Rect.fromLTWH(bx, 0, buildingWidth, gapY - buildingGap / 2);
      // Bottom building rect
      Rect bottomRect = Rect.fromLTWH(
          bx, gapY + buildingGap / 2, buildingWidth, height - (gapY + buildingGap / 2));

      // Responsive plane rect
      Rect planeRect = Rect.fromCenter(
        center: Offset(planeX, planeY), 
        width: planeWidth, 
        height: planeHeight
      );

      if (topRect.overlaps(planeRect) || bottomRect.overlaps(planeRect)) {
        return true;
      }
    }
    return false;
  }

  void _fly() {
    if (!canPlay || gameOver) return; // Add gameOver check here
    
    if (!gameStarted) {
      gameStarted = true;
      gameOver = false;
      score = 0;
      buildings.clear();
      planeY = height / 2;
      planeVelocity = 0;
      lastGapY = height / 2;
      attemptCounted = false;
    }
    planeVelocity = flyStrength;
  }

  void _gameOver() async {
    // Additional safety check
    if (gameOver) return;
    
    setState(() {
      gameStarted = false;
      gameOver = true;
      planeVelocity = 0;
      pointsEarned = score;
    });
    
    // Update attempts and score
    await _updateAttempts();
    await _updateScore(score);
    
    _showGameOverDialog();
  }

  void _resetGame() {
    setState(() {
      gameStarted = false;
      gameOver = false;
      score = 0;
      pointsEarned = 0;
      planeY = height / 2;
      planeVelocity = 0;
      buildings.clear();
      lastGapY = height / 2;
      attemptCounted = false; // This is crucial!
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D0F1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16)
          ),
          title: Text(
            'Plane Crashed!',
            style: GoogleFonts.poppins(
              color: const Color(0xFFE91E63),
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 24 : (isSmallDevice ? 18 : 20),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You hit a building!',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: isTablet ? 16 : (isSmallDevice ? 12 : 14),
                ),
              ),
              SizedBox(height: isTablet ? 16 : 12),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                  ),
                  borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Score: $pointsEarned',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 20 : (isSmallDevice ? 14 : 16),
                      ),
                    ),
                    if (pointsEarned > 0) ...[
                      SizedBox(height: isTablet ? 6 : 4),
                      Text(
                        '+$pointsEarned points earned!',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: isTablet ? 14 : (isSmallDevice ? 10 : 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (canPlay) ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetGame();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: isTablet ? 12 : 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                  ),
                ),
                child: Text(
                  'Try Again',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B2635),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: isTablet ? 12 : 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                  ),
                ),
                child: Text(
                  'Done',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
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
                    child: _buildGameArea(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24 : 20,
        isTablet ? 24 : 20,
        isTablet ? 24 : 20,
        isTablet ? 20 : 16,
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
        Icons.airplanemode_active, 
        color: Colors.white, 
        size: isTablet ? 28 : 24,
      ),
    ),
          SizedBox(width: isTablet ? 20 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                  ).createShader(bounds),
                  child: Text(
                    'ruby plane',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: headerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                Text(
                  'attempts: $attemptsToday/200',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 14 : (isSmallDevice ? 10 : 12),
                    color: canPlay ? const Color(0xFFE91E63) : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16, 
              vertical: isTablet ? 12 : 8,
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
                  Icons.star,
                  color: Colors.white,
                  size: isTablet ? 20 : 16,
                ),
                SizedBox(width: isTablet ? 8 : 6),
                Text(
                  score.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: scoreFontSize,
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

  Widget _buildGameArea() {
    if (!canPlay) {
      return _buildLimitReachedView();
    }

    return GestureDetector(
      onTap: gameOver ? null : _fly, // Disable tapping when game is over
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: CustomPaint(
          painter: RubyPlanePainter(
            planeY: planeY,
            planeX: planeX,
            planeWidth: planeWidth,
            planeHeight: planeHeight,
            buildings: buildings,
            buildingWidth: buildingWidth,
            buildingGap: buildingGap,
            gameStarted: gameStarted,
            gameOver: gameOver,
            isTablet: isTablet,
            isSmallDevice: isSmallDevice,
            gameTextFontSize: gameTextFontSize,
            instructionFontSize: instructionFontSize,
          ),
          child: Container(),
        ),
      ),
    );
  }

  Widget _buildLimitReachedView() {
    return Container(
      padding: EdgeInsets.all(isTablet ? 32 : 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.access_time,
            color: Colors.red,
            size: isTablet ? 80 : (isSmallDevice ? 48 : 64),
          ),
          SizedBox(height: isTablet ? 32 : 24),
          Text(
            'Daily Limit Reached',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 32 : (isSmallDevice ? 20 : 24),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isTablet ? 24 : 16),
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
            ),
            child: Column(
              children: [
                Text(
                  'You have used all 200 attempts for today.',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 18 : (isSmallDevice ? 14 : 16),
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isTablet ? 16 : 12),
                Text(
                  'Come back tomorrow for more attempts!',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : (isSmallDevice ? 12 : 14),
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          SizedBox(height: isTablet ? 32 : 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B2635),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 40 : 32, 
                vertical: isTablet ? 20 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
              ),
            ),
            child: Text(
              'Back to Games',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }
}

class RubyPlanePainter extends CustomPainter {
  final double planeY;
  final double planeX;
  final double planeWidth;
  final double planeHeight;
  final List<List<dynamic>> buildings;
  final double buildingWidth;
  final double buildingGap;
  final bool gameStarted;
  final bool gameOver;
  final bool isTablet;
  final bool isSmallDevice;
  final double gameTextFontSize;
  final double instructionFontSize;

  RubyPlanePainter({
    required this.planeY,
    required this.planeX,
    required this.planeWidth,
    required this.planeHeight,
    required this.buildings,
    required this.buildingWidth,
    required this.buildingGap,
    required this.gameStarted,
    required this.gameOver,
    required this.isTablet,
    required this.isSmallDevice,
    required this.gameTextFontSize,
    required this.instructionFontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // Sky gradient background
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4A1625),
          const Color(0xFF2D0F1A),
          const Color(0xFF1A0B11),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Draw clouds with responsive sizing
    _drawClouds(canvas, size);

    // Buildings
    for (var building in buildings) {
      double bx = building[0];
      double gapY = building[1];
      
      // Building gradient
      final buildingGradient = LinearGradient(
        colors: [
          const Color(0xFF374151),
          const Color(0xFF1F2937),
          const Color(0xFF111827),
        ],
      );
      
      // Responsive corner radius
      double cornerRadius = isTablet ? 6 : 4;
      
      // Top building
      paint.shader = buildingGradient.createShader(
        Rect.fromLTWH(bx, 0, buildingWidth, gapY - buildingGap / 2)
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, 0, buildingWidth, gapY - buildingGap / 2),
          Radius.circular(cornerRadius),
        ),
        paint,
      );
      
      // Bottom building
      paint.shader = buildingGradient.createShader(
        Rect.fromLTWH(bx, gapY + buildingGap / 2, buildingWidth, size.height - (gapY + buildingGap / 2))
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, gapY + buildingGap / 2, buildingWidth, size.height - (gapY + buildingGap / 2)),
          Radius.circular(cornerRadius),
        ),
        paint,
      );

      // Building windows with responsive sizing
      _drawBuildingWindows(canvas, bx, gapY, size.height);
    }

    // Plane
    _drawPlane(canvas, size);

    // Game state text
    if (!gameStarted && !gameOver) {
      _drawCenteredText(
        canvas, 
        size, 
        'TAP TO FLY',
        GoogleFonts.poppins(
          fontSize: gameTextFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        0,
      );
      _drawCenteredText(
        canvas, 
        size, 
        'Tap to fly and avoid the buildings!',
        GoogleFonts.poppins(
          fontSize: instructionFontSize,
          color: Colors.white70,
        ),
        gameTextFontSize + (isTablet ? 20 : 16),
      );
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    final cloudPaint = Paint()
      ..color = const Color(0xFF8B2635).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    // Responsive cloud sizing
    double cloudSize = isTablet ? 24 : (isSmallDevice ? 12 : 18);
    double cloudSpacing = isTablet ? 20 : (isSmallDevice ? 12 : 15);

    // Draw a few simple clouds
    for (int i = 0; i < 3; i++) {
      double x = (size.width / 4) * (i + 1);
      double y = size.height * 0.2 + (i * (isTablet ? 40 : 30));
      
      // Cloud made of circles with responsive sizing
      canvas.drawCircle(Offset(x - cloudSpacing, y), cloudSize * 0.67, cloudPaint);
      canvas.drawCircle(Offset(x, y), cloudSize, cloudPaint);
      canvas.drawCircle(Offset(x + cloudSpacing, y), cloudSize * 0.67, cloudPaint);
      canvas.drawCircle(Offset(x + cloudSpacing * 0.3, y - cloudSize * 0.6), cloudSize * 0.78, cloudPaint);
    }
  }

  void _drawBuildingWindows(Canvas canvas, double bx, double gapY, double screenHeight) {
    final windowPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..style = PaintingStyle.fill;

    // Responsive window sizing
    double windowWidth = isTablet ? 12 : (isSmallDevice ? 6 : 8);
    double windowHeight = isTablet ? 16 : (isSmallDevice ? 10 : 12);
    double windowSpacing = isTablet ? 30 : (isSmallDevice ? 20 : 25);
    double windowMargin = isTablet ? 20 : (isSmallDevice ? 12 : 15);

    // Top building windows
    double topBuildingHeight = gapY - buildingGap / 2;
    if (topBuildingHeight > windowSpacing * 2) {
      int windowRows = (topBuildingHeight / windowSpacing).floor();
      for (int row = 1; row <= windowRows; row++) {
        double windowY = row * windowSpacing;
        if (windowY + windowHeight < topBuildingHeight - 10) {
          // Left window
          canvas.drawRect(
            Rect.fromLTWH(bx + windowMargin, windowY, windowWidth, windowHeight),
            windowPaint,
          );
          // Right window (if building is wide enough)
          if (buildingWidth > windowMargin * 2 + windowWidth * 2) {
            canvas.drawRect(
              Rect.fromLTWH(bx + buildingWidth - windowMargin - windowWidth, windowY, windowWidth, windowHeight),
              windowPaint,
            );
          }
        }
      }
    }

    // Bottom building windows
    double bottomBuildingHeight = screenHeight - (gapY + buildingGap / 2);
    if (bottomBuildingHeight > windowSpacing * 2) {
      int windowRows = (bottomBuildingHeight / windowSpacing).floor();
      for (int row = 1; row <= windowRows; row++) {
        double windowY = gapY + buildingGap / 2 + (row * windowSpacing);
        if (windowY + windowHeight < screenHeight - 10) {
          // Left window
          canvas.drawRect(
            Rect.fromLTWH(bx + windowMargin, windowY, windowWidth, windowHeight),
            windowPaint,
          );
          // Right window (if building is wide enough)
          if (buildingWidth > windowMargin * 2 + windowWidth * 2) {
            canvas.drawRect(
              Rect.fromLTWH(bx + buildingWidth - windowMargin - windowWidth, windowY, windowWidth, windowHeight),
              windowPaint,
            );
          }
        }
      }
    }
  }

  void _drawPlane(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Responsive plane scaling
    double planeScale = isTablet ? 1.4 : (isSmallDevice ? 0.8 : 1.0);
    
    // Plane body
    paint.color = const Color(0xFFE91E63);
    Path planeBody = Path();
    planeBody.moveTo(planeX - (planeWidth * 0.3) * planeScale, planeY);
    planeBody.lineTo(planeX + (planeWidth * 0.4) * planeScale, planeY - (5 * planeScale));
    planeBody.lineTo(planeX + (planeWidth * 0.4) * planeScale, planeY + (5 * planeScale));
    planeBody.close();
    canvas.drawPath(planeBody, paint);

    // Main wing
    paint.color = const Color(0xFF8B2635);
    Path mainWing = Path();
    mainWing.moveTo(planeX - (8 * planeScale), planeY - (3 * planeScale));
    mainWing.lineTo(planeX + (8 * planeScale), planeY - (15 * planeScale));
    mainWing.lineTo(planeX + (15 * planeScale), planeY - (10 * planeScale));
    mainWing.lineTo(planeX, planeY + (3 * planeScale));
    mainWing.close();
    canvas.drawPath(mainWing, paint);

    // Tail wing
    Path tailWing = Path();
    tailWing.moveTo(planeX - (20 * planeScale), planeY - (2 * planeScale));
    tailWing.lineTo(planeX - (23 * planeScale), planeY - (10 * planeScale));
    tailWing.lineTo(planeX - (15 * planeScale), planeY - (8 * planeScale));
    tailWing.lineTo(planeX - (12 * planeScale), planeY + (2 * planeScale));
    tailWing.close();
    canvas.drawPath(tailWing, paint);

    // Cockpit
    paint.color = const Color(0xFF4A1625);
    canvas.drawCircle(
      Offset(planeX + (8 * planeScale), planeY - (1 * planeScale)), 
      4 * planeScale, 
      paint
    );

    // Engine trail (when moving) with responsive sizing
    if (gameStarted && !gameOver) {
      paint.color = const Color(0xFFE91E63).withOpacity(0.6);
      Path trail = Path();
      trail.moveTo(planeX - (planeWidth * 0.3) * planeScale, planeY);
      trail.lineTo(planeX - (planeWidth * 0.5) * planeScale, planeY - (3 * planeScale));
      trail.lineTo(planeX - (planeWidth * 0.4) * planeScale, planeY);
      trail.lineTo(planeX - (planeWidth * 0.5) * planeScale, planeY + (3 * planeScale));
      trail.close();
      canvas.drawPath(trail, paint);
    }
  }

  void _drawCenteredText(Canvas canvas, Size size, String text, TextStyle style, double yOffset) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: size.width - (isTablet ? 80 : 40));
    
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2 + yOffset,
    );
    
    // Text shadow with responsive blur
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: text, 
        style: style.copyWith(
          color: Colors.black.withOpacity(0.7),
          shadows: [
            Shadow(
              blurRadius: isTablet ? 8 : 6,
              offset: Offset(isTablet ? 3 : 2, isTablet ? 3 : 2),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    shadowPainter.layout(maxWidth: size.width - (isTablet ? 80 : 40));
    shadowPainter.paint(canvas, offset);
    
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}