import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class PollVotesPage extends StatefulWidget {
  final Map<String, dynamic> poll;
  final String communityId;
  final Future<Map<String, dynamic>?> Function(String) getUserData;

  const PollVotesPage({
    Key? key,
    required this.poll,
    required this.communityId,
    required this.getUserData,
  }) : super(key: key);

  @override
  State<PollVotesPage> createState() => _PollVotesPageState();
}

class _PollVotesPageState extends State<PollVotesPage> with TickerProviderStateMixin {
  final ValueNotifier<Map<String, List<String>>> _votesNotifier = ValueNotifier({});
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  TabController? _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<String> options = [];
  Map<String, Map<String, dynamic>> _userDataCache = {};
  late Stream<DocumentSnapshot> _pollStream;
  Map<String, dynamic> _currentPollData = {};

  // Enhanced responsive breakpoints
  bool get _isVerySmall => MediaQuery.of(context).size.width < 320;
  bool get _isSmall => MediaQuery.of(context).size.width < 350;
  bool get _isMedium => MediaQuery.of(context).size.width < 400;
  bool get _isLarge => MediaQuery.of(context).size.width < 600;
  bool get _isTablet => MediaQuery.of(context).size.width >= 600;
  bool get _isLandscape => MediaQuery.of(context).size.aspectRatio > 1.2;

  @override
  void initState() {
    super.initState();
    _currentPollData = Map<String, dynamic>.from(widget.poll);
    options = List<String>.from(_currentPollData['options'] ?? []);
    _initTabController();
    _initAnimations();
    _initRealTimeListener();
    _loadVotes();
  }

  void _initTabController() {
    _tabController?.dispose();
    if (options.isNotEmpty) {
      _tabController = TabController(length: options.length, vsync: this);
    }
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
  }

  void _initRealTimeListener() {
    final pollId = _currentPollData['id'] ?? _currentPollData['pollId'];
    
    if (pollId != null) {
      _pollStream = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('polls')
          .doc(pollId)
          .snapshots();
      
      _pollStream.listen((snapshot) {
        if (snapshot.exists && mounted) {
          final updatedPoll = snapshot.data() as Map<String, dynamic>;
          final newOptions = List<String>.from(updatedPoll['options'] ?? []);
          
          setState(() {
            _currentPollData = {
              'id': pollId,
              ...updatedPoll,
            };
            
            if (newOptions.length != options.length) {
              options = newOptions;
              _initTabController();
            } else {
              options = newOptions;
            }
          });
          
          _updateVotesFromSnapshot(updatedPoll);
          _triggerPulseAnimation();
        }
      });
    }
  }

  void _triggerPulseAnimation() {
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }

  void _updateVotesFromSnapshot(Map<String, dynamic> pollData) {
    final votes = Map<String, dynamic>.from(pollData['votes'] ?? {});
    final processedVotes = <String, List<String>>{};
    
    for (int i = 0; i < options.length; i++) {
      final optionKey = 'option_$i';
      final voters = votes[optionKey];
      if (voters is List) {
        final uniqueKey = _getUniqueOptionKey(options[i], i);
        processedVotes[uniqueKey] = voters.map((v) => v.toString()).toList();
      } else {
        final uniqueKey = _getUniqueOptionKey(options[i], i);
        processedVotes[uniqueKey] = [];
      }
    }

    _votesNotifier.value = processedVotes;
  }

  String _getUniqueOptionKey(String option, int index) {
    final optionCount = options.where((o) => o == option).length;
    if (optionCount > 1) {
      final duplicateIndex = options.take(index + 1).where((o) => o == option).length;
      return '$option (Option $duplicateIndex)';
    }
    return option;
  }

  @override
  void dispose() {
    _votesNotifier.dispose();
    _isLoadingNotifier.dispose();
    _tabController?.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadVotes() async {
    try {
      _isLoadingNotifier.value = true;
      
      final votes = Map<String, dynamic>.from(_currentPollData['votes'] ?? {});
      final processedVotes = <String, List<String>>{};
      
      for (int i = 0; i < options.length; i++) {
        final optionKey = 'option_$i';
        final voters = votes[optionKey];
        if (voters is List) {
          final uniqueKey = _getUniqueOptionKey(options[i], i);
          processedVotes[uniqueKey] = voters.map((v) => v.toString()).toList();
        } else {
          final uniqueKey = _getUniqueOptionKey(options[i], i);
          processedVotes[uniqueKey] = [];
        }
      }

      final allVoters = processedVotes.values.expand((voters) => voters).toSet();
      for (String username in allVoters) {
        if (!_userDataCache.containsKey(username)) {
          final userData = await widget.getUserData(username);
          _userDataCache[username] = userData ?? {};
        }
      }

      _votesNotifier.value = processedVotes;
    } catch (e) {
      print('Error loading votes: $e');
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  // Responsive sizing helpers
  EdgeInsets _getResponsivePadding() {
    if (_isVerySmall) return const EdgeInsets.all(12);
    if (_isSmall) return const EdgeInsets.all(16);
    if (_isMedium) return const EdgeInsets.all(18);
    if (_isTablet) return const EdgeInsets.all(24);
    return const EdgeInsets.all(20);
  }

  double _getResponsiveFontSize({required double small, required double medium, required double large}) {
    if (_isVerySmall) return small * 0.85;
    if (_isSmall) return small;
    if (_isMedium) return medium;
    if (_isTablet) return large;
    return medium;
  }

  double _getResponsiveIconSize() {
    if (_isVerySmall) return 16;
    if (_isSmall) return 18;
    if (_isTablet) return 28;
    return 24;
  }
@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final totalVotes = _currentPollData['totalVotes'] ?? 0;
  final optionCounts = List<int>.from(_currentPollData['optionCounts'] ?? []);

  return Scaffold(
    backgroundColor: const Color(0xFF0D1B2A),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1B263B),
            const Color(0xFF0D1B2A),
            const Color(0xFF041426),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _isLandscape 
            ? _buildLandscapeLayout(screenWidth, totalVotes, optionCounts)
            : _buildPortraitLayout(screenWidth, totalVotes, optionCounts),
        ),
      ),
    ),
  );
}
Widget _buildLandscapeLayout(double screenWidth, int totalVotes, List<int> optionCounts) {
  return CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: Column(
          children: [
            _buildHeader(screenWidth),
            _buildPollSummary(totalVotes, optionCounts, screenWidth),
            if (_tabController != null && options.isNotEmpty)
              _buildTabBar(screenWidth),
          ],
        ),
      ),
      if (_tabController != null && options.isNotEmpty)
        SliverFillRemaining(
          child: _buildTabBarView(screenWidth),
        )
      else
        SliverFillRemaining(
          child: Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF64B5F6),
              strokeWidth: _isTablet ? 4 : (_isVerySmall ? 2 : 3),
            ),
          ),
        ),
    ],
  );
}

Widget _buildPortraitLayout(double screenWidth, int totalVotes, List<int> optionCounts) {
  return Column(
    children: [
      _buildHeader(screenWidth),
      _buildPollSummary(totalVotes, optionCounts, screenWidth),
      if (_tabController != null && options.isNotEmpty) ...[
        _buildTabBar(screenWidth),
        Expanded(
          child: _buildTabBarView(screenWidth),
        ),
      ] else ...[
        Expanded(
          child: Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF64B5F6),
              strokeWidth: _isTablet ? 4 : (_isVerySmall ? 2 : 3),
            ),
          ),
        ),
      ],
    ],
  );
}
  Widget _buildHeader(double screenWidth) {
    return Container(
      padding: _getResponsivePadding(),
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //     colors: [
      //       const Color(0xFF1B263B).withOpacity(0.3),
      //       Colors.transparent,
      //     ],
      //   ),
      // ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(_isVerySmall ? 6 : (_isSmall ? 8 : (_isTablet ? 10 : 8))),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_isTablet ? 14 : 12),
                border: Border.all(
                  color: const Color(0xFF64B5F6).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: _getResponsiveIconSize() * 0.8,
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(left: _isVerySmall ? 8 : 15),
            padding: EdgeInsets.all(_isVerySmall ? 8 : (_isSmall ? 10 : (_isTablet ? 16 : 12))),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1B263B), const Color(0xFF0D1B2A)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B263B).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.how_to_vote,
              color: Colors.white,
              size: _getResponsiveIconSize(),
            ),
          ),
          SizedBox(width: _isVerySmall ? 8 : (_isTablet ? 20 : 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
                  ).createShader(bounds),
                  child: Text(
                    'poll votes',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: _getResponsiveFontSize(small: 16, medium: 20, large: 28),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                Text(
                  'see who voted for what',
                  style: GoogleFonts.poppins(
                    fontSize: _getResponsiveFontSize(small: 9, medium: 12, large: 14),
                    color: const Color(0xFF64B5F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollSummary(int totalVotes, List<int> optionCounts, double screenWidth) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: _isVerySmall ? 12 : (_isTablet ? 24 : 16),
        vertical: _isVerySmall ? 6 : (_isTablet ? 12 : 8),
      ),
      padding: EdgeInsets.all(_isVerySmall ? 12 : (_isTablet ? 20 : 14)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B263B).withOpacity(0.2),
            const Color(0xFF0D1B2A).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(_isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xFF1B263B).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _currentPollData['question'] ?? '',
            style: GoogleFonts.poppins(
              fontSize: _getResponsiveFontSize(small: 12, medium: 15, large: 18),
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            maxLines: _isVerySmall ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _isVerySmall ? 8 : (_isTablet ? 16 : 12)),
          Wrap(
            spacing: _isVerySmall ? 4 : 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isVerySmall ? 6 : (_isTablet ? 12 : 8),
                  vertical: _isVerySmall ? 3 : (_isTablet ? 6 : 4),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total Votes: $totalVotes',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: _getResponsiveFontSize(small: 9, medium: 12, large: 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isVerySmall ? 6 : (_isTablet ? 12 : 8),
                  vertical: _isVerySmall ? 3 : (_isTablet ? 6 : 4),
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Options: ${options.length}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: _getResponsiveFontSize(small: 9, medium: 12, large: 14),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(double screenWidth) {
    if (_tabController == null || options.isEmpty) {
      return const SizedBox.shrink();
    }

    final tabCount = options.length;
    
    // Enhanced scrolling logic based on actual content and screen size
    int targetVisibleTabs;
    if (_isVerySmall) {
      targetVisibleTabs = 2;
    } else if (_isSmall) {
      targetVisibleTabs = 3;
    } else if (_isMedium) {
      targetVisibleTabs = 4;
    } else if (_isTablet) {
      targetVisibleTabs = 6;
    } else {
      targetVisibleTabs = 4;
    }
    
    // Check if options have long text that would require scrolling anyway
    final hasLongOptions = options.any((option) => option.length > 12);
    final shouldScroll = tabCount > targetVisibleTabs || hasLongOptions;
    
    return Container(
      margin: EdgeInsets.all(_isVerySmall ? 12 : (_isTablet ? 24 : 16)),
      height: _isVerySmall ? 40 : (_isTablet ? 60 : 50),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF1B263B).withOpacity(0.3)),
      ),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: TabBar(
              controller: _tabController,
              isScrollable: shouldScroll,
              tabAlignment: shouldScroll ? TabAlignment.start : TabAlignment.fill,
              padding: EdgeInsets.symmetric(horizontal: _isVerySmall ? 4 : 8),
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: _getResponsiveFontSize(small: 8, medium: 11, large: 13),
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: _getResponsiveFontSize(small: 8, medium: 11, large: 13),
              ),
              dividerColor: Colors.transparent,
              tabs: options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final count = index < _currentPollData['optionCounts'].length 
                    ? _currentPollData['optionCounts'][index] 
                    : 0;
                
                // Enhanced tab width calculation
                final availableWidth = screenWidth - (_isVerySmall ? 24 : (_isTablet ? 48 : 32));
                double tabWidth;
                
                if (shouldScroll) {
                  // For scrollable tabs, use minimum width with proper spacing
                  final minTabWidth = _isVerySmall ? 60.0 : (_isTablet ? 120.0 : 80.0);
                  final maxTabWidth = availableWidth / 2.5; // Never take more than 40% of screen
                  tabWidth = minTabWidth.clamp(minTabWidth, maxTabWidth);
                } else {
                  tabWidth = (availableWidth / tabCount) - 4;
                }
                
                // Improved text truncation based on actual available space
                final charWidth = _getResponsiveFontSize(small: 6, medium: 8, large: 10);
                final maxChars = (tabWidth / charWidth).floor().clamp(3, 25);
                
                String displayText = option.length > maxChars 
                    ? '${option.substring(0, maxChars)}...' 
                    : option;
                
                // Handle duplicate options in tab display
                final duplicateCount = options.where((o) => o == option).length;
                if (duplicateCount > 1) {
                  final duplicateIndex = options.take(index + 1).where((o) => o == option).length;
                  final suffix = ' ($duplicateIndex)';
                  final availableForText = maxChars - suffix.length;
                  if (availableForText > 3) {
                    displayText = option.length > availableForText 
                        ? '${option.substring(0, availableForText)}...$suffix'
                        : '$option$suffix';
                  }
                }
                
                return Tab(
                  child: Container(
                    width: shouldScroll ? tabWidth : null,
                    constraints: BoxConstraints(
                      minWidth: _isVerySmall ? 50 : (_isTablet ? 100 : 70),
                      maxWidth: shouldScroll ? tabWidth : double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            displayText,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                        SizedBox(height: _isVerySmall ? 1 : (_isTablet ? 4 : 2)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: _isVerySmall ? 3 : (_isTablet ? 6 : 4),
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.poppins(
                              fontSize: _getResponsiveFontSize(small: 7, medium: 9, large: 11),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBarView(double screenWidth) {
  if (_tabController == null || options.isEmpty) {
    return const SizedBox.shrink();
  }

  return ValueListenableBuilder<bool>(
    valueListenable: _isLoadingNotifier,
    builder: (context, isLoading, child) {
      if (isLoading) {
        return Center(
          child: CircularProgressIndicator(
            color: const Color(0xFF64B5F6),
            strokeWidth: _isTablet ? 4 : (_isVerySmall ? 2 : 3),
          ),
        );
      }

      return ValueListenableBuilder<Map<String, List<String>>>(
        valueListenable: _votesNotifier,
        builder: (context, votes, child) {
          return TabBarView(
            controller: _tabController,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final uniqueKey = _getUniqueOptionKey(option, index);
              final voters = votes[uniqueKey] ?? [];
              return Container(
                height: double.infinity,
                child: _buildVotersList(option, voters, screenWidth, index),
              );
            }).toList(),
          );
        },
      );
    },
  );
}

Widget _buildVotersList(String option, List<String> voters, double screenWidth, int optionIndex) {
  if (voters.isEmpty) {
    return _buildEmptyVoters(option, screenWidth, optionIndex);
  }

  // Adaptive padding for landscape mode
  final listPadding = _isLandscape 
      ? EdgeInsets.symmetric(
          horizontal: _isVerySmall ? 8 : (_isTablet ? 16 : 12),
          vertical: _isVerySmall ? 6 : (_isTablet ? 12 : 8),
        )
      : _getResponsivePadding();
  
  return ListView.builder(
    padding: listPadding,
    physics: const AlwaysScrollableScrollPhysics(),
    shrinkWrap: false,
    itemCount: voters.length,
    itemBuilder: (context, index) {
      final username = voters[index];
      final userData = _userDataCache[username] ?? {};
      
      return VoterCard(
        username: username,
        userData: userData,
        screenWidth: screenWidth,
        communityId: widget.communityId,
        isVerySmall: _isVerySmall,
        isSmall: _isSmall,
        isTablet: _isTablet,
      );
    },
  );
}
  Widget _buildEmptyVoters(String option, double screenWidth, int optionIndex) {
  final duplicateCount = options.where((o) => o == option).length;
  String displayOption = option;
  if (duplicateCount > 1) {
    final duplicateIndex = options.take(optionIndex + 1).where((o) => o == option).length;
    displayOption = '$option (Option $duplicateIndex)';
  }

  // Adaptive sizing for landscape mode
  final iconSize = _isLandscape 
      ? (_isVerySmall ? 24.0 : (_isTablet ? 36.0 : 32.0))
      : (_isVerySmall ? 32.0 : (_isTablet ? 56.0 : 44.0));
  final containerPadding = _isLandscape 
      ? (_isVerySmall ? 8.0 : (_isTablet ? 16.0 : 12.0))
      : (_isVerySmall ? 12.0 : (_isTablet ? 24.0 : 16.0));
  final spacing = _isLandscape 
      ? (_isVerySmall ? 6.0 : (_isTablet ? 12.0 : 8.0))
      : (_isVerySmall ? 8.0 : (_isTablet ? 20.0 : 12.0));
  
  return CustomScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(containerPadding),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B).withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.how_to_vote_outlined,
                  color: const Color(0xFF64B5F6),
                  size: iconSize,
                ),
              ),
              SizedBox(height: spacing),
              Text(
                'No votes yet',
                style: GoogleFonts.poppins(
                  fontSize: _getResponsiveFontSize(
                    small: _isLandscape ? 12 : 14, 
                    medium: _isLandscape ? 14 : 16, 
                    large: _isLandscape ? 16 : 20
                  ),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: spacing / 2),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isLandscape 
                      ? (_isVerySmall ? 16.0 : (_isTablet ? 32.0 : 24.0))
                      : (_isVerySmall ? 20.0 : (_isTablet ? 48.0 : 32.0))
                ),
                child: Text(
                  'No one has voted for "$displayOption" yet',
                  style: GoogleFonts.poppins(
                    fontSize: _getResponsiveFontSize(
                      small: _isLandscape ? 8 : 10, 
                      medium: _isLandscape ? 11 : 13, 
                      large: _isLandscape ? 14 : 16
                    ),
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: _isLandscape ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
}

class VoterCard extends StatefulWidget {
  final String username;
  final Map<String, dynamic> userData;
  final double screenWidth;
  final String communityId;
  final bool isVerySmall;
  final bool isSmall;
  final bool isTablet;

  const VoterCard({
    Key? key,
    required this.username,
    required this.userData,
    required this.screenWidth,
    required this.communityId,
    required this.isVerySmall,
    required this.isSmall,
    required this.isTablet,
  }) : super(key: key);

  @override
  State<VoterCard> createState() => _VoterCardState();
}

class _VoterCardState extends State<VoterCard> {
  void _openUserProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          username: username,
          communityId: widget.communityId,
        ),
      ),
    );
  }

  double get _avatarSize {
    if (widget.isVerySmall) return 32;
    if (widget.isSmall) return 36;
    if (widget.isTablet) return 56;
    return 44;
  }

  double get _fontSize {
    if (widget.isVerySmall) return 11;
    if (widget.isSmall) return 12;
    if (widget.isTablet) return 17;
    return 14;
  }

  double get _smallFontSize {
    if (widget.isVerySmall) return 9;
    if (widget.isSmall) return 10;
    if (widget.isTablet) return 15;
    return 12;
  }

  double get _tagFontSize {
    if (widget.isVerySmall) return 7;
    if (widget.isSmall) return 8;
    if (widget.isTablet) return 12;
    return 10;
  }

  EdgeInsets get _cardPadding {
    if (widget.isVerySmall) return const EdgeInsets.all(8);
    if (widget.isSmall) return const EdgeInsets.all(10);
    if (widget.isTablet) return const EdgeInsets.all(20);
    return const EdgeInsets.all(14);
  }

  EdgeInsets get _cardMargin {
  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  if (isLandscape) {
    if (widget.isVerySmall) return const EdgeInsets.only(bottom: 4);
    if (widget.isSmall) return const EdgeInsets.only(bottom: 6);
    if (widget.isTablet) return const EdgeInsets.only(bottom: 12);
    return const EdgeInsets.only(bottom: 8);
  }
  if (widget.isVerySmall) return const EdgeInsets.only(bottom: 6);
  if (widget.isSmall) return const EdgeInsets.only(bottom: 8);
  if (widget.isTablet) return const EdgeInsets.only(bottom: 16);
  return const EdgeInsets.only(bottom: 12);
}

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userData['firstName'] ?? '';
    final lastName = widget.userData['lastName'] ?? '';
    final branch = widget.userData['branch'] ?? '';
    final year = widget.userData['year'] ?? '';
    final profileImageUrl = widget.userData['profileImageUrl'];
    final role = widget.userData['role'] ?? 'member';

    return Container(
      margin: _cardMargin,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(widget.isTablet ? 20 : (widget.isVerySmall ? 12 : 16)),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B263B).withOpacity(0.2),
            blurRadius: widget.isTablet ? 12 : (widget.isVerySmall ? 4 : 8),
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: _cardPadding,
        child: Row(
          children: [
            // Profile Avatar - Clickable
            GestureDetector(
              onTap: () => _openUserProfile(widget.username),
              child: Container(
                width: _avatarSize,
                height: _avatarSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                  ),
                  borderRadius: BorderRadius.circular(widget.isTablet ? 14 : (widget.isVerySmall ? 8 : 12)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.3),
                      blurRadius: widget.isVerySmall ? 4 : 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.isTablet ? 14 : (widget.isVerySmall ? 8 : 12)),
                  child: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? Image.network(
                          profileImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(firstName, lastName),
                        )
                      : _buildInitialAvatar(firstName, lastName),
                ),
              ),
            ),
            SizedBox(width: widget.isVerySmall ? 8 : (widget.isTablet ? 20 : 14)),
            
            // User Info - Enhanced responsive layout
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name and Role Row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openUserProfile(widget.username),
                          child: Text(
                            '$firstName $lastName'.trim().isNotEmpty 
                                ? '$firstName $lastName'.trim()
                                : '@${widget.username}',
                            style: GoogleFonts.poppins(
                              fontSize: _fontSize,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (role != 'member') ...[
                        SizedBox(width: widget.isVerySmall ? 4 : 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isVerySmall ? 3 : (widget.isTablet ? 8 : 6),
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: role == 'admin' 
                                  ? [Colors.amber, Colors.orange]
                                  : [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: widget.isVerySmall ? 6 : _tagFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  // Username (if name is provided)
                  if (firstName.isNotEmpty && lastName.isNotEmpty) ...[
                    SizedBox(height: widget.isVerySmall ? 2 : (widget.isTablet ? 4 : 2)),
                    GestureDetector(
                      onTap: () => _openUserProfile(widget.username),
                      child: Text(
                        '@${widget.username}',
                        style: GoogleFonts.poppins(
                          fontSize: _smallFontSize,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  
                  // Branch and Year Tags
                  if (branch.isNotEmpty || year.isNotEmpty) ...[
                    SizedBox(height: widget.isVerySmall ? 3 : (widget.isTablet ? 6 : 4)),
                    Wrap(
                      spacing: widget.isVerySmall ? 3 : 6,
                      runSpacing: 3,
                      children: [
                        if (branch.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isVerySmall ? 4 : (widget.isTablet ? 8 : 6),
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              branch.length > 8 && widget.isVerySmall 
                                  ? '${branch.substring(0, 6)}...'
                                  : branch,
                              style: GoogleFonts.poppins(
                                fontSize: _tagFontSize,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (year.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isVerySmall ? 4 : (widget.isTablet ? 8 : 6),
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$year',
                              style: GoogleFonts.poppins(
                                fontSize: _tagFontSize,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Vote indicator
            Container(
              padding: EdgeInsets.all(widget.isVerySmall ? 4 : (widget.isTablet ? 10 : 8)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: widget.isVerySmall ? 10 : (widget.isTablet ? 18 : 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAvatar(String firstName, String lastName) {
    String initials = '';
    if (firstName.isNotEmpty) initials += firstName[0];
    if (lastName.isNotEmpty) initials += lastName[0];
    if (initials.isEmpty) initials = widget.username[0].toUpperCase();

    return Center(
      child: Text(
        initials.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: widget.isVerySmall ? 12 : (widget.isTablet ? 20 : 16),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}