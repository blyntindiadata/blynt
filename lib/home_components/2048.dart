import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:async';

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

class _Ruby2048GameState extends State<Ruby2048Game> with TickerProviderStateMixin {
  List<List<int>> board = List.generate(4, (_) => List.filled(4, 0));
  int score = 0;
  int bestScore = 0;
  bool gameOver = false;
  bool hasWon = false;
  int timePlayedToday = 0; // in seconds
  bool canPlay = true;
  DateTime? sessionStartTime;
  Timer? _sessionTimer;
  int remainingTime = 180; // 30 minutes
  
  // For tracking swipe gestures
  Offset _totalPanDelta = Offset.zero;
  Direction? _lastSwipeDirection;
  
  final Random _random = Random();
  
  // Enhanced Ruby-themed colors (simple solid colors)
  final Map<int, Color> tileColors = {
    0: const Color(0xFF2D0F1A),
    2: const Color(0xFF4A1625),
    4: const Color(0xFF6B1E2F),
    8: const Color(0xFF8B2635),
    16: const Color(0xFFA52A3A),
    32: const Color(0xFFBF2E3F),
    64: const Color(0xFFD93244),
    128: const Color(0xFFE91E63),
    256: const Color(0xFFEC407A),
    512: const Color(0xFFEF5350),
    1024: const Color(0xFFF44336),
    2048: const Color(0xFFFF5722),
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

  // Responsive design helpers
  bool get isTablet => MediaQuery.of(context).size.shortestSide >= 600;
  bool get isLandscape => MediaQuery.of(context).orientation == Orientation.landscape;
  bool get isSmallDevice => MediaQuery.of(context).size.height < 600;
  
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  double get availableHeight => screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom;
  
  // Dynamic sizing based on screen size
  double get boardSize {
    double maxSize = isTablet ? 400 : 320;
    double padding = isTablet ? 32 : 16;
    return min(maxSize, screenWidth - (padding * 2));
  }
  
  double get tileSize => (boardSize - 32) / 4 - 8;
  
  double get headerFontSize => isTablet ? 28 : (isSmallDevice ? 18 : 22);
  double get scoreFontSize => isTablet ? 28 : (isSmallDevice ? 20 : 24);
  double get tileFontSize => isTablet ? 24 : (isSmallDevice ? 16 : 20);
  
  EdgeInsets get screenPadding => EdgeInsets.all(isTablet ? 24 : (isSmallDevice ? 12 : 16));

  @override
  void initState() {
    super.initState();
    _loadGameData();
    _initGame();
  }

  @override
  void dispose() {
    _saveSessionTime();
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGameData() async {
    await _loadTodayPlayTime();
    await _loadBestScore();
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

  Future<void> _loadTodayPlayTime() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_time')
          .doc('${widget.username}_2048_$todayString')
          .get();

      if (doc.exists) {
        setState(() {
          timePlayedToday = doc.data()?['timePlayedSeconds'] ?? 0;
          remainingTime = 180 - timePlayedToday;
          canPlay = timePlayedToday < 180;
        });
      } else {
        setState(() {
          timePlayedToday = 0;
          remainingTime = 180;
          canPlay = true;
        });
      }
    } catch (e) {
      print('Error loading play time: $e');
    }
  }

  Future<void> _saveSessionTime() async {
    if (sessionStartTime == null) return;
    
    try {
      final sessionDuration = DateTime.now().difference(sessionStartTime!).inSeconds;
      final today = DateTime.now();
      final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_time')
          .doc('${widget.username}_2048_$todayString')
          .set({
        'username': widget.username,
        'game': '2048',
        'timePlayedSeconds': timePlayedToday + sessionDuration,
        'date': todayString,
        'lastSession': FieldValue.serverTimestamp(),
      });

      setState(() {
        timePlayedToday += sessionDuration;
        remainingTime = 180 - timePlayedToday;
        canPlay = timePlayedToday < 180;
      });
    } catch (e) {
      print('Error saving session time: $e');
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
      if (remainingTime > 0) {
        setState(() {
          remainingTime--;
        });
      } else {
        setState(() {
          canPlay = false;
        });
        _saveSessionTime();
        timer.cancel();
      }
    });
  }

  void _initGame() {
    if (!canPlay) return;
    
    board = List.generate(4, (_) => List.filled(4, 0));
    score = 0;
    gameOver = false;
    hasWon = false;
    sessionStartTime = DateTime.now();
    
    _startSessionTimer();
    
    _addRandomTile();
    _addRandomTile();
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
    if (gameOver || !canPlay) return;
    
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
      board = newBoard;
      score += scoreIncrease;
      _lastSwipeDirection = direction;
      
      if (score > bestScore) {
        setState(() {
          bestScore = score;
        });
        _saveBestScore();
      }
      
      if (scoreIncrease > 0) {
        _updateScore(scoreIncrease);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
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
              fontSize: isTablet ? 16 : 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE91E63),
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initGame();
              },
              child: Text(
                'New Game',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE91E63),
                  fontSize: isTablet ? 16 : 14,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Game Over!',
            style: GoogleFonts.dmSerifDisplay(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE91E63),
              fontSize: isTablet ? 28 : 24,
            ),
          ),
          content: Text(
            'No more moves available!\nFinal Score: $score',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: isTablet ? 16 : 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _initGame();
              },
              child: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFE91E63),
                  fontSize: isTablet ? 16 : 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeLimitWarning() {
    if (canPlay) return const SizedBox.shrink();
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16, 
        vertical: isTablet ? 12 : 8
      ),
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE91E63).withOpacity(0.2),
        borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        border: Border.all(color: const Color(0xFFE91E63)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.timer, 
            color: const Color(0xFFE91E63),
            size: isTablet ? 24 : 20,
          ),
          SizedBox(width: isTablet ? 12 : 8),
          Expanded(
            child: Text(
              'Daily play time reached! Try again tomorrow.',
              style: GoogleFonts.poppins(
                color: const Color(0xFFE91E63),
                fontSize: isTablet ? 14 : 12,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0B11),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4A1625),
              const Color(0xFF2D0F1A),
              const Color(0xFF1A0B11),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return canPlay 
                ? _buildGameContent(constraints)
                : _buildScrollableContent(constraints);
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
        
        const double minSwipeDistance = 15.0;
        
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
              SizedBox(height: isSmallDevice ? 8 : 16),
              _buildScoreSection(),
              SizedBox(height: isSmallDevice ? 8 : 16),
              _buildControls(),
              const Spacer(),
              _buildInstructions(),
            ],
          ),
        ),
        SizedBox(width: isTablet ? 24 : 16),
        Expanded(
          flex: 1,
          child: Center(child: _buildGameBoard()),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout(BoxConstraints constraints) {
    double availableHeight = constraints.maxHeight;
    double gameboardHeight = boardSize + 32;
    double remainingHeight = availableHeight - gameboardHeight;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        SizedBox(height: isTablet ? 16 : (isSmallDevice ? 8 : 12)),
        _buildScoreSection(),
        SizedBox(height: isTablet ? 20 : (isSmallDevice ? 12 : 16)),
        _buildControls(),
        Flexible(
          child: Center(child: _buildGameBoard()),
        ),
        if (remainingHeight > 100) ...[
          SizedBox(height: isTablet ? 16 : (isSmallDevice ? 8 : 12)),
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
              SizedBox(height: isTablet ? 16 : 12),
              _buildTimeLimitWarning(),
              _buildScoreSection(),
              SizedBox(height: isTablet ? 20 : 16),
              _buildControls(),
              SizedBox(height: isTablet ? 24 : 20),
              Center(child: _buildGameBoard()),
              SizedBox(height: isTablet ? 24 : 20),
              _buildInstructions(),
              SizedBox(height: isTablet ? 16 : 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
        Icons.grid_4x4, 
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
                  'ruby 2048',
                  style: GoogleFonts.dmSerifDisplay(
                   fontSize: headerFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                  ),
                ),
              ),
              Text(
                'time remaining: ${_formatTime(remainingTime)}',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : (isSmallDevice ? 10 : 12),
                  color: canPlay ? const Color(0xFFE91E63) : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScoreSection() {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4A1625).withOpacity(0.3),
            const Color(0xFF2D0F1A).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: isLandscape && !isTablet && isSmallDevice
        ? Column(
            children: [
              _buildScoreBox('Current Score', score, true),
              SizedBox(height: 12),
              _buildScoreBox('Best Score', bestScore, false),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _buildScoreBox('Current Score', score, true),
              ),
              SizedBox(width: isTablet ? 20 : 16),
              Expanded(
                child: _buildScoreBox('Best Score', bestScore, false),
              ),
            ],
          ),
    );
  }

  Widget _buildControls() {
    return Flex(
      direction: isLandscape && !isTablet ? Axis.vertical : Axis.horizontal,
      mainAxisAlignment: isLandscape && !isTablet 
        ? MainAxisAlignment.start 
        : MainAxisAlignment.spaceBetween,
      crossAxisAlignment: isLandscape && !isTablet
        ? CrossAxisAlignment.stretch
        : CrossAxisAlignment.center,
      children: [
        Text(
          'Swipe to move tiles',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 16 : (isSmallDevice ? 12 : 14),
            color: Colors.white60,
          ),
        ),
        if (isLandscape && !isTablet) SizedBox(height: 12),
        ElevatedButton(
          onPressed: canPlay ? _initGame : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B2635),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 20, 
              vertical: isTablet ? 16 : 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
            ),
            minimumSize: Size(
              isLandscape && !isTablet ? double.infinity : 0,
              isTablet ? 48 : 40,
            ),
          ),
          child: Text(
            'New Game',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: isTablet ? 16 : 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBox(String label, int value, bool isCurrentScore) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isCurrentScore 
            ? [const Color(0xFFE91E63), const Color(0xFF8B2635)]
            : [const Color(0xFF8B2635), const Color(0xFF4A1625)],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        boxShadow: [
          BoxShadow(
            color: (isCurrentScore ? const Color(0xFFE91E63) : const Color(0xFF8B2635))
                .withOpacity(0.3),
            blurRadius: isTablet ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 14 : (isSmallDevice ? 10 : 12),
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 4),
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
    return Container(
      width: boardSize,
      height: boardSize,
      padding: EdgeInsets.all(isTablet ? 12 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4A1625),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: isTablet ? 16 : 10,
            offset: const Offset(0, 4),
          ),
        ],
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
  }

  Widget _buildTile(int value, int row, int col) {
    return Container(
      margin: EdgeInsets.all(isTablet ? 6 : 4),
      decoration: BoxDecoration(
        color: tileColors[value] ?? tileColors[0],
        borderRadius: BorderRadius.circular(isTablet ? 8 : 6),
        boxShadow: value > 0 ? [
          BoxShadow(
            color: (tileColors[value] ?? Colors.black).withOpacity(0.3),
            blurRadius: isTablet ? 6 : 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Center(
        child: value > 0
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: _getTileFontSize(value),
                    fontWeight: FontWeight.bold,
                    color: textColors[value] ?? Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  double _getTileFontSize(int value) {
    if (value < 100) {
      return isTablet ? 28 : (isSmallDevice ? 18 : 22);
    } else if (value < 1000) {
      return isTablet ? 24 : (isSmallDevice ? 16 : 20);
    } else {
      return isTablet ? 20 : (isSmallDevice ? 14 : 16);
    }
  }

  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D0F1A).withOpacity(0.5),
            const Color(0xFF4A1625).withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            'HOW TO PLAY',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFE91E63),
            ),
          ),
          SizedBox(height: isTablet ? 12 : 8),
          Text(
            'Swipe to move tiles. When two tiles with the same number touch, they merge into one! Try to reach the 2048 tile.',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 15 : (isSmallDevice ? 12 : 13),
              color: Colors.white70,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum Direction { up, down, left, right }