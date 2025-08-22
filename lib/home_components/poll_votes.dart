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
            
            // Check if options changed
            if (newOptions.length != options.length) {
              options = newOptions;
              _initTabController(); // Reinitialize TabController with new length
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
    
    // Process votes by option index - handle duplicates properly
    for (int i = 0; i < options.length; i++) {
      final optionKey = 'option_$i';
      final voters = votes[optionKey];
      if (voters is List) {
        // Use a unique key that combines option text and index for duplicates
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
    // Create unique keys for duplicate options
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
      
      // Process votes by option index
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

      // Preload user data for all voters
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
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
            child: Column(
              children: [
                _buildHeader(screenWidth, isTablet),
                _buildPollSummary(totalVotes, optionCounts, screenWidth, isTablet),
                if (_tabController != null && options.isNotEmpty) ...[
                  _buildTabBar(screenWidth, isTablet),
                  Expanded(
                    child: _buildTabBarView(screenWidth, isTablet),
                  ),
                ] else ...[
                  Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF64B5F6),
                        strokeWidth: isTablet ? 4 : 3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double screenWidth, bool isTablet) {
  final isCompact = screenWidth < 350;

  return Container(
    padding: EdgeInsets.all(isTablet ? 24 : (isCompact ? 16 : 20)),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1B263B).withOpacity(0.3),
          Colors.transparent,
        ],
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 10 : (isCompact ? 8 : 8)),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
              border: Border.all(
                color: const Color(0xFF64B5F6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: isTablet ? 22 : (isCompact ? 18 : 18),
            ),
          ),
        ),
        Container(
          margin: EdgeInsets.only(left: 15),
          padding: EdgeInsets.all(isTablet ? 16 : (isCompact ? 10 : 12)),
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
            size: isTablet ? 28 : (isCompact ? 20 : 24),
          ),
        ),
        SizedBox(width: isTablet ? 20 : (isCompact ? 12 : 16)),
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
                    fontSize: isTablet ? 28 : (isCompact ? 18 : 22),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5
                  ),
                ),
              ),
              Text(
                'see who voted for what',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : (isCompact ? 10 : 12),
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
  Widget _buildPollSummary(int totalVotes, List<int> optionCounts, double screenWidth, bool isTablet) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 12 : 8,
      ),
      padding: EdgeInsets.all(isTablet ? 20 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B263B).withOpacity(0.2),
            const Color(0xFF0D1B2A).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
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
              fontSize: isTablet ? 18 : (screenWidth < 350 ? 13 : 15),
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 8, 
                  vertical: isTablet ? 6 : 4
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
                    fontSize: isTablet ? 14 : (screenWidth < 350 ? 10 : 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 12 : 8, 
                  vertical: isTablet ? 6 : 4
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Options: ${options.length}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: isTablet ? 14 : (screenWidth < 350 ? 10 : 12),
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

  Widget _buildTabBar(double screenWidth, bool isTablet) {
    if (_tabController == null || options.isEmpty) {
      return const SizedBox.shrink();
    }

    final tabCount = options.length;
    final targetVisibleTabs = isTablet ? 6 : 4;
    final shouldScroll = tabCount > targetVisibleTabs;
    
    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : 16),
      height: isTablet ? 60 : 50,
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
                fontSize: isTablet ? 13 : (screenWidth < 350 ? 9 : 11)
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w500, 
                fontSize: isTablet ? 13 : (screenWidth < 350 ? 9 : 11)
              ),
              dividerColor: Colors.transparent,
              tabs: options.asMap().entries.map((entry) {
                final index = entry.key;
                final option = entry.value;
                final count = index < _currentPollData['optionCounts'].length 
                    ? _currentPollData['optionCounts'][index] 
                    : 0;
                
                final availableWidth = screenWidth - (isTablet ? 48 : 32);
                final tabWidth = shouldScroll 
                    ? (availableWidth / targetVisibleTabs) - 8
                    : (availableWidth / tabCount) - 4;
                
                final maxLength = (tabWidth / (isTablet ? 12 : 8)).floor().clamp(6, 20);
                
                // Handle duplicate options in tab display
                String displayText = option.length > maxLength 
                    ? '${option.substring(0, maxLength)}...' 
                    : option;
                
                // Add option number for duplicates
                final duplicateCount = options.where((o) => o == option).length;
                if (duplicateCount > 1) {
                  final duplicateIndex = options.take(index + 1).where((o) => o == option).length;
                  displayText = '$displayText ($duplicateIndex)';
                  if (displayText.length > maxLength) {
                    displayText = '${displayText.substring(0, maxLength)}...';
                  }
                }
                
                return Tab(
                  child: Container(
                    width: shouldScroll ? tabWidth : null,
                    constraints: BoxConstraints(
                      minWidth: isTablet ? 100 : 70,
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
                        SizedBox(height: isTablet ? 4 : 2),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 6 : 4, 
                            vertical: 1
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 11 : (screenWidth < 350 ? 8 : 9),
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

  Widget _buildTabBarView(double screenWidth, bool isTablet) {
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
              strokeWidth: isTablet ? 4 : 3,
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
                return _buildVotersList(option, voters, screenWidth, isTablet, index);
              }).toList(),
            );
          },
        );
      },
    );
  }

  Widget _buildVotersList(String option, List<String> voters, double screenWidth, bool isTablet, int optionIndex) {
    if (voters.isEmpty) {
      return _buildEmptyVoters(option, screenWidth, isTablet, optionIndex);
    }

    return ListView.builder(
      padding: EdgeInsets.all(isTablet ? 24 : 16),
      itemCount: voters.length,
      itemBuilder: (context, index) {
        final username = voters[index];
        final userData = _userDataCache[username] ?? {};
        
        return VoterCard(
          username: username,
          userData: userData,
          screenWidth: screenWidth,
          isTablet: isTablet,
          communityId: widget.communityId,
        );
      },
    );
  }

  Widget _buildEmptyVoters(String option, double screenWidth, bool isTablet, int optionIndex) {
    // Show option number for duplicates
    final duplicateCount = options.where((o) => o == option).length;
    String displayOption = option;
    if (duplicateCount > 1) {
      final duplicateIndex = options.take(optionIndex + 1).where((o) => o == option).length;
      displayOption = '$option (Option $duplicateIndex)';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B263B).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.how_to_vote_outlined,
              color: const Color(0xFF64B5F6),
              size: isTablet ? 56 : (screenWidth < 350 ? 36 : 44),
            ),
          ),
          SizedBox(height: isTablet ? 20 : 12),
          Text(
            'No votes yet',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 20 : (screenWidth < 350 ? 14 : 16),
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isTablet ? 12 : 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 48 : 32),
            child: Text(
              'No one has voted for "$displayOption" yet',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 16 : (screenWidth < 350 ? 11 : 13),
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class VoterCard extends StatefulWidget {
  final String username;
  final Map<String, dynamic> userData;
  final double screenWidth;
  final bool isTablet;
  final String communityId;

  const VoterCard({
    Key? key,
    required this.username,
    required this.userData,
    required this.screenWidth,
    required this.isTablet,
    required this.communityId
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

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userData['firstName'] ?? '';
    final lastName = widget.userData['lastName'] ?? '';
    final branch = widget.userData['branch'] ?? '';
    final year = widget.userData['year'] ?? '';
    final profileImageUrl = widget.userData['profileImageUrl'];
    final role = widget.userData['role'] ?? 'member';
    final isCompact = widget.screenWidth < 350;

    return Container(
      margin: EdgeInsets.only(bottom: widget.isTablet ? 16 : (isCompact ? 8 : 12)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(widget.isTablet ? 20 : (isCompact ? 12 : 16)),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B263B).withOpacity(0.2),
            blurRadius: widget.isTablet ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.isTablet ? 20 : (isCompact ? 10 : 14)),
        child: Row(
          children: [
            // Profile Avatar - MAKE IT CLICKABLE
            GestureDetector(
              onTap: () => _openUserProfile(widget.username),
              child: Container(
                width: widget.isTablet ? 56 : (isCompact ? 36 : 44),
                height: widget.isTablet ? 56 : (isCompact ? 36 : 44),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                  ),
                  borderRadius: BorderRadius.circular(widget.isTablet ? 14 : (isCompact ? 8 : 12)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.isTablet ? 14 : (isCompact ? 8 : 12)),
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
            SizedBox(width: widget.isTablet ? 20 : (isCompact ? 10 : 14)),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              fontSize: widget.isTablet ? 17 : (isCompact ? 12 : 14),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      if (role != 'member') 
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 8 : (isCompact ? 4 : 6),
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
                              fontSize: widget.isTablet ? 10 : (isCompact ? 7 : 8),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  
                  if (firstName.isNotEmpty && lastName.isNotEmpty) ...[
                    SizedBox(height: widget.isTablet ? 4 : 2),
                    GestureDetector(
                      onTap: () => _openUserProfile(widget.username),
                      child: Text(
                        '@${widget.username}',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isTablet ? 15 : (isCompact ? 10 : 12),
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  
                  if (branch.isNotEmpty || year.isNotEmpty) ...[
                    SizedBox(height: widget.isTablet ? 6 : 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (branch.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isTablet ? 8 : (isCompact ? 4 : 6),
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              branch,
                              style: GoogleFonts.poppins(
                                fontSize: widget.isTablet ? 12 : (isCompact ? 8 : 10),
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (year.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isTablet ? 8 : (isCompact ? 4 : 6),
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$year',
                              style: GoogleFonts.poppins(
                                fontSize: widget.isTablet ? 12 : (isCompact ? 8 : 10),
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
              padding: EdgeInsets.all(widget.isTablet ? 10 : (isCompact ? 6 : 8)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: widget.isTablet ? 18 : (isCompact ? 12 : 14),
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
          fontSize: widget.isTablet ? 20 : (widget.screenWidth < 350 ? 14 : 16),
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}