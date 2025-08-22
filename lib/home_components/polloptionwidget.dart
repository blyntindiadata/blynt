import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class PollOptionWidget extends StatefulWidget {
  final String option;
  final int index;
  final int voteCount;
  final int totalVotes;
  final bool isSelected;
  final String pollId;
  final String communityId;
  final String userId;
  final String username;
  final VoidCallback onVote;

  const PollOptionWidget({
    Key? key,
    required this.option,
    required this.index,
    required this.voteCount,
    required this.totalVotes,
    required this.isSelected,
    required this.pollId,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.onVote,
  }) : super(key: key);

  @override
  State<PollOptionWidget> createState() => _PollOptionWidgetState();
}

class _PollOptionWidgetState extends State<PollOptionWidget>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _progressController;
  late AnimationController _glowController;
  late AnimationController _rippleController;
  late AnimationController _bounceController;
  late AnimationController _clickController; // New click animation
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _clickAnimation; // New click animation
  
  bool _isVoting = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    // New click animation controller
    _clickController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _clickAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _clickController,
      curve: Curves.easeInOut,
    ));

    _progressController.forward();
    
    if (widget.isSelected) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PollOptionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _glowController.repeat(reverse: true);
        _bounceController.forward().then((_) {
          _bounceController.reverse();
        });
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    }

    if (widget.voteCount != oldWidget.voteCount) {
      _progressController.reset();
      _progressController.forward();
      _bounceController.forward().then((_) {
        _bounceController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _progressController.dispose();
    _glowController.dispose();
    _rippleController.dispose();
    _bounceController.dispose();
    _clickController.dispose(); // Dispose click controller
    super.dispose();
  }

  Future<void> _handleVote() async {
    if (_isVoting) return;

    // Trigger click animation
    _clickController.forward().then((_) {
      _clickController.reverse();
    });
    
    _rippleController.forward();
    
    setState(() => _isVoting = true);

    try {
      final pollRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('polls')
          .doc(widget.pollId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final pollDoc = await transaction.get(pollRef);
        
        if (!pollDoc.exists) {
          throw Exception('Poll not found');
        }

        final pollData = pollDoc.data()!;
        final votes = Map<String, dynamic>.from(pollData['votes'] ?? {});
        final optionCounts = List<int>.from(pollData['optionCounts'] ?? []);
        final voteTimestamps = Map<String, dynamic>.from(pollData['voteTimestamps'] ?? {});
        
        // Ensure optionCounts has enough elements
        while (optionCounts.length <= widget.index) {
          optionCounts.add(0);
        }
        
        // Remove previous vote if exists - use index-based keys consistently
        String? previousOption;
        for (int i = 0; i < optionCounts.length; i++) {
          final optionKey = 'option_$i'; // Always use index-based keys
          final votersList = votes[optionKey];
          if (votersList is List) {
            final voters = List<String>.from(votersList);
            if (voters.contains(widget.username)) {
              previousOption = optionKey;
              voters.remove(widget.username);
              votes[optionKey] = voters;
              optionCounts[i] = math.max(0, optionCounts[i] - 1);
              break;
            }
          }
        }

        final currentOptionKey = 'option_${widget.index}'; // Use index-based key
        if (previousOption != currentOptionKey) {
          // Add new vote
          if (votes[currentOptionKey] == null) {
            votes[currentOptionKey] = <String>[];
          }
          final votersList = votes[currentOptionKey];
          final voters = votersList is List ? List<String>.from(votersList) : <String>[];
          voters.add(widget.username);
          votes[currentOptionKey] = voters;
          
          optionCounts[widget.index] = optionCounts[widget.index] + 1;
          voteTimestamps[widget.username] = FieldValue.serverTimestamp();
        } else {
          // Toggle off - remove vote timestamp
          voteTimestamps.remove(widget.username);
        }

        final totalVotes = optionCounts.fold<int>(0, (sum, count) => sum + count);

        transaction.update(pollRef, {
          'votes': votes,
          'optionCounts': optionCounts,
          'voteTimestamps': voteTimestamps,
          'totalVotes': totalVotes,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      });

      // Success animation
      _bounceController.forward().then((_) {
        _bounceController.reverse();
      });
      
      widget.onVote();
      
    } catch (e) {
      print('Error voting: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to vote: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
      _rippleController.reset();
    }
  }

  double get _progressValue {
    if (widget.totalVotes == 0) return 0.0;
    return widget.voteCount / widget.totalVotes;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isCompact = screenWidth < 350;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scaleAnimation, 
          _glowAnimation, 
          _bounceAnimation, 
          _rippleAnimation,
          _clickAnimation, // Include click animation
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value * _bounceAnimation.value * _clickAnimation.value,
            child: GestureDetector(
              onTapDown: (_) => _scaleController.forward(),
              onTapUp: (_) {
                _scaleController.reverse();
                _handleVote();
              },
              onTapCancel: () => _scaleController.reverse(),
              child: Container(
                margin: EdgeInsets.only(
                  bottom: isTablet ? 16 : (isCompact ? 8 : 12)
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    isTablet ? 20 : (isCompact ? 12 : 16)
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B263B).withOpacity(0.4),
                      blurRadius: isTablet ? 16 : 12,
                      offset: const Offset(0, 4),
                    ),
                    if (widget.isSelected)
                      BoxShadow(
                        color: const Color(0xFF64B5F6).withOpacity(0.6 * _glowAnimation.value),
                        blurRadius: isTablet ? 30 : 20,
                        offset: const Offset(0, 0),
                      ),
                    if (_isHovered && !widget.isSelected)
                      BoxShadow(
                        color: Colors.white.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 0),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    isTablet ? 20 : (isCompact ? 12 : 16)
                  ),
                  child: Stack(
                    children: [
                      // Background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: widget.isSelected
                                ? [
                                    const Color(0xFF1976D2).withOpacity(0.3),
                                    const Color(0xFF64B5F6).withOpacity(0.2),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.04),
                                  ],
                          ),
                          border: Border.all(
                            color: widget.isSelected
                                ? const Color(0xFF64B5F6).withOpacity(0.6)
                                : Colors.white.withOpacity(0.1),
                            width: widget.isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                      
                      // Enhanced ripple effect with color transition
                      if (_rippleAnimation.value > 0)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: _rippleAnimation.value * 1.5,
                                colors: [
                                  const Color(0xFF64B5F6).withOpacity(
                                    0.5 * (1 - _rippleAnimation.value)
                                  ),
                                  const Color(0xFF1976D2).withOpacity(
                                    0.3 * (1 - _rippleAnimation.value)
                                  ),
                                  Colors.transparent,
                                ],
                                stops: [
                                  0.0,
                                  _rippleAnimation.value * 0.7,
                                  1.0,
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // Enhanced progress bar with smooth animation
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, child) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                stops: [
                                  0.0,
                                  _progressValue * _progressAnimation.value,
                                  _progressValue * _progressAnimation.value,
                                  1.0,
                                ],
                                colors: [
                                  const Color(0xFF1976D2).withOpacity(0.25),
                                  const Color(0xFF64B5F6).withOpacity(0.25),
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      // Content with improved spacing and animations
                      Padding(
                        padding: EdgeInsets.all(
                          isTablet ? 20 : (isCompact ? 12 : 16)
                        ),
                        child: Row(
                          children: [
                            // Enhanced option indicator with smooth transitions
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              width: isTablet ? 40 : (isCompact ? 28 : 32),
                              height: isTablet ? 40 : (isCompact ? 28 : 32),
                              decoration: BoxDecoration(
                                gradient: widget.isSelected
                                    ? LinearGradient(
                                        colors: [
                                          const Color(0xFF1976D2),
                                          const Color(0xFF64B5F6),
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.25),
                                          Colors.white.withOpacity(0.15),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(
                                  isTablet ? 10 : 8
                                ),
                                border: Border.all(
                                  color: widget.isSelected
                                      ? Colors.white.withOpacity(0.4)
                                      : Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: widget.isSelected ? [
                                  BoxShadow(
                                    color: const Color(0xFF1976D2).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ] : null,
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: widget.isSelected
                                    ? Icon(
                                        Icons.check,
                                        key: const ValueKey('check'),
                                        color: Colors.white,
                                        size: isTablet ? 22 : (isCompact ? 14 : 18),
                                      )
                                    : Text(
                                        '${widget.index + 1}',
                                        key: const ValueKey('number'),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white70,
                                          fontSize: isTablet ? 16 : (isCompact ? 11 : 14),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            
                            SizedBox(width: isTablet ? 20 : (isCompact ? 10 : 14)),
                            
                            // Option text with better formatting for duplicates
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 17 : (isCompact ? 12 : 14),
                                      fontWeight: widget.isSelected 
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: widget.isSelected 
                                          ? Colors.white 
                                          : Colors.white.withOpacity(0.9),
                                      height: 1.3,
                                    ),
                                    child: Text(widget.option),
                                  ),
                                  // Show option number for duplicate text
                                  if (_hasDuplicateOptions())
                                    Text(
                                      'Option ${widget.index + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: isTablet ? 11 : (isCompact ? 8 : 9),
                                        color: Colors.white.withOpacity(0.5),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            
                            SizedBox(width: isTablet ? 16 : (isCompact ? 8 : 12)),
                            
                            // Enhanced vote count and percentage display
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 12 : (isCompact ? 6 : 8),
                                    vertical: isTablet ? 6 : (isCompact ? 3 : 4),
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: widget.isSelected
                                        ? LinearGradient(
                                            colors: [
                                              const Color(0xFF1976D2),
                                              const Color(0xFF64B5F6),
                                            ],
                                          )
                                        : LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.2),
                                              Colors.white.withOpacity(0.1),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: widget.isSelected ? [
                                      BoxShadow(
                                        color: const Color(0xFF1976D2).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ] : null,
                                  ),
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 16 : (isCompact ? 11 : 13),
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    child: Text('${widget.voteCount}'),
                                  ),
                                ),
                                
                                if (widget.totalVotes > 0) ...[
                                  SizedBox(height: isTablet ? 4 : 2),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 13 : (isCompact ? 9 : 11),
                                      color: widget.isSelected 
                                          ? const Color(0xFF64B5F6)
                                          : Colors.white60,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    child: Text('${((_progressValue) * 100).toInt()}%'),
                                  ),
                                ],
                              ],
                            ),
                            
                            // Enhanced loading indicator
                            if (_isVoting) ...[
                              SizedBox(width: isTablet ? 16 : (isCompact ? 8 : 12)),
                              SizedBox(
                                width: isTablet ? 24 : (isCompact ? 16 : 20),
                                height: isTablet ? 24 : (isCompact ? 16 : 20),
                                child: CircularProgressIndicator(
                                  color: const Color(0xFF64B5F6),
                                  strokeWidth: isTablet ? 3 : 2,
                                ),
                              ),
                            ],
                          ],
                        ),
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

  // Helper method to check if there are duplicate options
  bool _hasDuplicateOptions() {
    // This would need to be passed from parent or calculated
    // For now, return false - you can implement this logic in the parent widget
    return false;
  }
}