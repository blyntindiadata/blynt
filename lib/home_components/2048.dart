import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

class Ruby2048Game extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const Ruby2048Game({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<Ruby2048Game> createState() => _Ruby2048GameState();
}

class _Ruby2048GameState extends State<Ruby2048Game> 
    with TickerProviderStateMixin {
  List<List<int>> board = List.generate(4, (_) => List.filled(4, 0));
  List<List<int>> previousBoard = List.generate(4, (_) => List.filled(4, 0));
  int score = 0;
  int previousScore = 0;
  int bestScore = 0;
  bool gameOver = false;
  bool hasWon = false;
  DateTime? sessionStartTime;
  Timer? _sessionTimer;

  // Ad-related variables
RewardedAd? _rewardedAd;
bool _isAdLoaded = false;
bool _showingAd = false;
int _gameplaySeconds = 0;
int _lastAdAt = 0;
static const String _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917'; // Test ID

  
  // Animation controllers for smooth interactions
  late AnimationController _tileAnimationController;
  late AnimationController _scoreAnimationController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _bounceController;
  late AnimationController _glowController;
  
  late Animation<double> _tileAnimation;
  late Animation<double> _scoreAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;

  // For tracking swipe gestures
  Offset _totalPanDelta = Offset.zero;
  Direction? _lastSwipeDirection;
  
  final Random _random = Random();
  
  // Enhanced Ruby-themed colors with smooth gradients
  final Map<int, List<Color>> tileGradients = {
    0: [const Color(0xFF2D0F1A), const Color(0xFF1A0B11)],
    2: [const Color(0xFF4A1625), const Color(0xFF2D0F1A)],
    4: [const Color(0xFF6B1E2F), const Color(0xFF4A1625)],
    8: [const Color(0xFF8B2635), const Color(0xFF6B1E2F)],
    16: [const Color(0xFFA52A3A), const Color(0xFF8B2635)],
    32: [const Color(0xFFBF2E3F), const Color(0xFFA52A3A)],
    64: [const Color(0xFFD93244), const Color(0xFFBF2E3F)],
    128: [const Color(0xFFE91E63), const Color(0xFFD93244)],
    256: [const Color(0xFFEC407A), const Color(0xFFE91E63)],
    512: [const Color(0xFFEF5350), const Color(0xFFEC407A)],
    1024: [const Color(0xFFF44336), const Color(0xFFEF5350)],
    2048: [const Color(0xFFFF5722), const Color(0xFFF44336)],
  };
  
  final Map<int, Color> textColors = {
    2: Colors.white70,
    4: Colors.white70,
    8: Colors.white,
    16: Colors.white,
    32: Colors.white,
    64: Colors.white,
    128: Colors.white,
    256: Colors.white,
    512: Colors.white,
    1024: Colors.white,
    2048: Colors.white,
  };

  // Enhanced responsive design helpers
  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;
  bool get isLandscape => MediaQuery.of(context).orientation == Orientation.landscape;
  bool get isSmallDevice => MediaQuery.of(context).size.height < 600;
  bool get isCompact => MediaQuery.of(context).size.width < 400;
  bool get isExtraLarge => MediaQuery.of(context).size.shortestSide >= 900;
  
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  double get availableHeight => screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
  
  // Improved dynamic sizing
  double get boardSize {
    if (isExtraLarge) return min(450, screenWidth - 64);
    if (isTablet) return min(400, screenWidth - 48);
    if (isCompact) return min(280, screenWidth - 20);
    if (isSmallDevice) return min(300, screenWidth - 24);
    return min(320, screenWidth - 32);
  }
  
  double get tileSize => (boardSize - 40) / 4 - 8;
  
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
  
  double get scoreFontSize {
    if (isExtraLarge) return 32;
    if (isTablet) return 28;
    if (isCompact) return 18;
    if (isSmallDevice) return 20;
    return 24;
  }
  
  double get bodyFontSize {
    if (isExtraLarge) return 18;
    if (isTablet) return 16;
    if (isCompact) return 11;
    if (isSmallDevice) return 12;
    return 14;
  }
  
  double get buttonFontSize {
    if (isExtraLarge) return 18;
    if (isTablet) return 16;
    if (isCompact) return 12;
    if (isSmallDevice) return 14;
    return 16;
  }
  
  EdgeInsets get screenPadding {
    if (isExtraLarge) return const EdgeInsets.all(32);
    if (isTablet) return const EdgeInsets.all(24);
    if (isCompact) return const EdgeInsets.all(8);
    if (isSmallDevice) return const EdgeInsets.all(12);
    return const EdgeInsets.all(16);
  }
  
  EdgeInsets get containerPadding {
    if (isExtraLarge) return const EdgeInsets.all(28);
    if (isTablet) return const EdgeInsets.all(20);
    if (isCompact) return const EdgeInsets.all(12);
    if (isSmallDevice) return const EdgeInsets.all(16);
    return const EdgeInsets.all(18);
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

@override
void initState() {
  super.initState();
  _initAnimations();
  _loadBestScore();
  _loadRewardedAd();
  _initGame();
}

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
        print('Rewarded ad failed to load: $error');
        _isAdLoaded = false;
        Timer(const Duration(seconds: 5), () {
          _loadRewardedAd();
        });
      },
    ),
  );
}

void _showRewardedAd() {
  if (_isAdLoaded && _rewardedAd != null && !_showingAd) {
    _showingAd = true;
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        _showingAd = false;
        _isAdLoaded = false;
        _lastAdAt = _gameplaySeconds;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        _showingAd = false;
        _isAdLoaded = false;
        _lastAdAt = _gameplaySeconds;
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

  void _initAnimations() {
    _tileAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scoreAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _tileAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _tileAnimationController, curve: Curves.elasticOut),
    );
    _scoreAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _scoreAnimationController, curve: Curves.elasticOut),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -0.05)).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.bounceOut),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

 @override
void dispose() {
  _sessionTimer?.cancel();
  _rewardedAd?.dispose();
  _tileAnimationController.dispose();
  _scoreAnimationController.dispose();
  _pulseController.dispose();
  _slideController.dispose();
  _scaleController.dispose();
  _bounceController.dispose();
  _glowController.dispose();
  super.dispose();
}



  Future<void> _loadBestScore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_scores')
          .doc(widget.username)
          .get();

      if (doc.exists) {
        setState(() {
          bestScore = doc.data()?['best2048Score'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading best score: $e');
    }
  }

  Future<void> _saveBestScore() async {
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
          final currentBestScore = currentData['best2048Score'] ?? 0;
          
          if (score > currentBestScore) {
            transaction.update(scoreRef, {
              'best2048Score': score,
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }
        } else {
          transaction.set(scoreRef, {
            'username': widget.username,
            'timerPoints': 0,
            'puzzlePoints': 0,
            '2048Points': 0,
            'birdPoints': 0,
            'best2048Score': score,
            'totalPoints': 0,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      print('Error saving best score: $e');
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
          final current2048Points = currentData['2048Points'] ?? 0;
          final currentTotalPoints = currentData['totalPoints'] ?? 0;
          
          transaction.update(scoreRef, {
            '2048Points': current2048Points + points,
            'totalPoints': currentTotalPoints + points,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(scoreRef, {
            'username': widget.username,
            'timerPoints': 0,
            'puzzlePoints': 0,
            '2048Points': points,
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

void _startSessionTimer() {
  _sessionTimer?.cancel();
  _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    _gameplaySeconds++;
    
    // Show ad every 60 seconds (1 minute)
    if (_gameplaySeconds - _lastAdAt >= 60) {
      _showRewardedAd();
    }
  });
}

void _initGame() {
  // Store previous state for undo functionality
  previousBoard = board.map((row) => List<int>.from(row)).toList();
  previousScore = score;
  
  board = List.generate(4, (_) => List.filled(4, 0));
  score = 0;
  gameOver = false;
  hasWon = false;
  sessionStartTime = DateTime.now();
  
  _startSessionTimer();
  
  _addRandomTile();
  _addRandomTile();
  
  // Trigger board appearance animation
  _tileAnimationController.forward();
  
  setState(() {});
}

  void _addRandomTile() {
    List<Point<int>> emptyCells = [];
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (board[i][j] == 0) {
          emptyCells.add(Point(i, j));
        }
      }
    }
    
    if (emptyCells.isNotEmpty) {
      Point<int> randomCell = emptyCells[_random.nextInt(emptyCells.length)];
      board[randomCell.x][randomCell.y] = _random.nextDouble() < 0.9 ? 2 : 4;
      
      // Animate new tile appearance
      _bounceController.forward().then((_) => _bounceController.reset());
    }
  }

  bool _canMove() {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (board[i][j] == 0) return true;
      }
    }
    
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        int current = board[i][j];
        if ((j < 3 && current == board[i][j + 1]) ||
            (i < 3 && current == board[i + 1][j])) {
          return true;
        }
      }
    }
    
    return false;
  }

  void _move(Direction direction) {
    if (gameOver) return;
    
    // Store current state for comparison
    List<List<int>> oldBoard = board.map((row) => List<int>.from(row)).toList();
    int oldScore = score;
    
    List<List<int>> newBoard = board.map((row) => List<int>.from(row)).toList();
    bool moved = false;
    int scoreIncrease = 0;

    switch (direction) {
      case Direction.left:
        for (int i = 0; i < 4; i++) {
          List<int> row = _compactRow(newBoard[i]);
          Map<String, dynamic> result = _mergeRow(row);
          newBoard[i] = result['row'] as List<int>;
          scoreIncrease += result['score'] as int;
          if (!_listsEqual(board[i], newBoard[i])) moved = true;
        }
        break;
        
      case Direction.right:
        for (int i = 0; i < 4; i++) {
          List<int> row = _compactRow(newBoard[i].reversed.toList());
          Map<String, dynamic> result = _mergeRow(row);
          newBoard[i] = (result['row'] as List<int>).reversed.toList();
          scoreIncrease += result['score'] as int;
          if (!_listsEqual(board[i], newBoard[i])) moved = true;
        }
        break;
        
      case Direction.up:
        for (int j = 0; j < 4; j++) {
          List<int> column = [newBoard[0][j], newBoard[1][j], newBoard[2][j], newBoard[3][j]];
          List<int> compactColumn = _compactRow(column);
          Map<String, dynamic> result = _mergeRow(compactColumn);
          List<int> mergedColumn = result['row'] as List<int>;
          scoreIncrease += result['score'] as int;
          
          bool columnMoved = false;
          for (int i = 0; i < 4; i++) {
            if (board[i][j] != mergedColumn[i]) columnMoved = true;
            newBoard[i][j] = mergedColumn[i];
          }
          if (columnMoved) moved = true;
        }
        break;
        
      case Direction.down:
        for (int j = 0; j < 4; j++) {
          List<int> column = [newBoard[3][j], newBoard[2][j], newBoard[1][j], newBoard[0][j]];
          List<int> compactColumn = _compactRow(column);
          Map<String, dynamic> result = _mergeRow(compactColumn);
          List<int> mergedColumn = result['row'] as List<int>;
          scoreIncrease += result['score'] as int;
          
          bool columnMoved = false;
          for (int i = 0; i < 4; i++) {
            if (board[3-i][j] != mergedColumn[i]) columnMoved = true;
            newBoard[3-i][j] = mergedColumn[i];
          }
          if (columnMoved) moved = true;
        }
        break;
    }

    if (moved) {
      // Store previous state for undo
      previousBoard = board.map((row) => List<int>.from(row)).toList();
      previousScore = score;
      
      board = newBoard;
      score += scoreIncrease;
      _lastSwipeDirection = direction;
      
      // Animate score increase
      if (scoreIncrease > 0) {
        _updateScore(scoreIncrease);
      }
      
      if (score > bestScore) {
        setState(() {
          bestScore = score;
        });
        _saveBestScore();
      }
      
      _addRandomTile();
      
      if (!hasWon) {
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            if (board[i][j] == 2048) {
              hasWon = true;
              _showWinDialog();
              break;
            }
          }
        }
      }
      
      if (!_canMove()) {
        gameOver = true;
        _showGameOverDialog();
      }
      
      setState(() {});
    }
  }

  List<int> _compactRow(List<int> row) {
    List<int> newRow = row.where((tile) => tile != 0).toList();
    while (newRow.length < 4) {
      newRow.add(0);
    }
    return newRow;
  }

  Map<String, dynamic> _mergeRow(List<int> row) {
    int scoreIncrease = 0;
    for (int i = 0; i < 3; i++) {
      if (row[i] != 0 && row[i] == row[i + 1]) {
        row[i] *= 2;
        scoreIncrease += row[i];
        row[i + 1] = 0;
      }
    }
    return {'row': _compactRow(row), 'score': scoreIncrease};
  }

  bool _listsEqual(List<int> list1, List<int> list2) {
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D0F1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTablet ? 20 : 16)),
          title: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
            ).createShader(bounds),
            child: Text(
              'Ruby Master!',
              style: GoogleFonts.dmSerifDisplay(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: isTablet ? 28 : 24,
              ),
            ),
          ),
          content: Text(
            'You reached 2048! Continue playing or start fresh?',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: bodyFontSize,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE91E63),
                  fontSize: bodyFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initGame();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'New Game',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE91E63),
                  fontSize: bodyFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D0F1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isTablet ? 20 : 16)),
          title: Text(
            'Game Over!',
            style: GoogleFonts.dmSerifDisplay(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE91E63),
              fontSize: isTablet ? 28 : 24,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No more moves available!',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: bodyFontSize,
                  height: 1.4,
                ),
              ),
              SizedBox(height: spacingSmall),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
                  ),
                  borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
                ),
                child: Text(
                  'Final Score: $score',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: bodyFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initGame();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 20,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE91E63),
                  fontSize: bodyFontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeLimitWarning() {
  
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: EdgeInsets.only(bottom: spacingMedium),
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.withOpacity(0.25), Colors.red.withOpacity(0.15)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(
          color: Colors.red.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timer,
              color: Colors.red,
              size: isTablet ? 22 : 18,
            ),
          ),
          SizedBox(width: spacingMedium),
          Expanded(
            child: Text(
              'Daily time limit reached',
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontSize: bodyFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Animated wrapper for smooth button interactions
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0B11),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4A1625),
              Color(0xFF2D0F1A),
              Color(0xFF1A0B11),
            ],
          ),
        ),
        child: SafeArea(
        
              child: LayoutBuilder(
  builder: (context, constraints) {
    return _buildGameContent(constraints);
  },
),
            
        ),
      ),
    );
  }

  Widget _buildGameContent(BoxConstraints constraints) {
    return GestureDetector(
      onPanStart: (details) {
        _totalPanDelta = Offset.zero;
      },
      onPanUpdate: (details) {
        _totalPanDelta += details.delta;
      },
      onPanEnd: (details) {
        double dx = _totalPanDelta.dx;
        double dy = _totalPanDelta.dy;
        
        const double minSwipeDistance = 20.0;
        
        if (dx.abs() < minSwipeDistance && dy.abs() < minSwipeDistance) {
          return;
        }
        
        if (dx.abs() > dy.abs()) {
          if (dx > 0) {
            _move(Direction.right);
          } else {
            _move(Direction.left);
          }
        } else {
          if (dy > 0) {
            _move(Direction.down);
          } else {
            _move(Direction.up);
          }
        }
        
        _totalPanDelta = Offset.zero;
      },
      child: Padding(
        padding: screenPadding,
        child: isLandscape && !isTablet
          ? _buildLandscapeLayout(constraints)
          : _buildPortraitLayout(constraints),
      ),
    );
  }

  Widget _buildLandscapeLayout(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              SizedBox(height: spacingMedium),
              _buildScoreSection(),
              SizedBox(height: spacingMedium),
              _buildControls(),
              const Spacer(),
              _buildInstructions(),
            ],
          ),
        ),
        SizedBox(width: spacingLarge),
        Expanded(
          flex: 1,
          child: Center(child: _buildGameBoard()),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    double gameboardHeight = boardSize + 40;
    double remainingHeight = constraints.maxHeight - gameboardHeight;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        SizedBox(height: spacingMedium),
        _buildScoreSection(),
        SizedBox(height: spacingMedium),
        _buildControls(),
        Flexible(
          child: Center(child: _buildGameBoard()),
        ),
        if (remainingHeight > 100) ...[
          SizedBox(height: spacingMedium),
          _buildInstructions(),
        ],
      ],
    );
  }

  Widget _buildScrollableContent(BoxConstraints constraints) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight,
        ),
        child: Padding(
          padding: screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              SizedBox(height: spacingMedium),
              _buildTimeLimitWarning(),
              _buildScoreSection(),
              SizedBox(height: spacingMedium),
              _buildControls(),
              SizedBox(height: spacingLarge),
              Center(child: _buildGameBoard()),
              SizedBox(height: spacingLarge),
              _buildInstructions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
            Icons.grid_4x4, 
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
                  'swipe & merge',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5
                  ),
                ),
              ),
              // Text(
              //   'swipe to combine tiles',
              //   style: GoogleFonts.poppins(
              //     fontSize: subHeaderFontSize,
              //     color: const Color.fromARGB(255, 233, 70, 70)
              //   ),
              // ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreSection() {
    return Container(
      padding: containerPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A1625).withOpacity(0.4),
            const Color(0xFF2D0F1A).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.2),
            blurRadius: isTablet ? 15 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLandscape && !isTablet && isSmallDevice
        ? Column(
            children: [
              _buildScoreBox('Current Score', score, true),
              SizedBox(height: spacingMedium),
              _buildScoreBox('Best Score', bestScore, false),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _buildScoreBox('Current Score', score, true),
              ),
              SizedBox(width: spacingMedium),
              Expanded(
                child: _buildScoreBox('Best Score', bestScore, false),
              ),
            ],
          ),
    );
  }

  Widget _buildControls() {
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
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 8 : 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swipe,
              color: const Color(0xFFE91E63),
              size: isTablet ? 20 : 16,
            ),
          ),
          SizedBox(width: spacingMedium),
          Expanded(
            child: Text(
              'Swipe to move tiles',
              style: GoogleFonts.poppins(
                fontSize: bodyFontSize,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Small New Game button on the right
          _buildAnimatedButton(
             onTap: _initGame,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 10 : 8,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
      colors: [Color(0xFF8B2635), Color(0xFF4A1625)],
    ),
                borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
                boxShadow: [
      BoxShadow(
        color: const Color(0xFF8B2635).withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: isTablet ? 18 : 14,
                  ),
                  SizedBox(width: spacingSmall),
                  Text(
                    'New',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBox(String label, int value, bool isCurrentScore) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrentScore 
            ? [const Color(0xFFE91E63), const Color(0xFF8B2635)]
            : [const Color(0xFF8B2635), const Color(0xFF4A1625)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: (isCurrentScore ? const Color(0xFFE91E63) : const Color(0xFF8B2635))
                .withOpacity(0.4),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 14 : (isCompact ? 9 : (isSmallDevice ? 10 : 12)),
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: GoogleFonts.poppins(
              fontSize: scoreFontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: boardSize,
          height: boardSize,
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF4A1625),
                const Color(0xFF2D0F1A),
              ],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: isTablet ? 20 : 15,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFFE91E63).withOpacity(_glowAnimation.value * 0.3),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE91E63).withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              return Expanded(
                child: Row(
                  children: List.generate(4, (j) {
                    return Expanded(
                      child: _buildTile(board[i][j], i, j),
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildTile(int value, int row, int col) {
    final gradientColors = tileGradients[value] ?? tileGradients[0]!;
    final isNewTile = value > 0 && (previousBoard.isEmpty || previousBoard[row][col] != value);
    
    return AnimatedBuilder(
      animation: isNewTile ? _bounceAnimation : kAlwaysCompleteAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isNewTile ? _bounceAnimation.value : 1.0,
          child: Container(
            margin: EdgeInsets.all(isTablet ? 6 : 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
              boxShadow: value > 0 ? [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.4),
                  blurRadius: isTablet ? 8 : 6,
                  offset: const Offset(0, 3),
                ),
                if (value >= 128) BoxShadow(
                  color: gradientColors[0].withOpacity(0.6),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ] : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: value > 0 
                  ? Colors.white.withOpacity(0.2) 
                  : Colors.transparent,
                width: 1,
              ),
            ),
            child: Center(
              child: value > 0
                  ? AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.poppins(
                        fontSize: _getTileFontSize(value),
                        fontWeight: FontWeight.bold,
                        color: textColors[value] ?? Colors.white,
                        letterSpacing: value >= 1000 ? -0.5 : 0,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _formatTileValue(value),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  String _formatTileValue(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return value.toString();
  }

  double _getTileFontSize(int value) {
    double baseFontSize;
    
    if (isExtraLarge) {
      baseFontSize = value < 100 ? 32 : (value < 1000 ? 28 : 24);
    } else if (isTablet) {
      baseFontSize = value < 100 ? 28 : (value < 1000 ? 24 : 20);
    } else if (isCompact) {
      baseFontSize = value < 100 ? 16 : (value < 1000 ? 14 : 12);
    } else if (isSmallDevice) {
      baseFontSize = value < 100 ? 18 : (value < 1000 ? 16 : 14);
    } else {
      baseFontSize = value < 100 ? 22 : (value < 1000 ? 20 : 16);
    }
    
    // Scale down for very large numbers
    if (value >= 10000) baseFontSize *= 0.8;
    
    return baseFontSize;
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
            const Color(0xFF2D0F1A).withOpacity(0.6),
            const Color(0xFF4A1625).withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 8 : 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline,
                  color: const Color(0xFFE91E63),
                  size: isTablet ? 20 : 16,
                ),
              ),
              SizedBox(width: spacingSmall),
              Text(
                'HOW TO PLAY',
                style: GoogleFonts.poppins(
                  fontSize: bodyFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE91E63),
                ),
              ),
            ],
          ),
          SizedBox(height: spacingMedium),
          Text(
            'Swipe to move tiles. When two tiles with the same number touch, they merge into one! Try to reach the 2048 tile.',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 15 : (isCompact ? 11 : (isSmallDevice ? 12 : 13)),
              color: Colors.white70,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum Direction { up, down, left, right }