import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/committee_calendar_widget.dart';
import 'package:startup/home_components/committee_create_event.dart';

class CommitteeDetailPage extends StatefulWidget {
  final String committeeId;
  final String communityId;
  final String userId;
  final String username;
  final String userRole;

  const CommitteeDetailPage({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
  }) : super(key: key);

  @override
  State<CommitteeDetailPage> createState() => _CommitteeDetailPageState();
}

class _CommitteeDetailPageState extends State<CommitteeDetailPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  Map<String, dynamic>? _committeeData;
  bool _isLoading = true;
  bool _isCreator = false;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initAnimations();
    _loadCommitteeData();
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
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCommitteeData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _committeeData = data;
          _isCreator = data['creatorUsername'] == widget.username;
          final followers = List<String>.from(data['followers'] ?? []);
          _isFollowing = followers.contains(widget.username);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading committee data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final committeeRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId);

      if (_isFollowing) {
        await committeeRef.update({
          'followers': FieldValue.arrayRemove([widget.username]),
          'followerCount': FieldValue.increment(-1),
        });
      } else {
        await committeeRef.update({
          'followers': FieldValue.arrayUnion([widget.username]),
          'followerCount': FieldValue.increment(1),
        });
      }

      setState(() {
        _isFollowing = !_isFollowing;
        if (_committeeData != null) {
          final currentCount = _committeeData!['followerCount'] ?? 0;
          _committeeData!['followerCount'] = _isFollowing ? currentCount + 1 : currentCount - 1;
        }
      });
    } catch (e) {
      _showMessage('Error updating follow status: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E3A5F),
                const Color(0xFF0A1628),
                const Color(0xFF041018),
                Colors.black,
              ],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(color: const Color(0xFF4FC3F7)),
          ),
        ),
      );
    }

    if (_committeeData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1628),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E3A5F),
                const Color(0xFF0A1628),
                const Color(0xFF041018),
                Colors.black,
              ],
            ),
          ),
          child: Center(
            child: Text(
              'Committee not found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1E3A5F),
              const Color(0xFF0A1628),
              const Color(0xFF041018),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                _buildCommitteeInfo(),
                _buildTabBar(),
                Expanded(
                  child: _buildTabBarView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _committeeData!['name'] ?? 'Committee',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 18 : 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (!_isCreator)
                GestureDetector(
                  onTap: _toggleFollow,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16,
                      vertical: isCompact ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: _isFollowing 
                          ? LinearGradient(
                              colors: [Colors.red.shade400, Colors.red.shade600]
                            )
                          : LinearGradient(
                              colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)]
                            ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (_isFollowing ? Colors.red : const Color(0xFF29B6F6)).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _isFollowing ? 'Following' : 'Follow',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommitteeInfo() {
    final followerCount = _committeeData!['followerCount'] ?? 0;
    final departments = List<String>.from(_committeeData!['departments'] ?? []);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.3),
                const Color(0xFF0A1628).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1E3A5F).withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              if (_committeeData!['description'] != null) ...[
                Text(
                  _committeeData!['description'],
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 13 : 15,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: isCompact ? 12 : 16),
              ],

              // Stats
              Row(
                children: [
                  Icon(
                    Icons.people,
                    color: const Color(0xFF4FC3F7),
                    size: isCompact ? 16 : 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$followerCount follower${followerCount != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 12 : 14,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.category,
                    color: const Color(0xFF4FC3F7),
                    size: isCompact ? 16 : 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${departments.length} department${departments.length != 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 12 : 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),

              // Creator info
              if (_isCreator) ...[
                SizedBox(height: isCompact ? 8 : 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 8 : 12,
                    vertical: isCompact ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade600, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: isCompact ? 14 : 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'You are the creator',
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 10 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.3)),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 11 : 13
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 11 : 13
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Members'),
              Tab(text: 'Events'),
              Tab(text: 'Achievements'),
              Tab(text: 'Recruitment'),
              Tab(text: 'Calendar'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        CommitteeOverviewTab(
          committeeData: _committeeData!,
          isCreator: _isCreator,
          isCompact: MediaQuery.of(context).size.width < 400,
        ),
        CommitteeMembersTab(
          committeeId: widget.committeeId,
          communityId: widget.communityId,
          isCreator: _isCreator,
          username: widget.username,
          isCompact: MediaQuery.of(context).size.width < 400,
          onRefresh: _loadCommitteeData,
        ),
        CommitteeEventsTab(
          committeeId: widget.committeeId,
          communityId: widget.communityId,
          isCreator: _isCreator,
          username: widget.username,
          userId: widget.userId,
          isCompact: MediaQuery.of(context).size.width < 400,
        ),
        CommitteeAchievementsTab(
          committeeId: widget.committeeId,
          communityId: widget.communityId,
          isCreator: _isCreator,
          username: widget.username,
          isCompact: MediaQuery.of(context).size.width < 400,
          achievements: List<String>.from(_committeeData!['achievements'] ?? []),
          onRefresh: _loadCommitteeData,
        ),
        CommitteeRecruitmentTab(
          committeeId: widget.committeeId,
          communityId: widget.communityId,
          isCreator: _isCreator,
          username: widget.username,
          isCompact: MediaQuery.of(context).size.width < 400,
        ),
        CommitteeCalendarTab(
          committeeId: widget.committeeId,
          communityId: widget.communityId,
          username: widget.username,
          isCompact: MediaQuery.of(context).size.width < 400,
        ),
      ],
    );
  }
}

// Overview Tab
class CommitteeOverviewTab extends StatelessWidget {
  final Map<String, dynamic> committeeData;
  final bool isCreator;
  final bool isCompact;

  const CommitteeOverviewTab({
    Key? key,
    required this.committeeData,
    required this.isCreator,
    required this.isCompact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final departments = List<String>.from(committeeData['departments'] ?? []);
    final departmentLeaderTerms = List<String>.from(committeeData['departmentLeaderTerms'] ?? []);
    final overallLeaderTerm = committeeData['overallLeaderTerm'] ?? 'Leader';
    final achievements = List<String>.from(committeeData['achievements'] ?? []);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall Leader Term
          _buildInfoCard(
            'Overall Leader Position',
            overallLeaderTerm,
            Icons.person_pin_circle,
            isCompact,
          ),

          SizedBox(height: isCompact ? 16 : 20),

          // Departments
          _buildInfoCard(
            'Departments & Leadership',
            null,
            Icons.category,
            isCompact,
            child: Column(
              children: List.generate(departments.length, (index) {
                final dept = departments[index];
                final leaderTerm = index < departmentLeaderTerms.length 
                    ? departmentLeaderTerms[index] 
                    : 'Head';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isCompact ? 6 : 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: isCompact ? 10 : 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dept,
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 13 : 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Led by: $leaderTerm',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 10 : 12,
                                color: const Color(0xFF4FC3F7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),

          SizedBox(height: isCompact ? 16 : 20),

          // Achievements Preview
          if (achievements.isNotEmpty) ...[
            _buildInfoCard(
              'Recent Achievements',
              null,
              Icons.emoji_events,
              isCompact,
              child: Column(
                children: achievements.take(3).map((achievement) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.amber.withOpacity(0.1),
                        Colors.orange.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: isCompact ? 16 : 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          achievement,
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 12 : 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            SizedBox(height: isCompact ? 16 : 20),
          ],

          // Committee Stats
          _buildStatsCard(isCompact),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String? content, IconData icon, bool isCompact, {Widget? child}) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isCompact ? 16 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4FC3F7),
                  ),
                ),
              ),
            ],
          ),
          if (content != null) ...[
            SizedBox(height: isCompact ? 12 : 16),
            Text(
              content,
              style: GoogleFonts.poppins(
                fontSize: isCompact ? 13 : 15,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (child != null) ...[
            SizedBox(height: isCompact ? 12 : 16),
            child,
          ],
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4FC3F7).withOpacity(0.1),
            const Color(0xFF29B6F6).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4FC3F7).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: const Color(0xFF4FC3F7),
                size: isCompact ? 18 : 22,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Stats',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12 : 16),
          
          // Stats grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Followers', '${committeeData['followerCount'] ?? 0}', isCompact),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem('Departments', '${(committeeData['departments'] as List?)?.length ?? 0}', isCompact),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('Events', '0', isCompact), // This will be updated when events are loaded
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem('Achievements', '${(committeeData['achievements'] as List?)?.length ?? 0}', isCompact),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isCompact ? 18 : 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isCompact ? 10 : 12,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

// Members Tab
class CommitteeMembersTab extends StatefulWidget {
  final String committeeId;
  final String communityId;
  final bool isCreator;
  final String username;
  final bool isCompact;
  final VoidCallback onRefresh;

  const CommitteeMembersTab({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.isCreator,
    required this.username,
    required this.isCompact,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<CommitteeMembersTab> createState() => _CommitteeMembersTabState();
}

class _CommitteeMembersTabState extends State<CommitteeMembersTab> {
  Map<String, List<Map<String, dynamic>>> _departmentMembers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final departmentMembersData = Map<String, dynamic>.from(data['departmentMembers'] ?? {});
        
        final Map<String, List<Map<String, dynamic>>> processedMembers = {};
        for (String dept in departmentMembersData.keys) {
          final members = List<Map<String, dynamic>>.from(departmentMembersData[dept] ?? []);
          processedMembers[dept] = members;
        }

        setState(() {
          _departmentMembers = processedMembers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading members: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _editMembers() async {
    // Implementation for editing members
    _showMessage('Member editing functionality coming soon!');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF4FC3F7)),
      );
    }

    if (_departmentMembers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              color: const Color(0xFF4FC3F7),
              size: widget.isCompact ? 48 : 64,
            ),
            SizedBox(height: widget.isCompact ? 12 : 16),
            Text(
              'No members added yet',
              style: GoogleFonts.poppins(
                fontSize: widget.isCompact ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (widget.isCreator) ...[
              const SizedBox(height: 8),
              Text(
                'Add members to get started',
                style: GoogleFonts.poppins(
                  fontSize: widget.isCompact ? 12 : 14,
                  color: Colors.white60,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _editMembers,
                icon: const Icon(Icons.person_add),
                label: const Text('Add Members'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isCreator) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people_alt,
                    color: Colors.white,
                    size: widget.isCompact ? 20 : 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manage Committee Members',
                      style: GoogleFonts.poppins(
                        fontSize: widget.isCompact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _editMembers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4FC3F7),
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.isCompact ? 12 : 16,
                        vertical: widget.isCompact ? 6 : 8,
                      ),
                    ),
                    child: Text(
                      'Edit',
                      style: GoogleFonts.poppins(
                        fontSize: widget.isCompact ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: widget.isCompact ? 16 : 20),
          ],
          
          ..._departmentMembers.entries.map((entry) {
            final departmentName = entry.key;
            final members = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(widget.isCompact ? 8 : 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.group,
                          color: Colors.white,
                          size: widget.isCompact ? 16 : 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          departmentName,
                          style: GoogleFonts.poppins(
                            fontSize: widget.isCompact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isCompact ? 8 : 12,
                          vertical: widget.isCompact ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FC3F7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${members.length} member${members.length != 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: widget.isCompact ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4FC3F7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  if (members.isNotEmpty) ...[
                    SizedBox(height: widget.isCompact ? 12 : 16),
                    ...members.map((member) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: widget.isCompact ? 36 : 40,
                            height: widget.isCompact ? 36 : 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                (member['username'] ?? 'U')[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: widget.isCompact ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@${member['username'] ?? 'Unknown'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: widget.isCompact ? 13 : 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (member['name'] != null && member['name'].toString().isNotEmpty)
                                  Text(
                                    member['name'],
                                    style: GoogleFonts.poppins(
                                      fontSize: widget.isCompact ? 11 : 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (member['role'] != null && member['role'] != 'Member')
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.isCompact ? 6 : 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.purple.shade400, Colors.purple.shade600],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                member['role'],
                                style: GoogleFonts.poppins(
                                  fontSize: widget.isCompact ? 9 : 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    )).toList(),
                  ] else ...[
                    SizedBox(height: widget.isCompact ? 12 : 16),
                    Center(
                      child: Text(
                        'No members in this department',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 12 : 14,
                          color: Colors.white60,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// Events Tab
class CommitteeEventsTab extends StatefulWidget {
  final String committeeId;
  final String communityId;
  final bool isCreator;
  final String username;
  final String userId;
  final bool isCompact;

  const CommitteeEventsTab({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.isCreator,
    required this.username,
    required this.userId,
    required this.isCompact,
  }) : super(key: key);

  @override
  State<CommitteeEventsTab> createState() => _CommitteeEventsTabState();
}

class _CommitteeEventsTabState extends State<CommitteeEventsTab> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .collection('events')
          .orderBy('eventDateTime', descending: false)
          .get();

      final events = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        events.add({
          'id': doc.id,
          ...data,
        });
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading events: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createEvent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEventPage(
          committeeId: widget.committeeId,
          communityId: widget.communityId,
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );

    if (result == true) {
      _loadEvents();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF4FC3F7)),
      );
    }

    return Column(
      children: [
        if (widget.isCreator) ...[
          Container(
            margin: EdgeInsets.all(widget.isCompact ? 16 : 20),
            padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available,
                  color: Colors.white,
                  size: widget.isCompact ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Create Committee Events',
                    style: GoogleFonts.poppins(
                      fontSize: widget.isCompact ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4FC3F7),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isCompact ? 12 : 16,
                      vertical: widget.isCompact ? 6 : 8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Create',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        Expanded(
          child: _events.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_outlined,
                        color: const Color(0xFF4FC3F7),
                        size: widget.isCompact ? 48 : 64,
                      ),
                      SizedBox(height: widget.isCompact ? 12 : 16),
                      Text(
                        'No events yet',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isCreator 
                            ? 'Create your first event to get started'
                            : 'No events have been created yet',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 12 : 14,
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return EventCard(
                      event: event,
                      isCompact: widget.isCompact,
                      isCreator: widget.isCreator,
                      username: widget.username,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isCompact;
  final bool isCreator;
  final String username;

  const EventCard({
    Key? key,
    required this.event,
    required this.isCompact,
    required this.isCreator,
    required this.username,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventDate = (event['eventDateTime'] as Timestamp).toDate();
    final eventType = event['eventType'] ?? 'general';
    final isRegistrationRequired = event['requiresRegistration'] ?? false;
    final trackAttendance = event['trackAttendance'] ?? false;
    
    IconData getEventIcon() {
      switch (eventType) {
        case 'workshop': return Icons.work;
        case 'meeting': return Icons.people;
        case 'competition': return Icons.emoji_events;
        default: return Icons.event;
      }
    }

    Color getEventColor() {
      switch (eventType) {
        case 'workshop': return Colors.orange;
        case 'meeting': return Colors.blue;
        case 'competition': return Colors.amber;
        default: return const Color(0xFF4FC3F7);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            getEventColor().withOpacity(0.1),
            getEventColor().withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: getEventColor().withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 8 : 10),
                  decoration: BoxDecoration(
                    color: getEventColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getEventIcon(),
                    color: getEventColor(),
                    size: isCompact ? 16 : 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event['title'] ?? 'Untitled Event',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 15 : 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 6 : 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: getEventColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    eventType.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 9 : 10,
                      fontWeight: FontWeight.w600,
                      color: getEventColor(),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: isCompact ? 8 : 12),

            if (event['description'] != null) ...[
              Text(
                event['description'],
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 12 : 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isCompact ? 8 : 12),
            ],

            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: getEventColor(),
                  size: isCompact ? 14 : 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 11 : 13,
                    color: getEventColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  color: getEventColor(),
                  size: isCompact ? 14 : 16,
                ),
                const SizedBox(width: 4),
                Text(
                  TimeOfDay.fromDateTime(eventDate).format(context),
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 11 : 13,
                    color: getEventColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            SizedBox(height: isCompact ? 6 : 8),

            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: getEventColor(),
                  size: isCompact ? 14 : 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    event['location'] ?? 'TBA',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 11 : 13,
                      color: getEventColor(),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (isRegistrationRequired || trackAttendance) ...[
              SizedBox(height: isCompact ? 8 : 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (isRegistrationRequired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.app_registration,
                            color: Colors.green,
                            size: isCompact ? 12 : 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Registration Required',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 9 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (trackAttendance)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fact_check,
                            color: Colors.blue,
                            size: isCompact ? 12 : 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Attendance Tracked',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 9 : 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Achievements Tab
class CommitteeAchievementsTab extends StatefulWidget {
  final String committeeId;
  final String communityId;
  final bool isCreator;
  final String username;
  final bool isCompact;
  final List<String> achievements;
  final VoidCallback onRefresh;

  const CommitteeAchievementsTab({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.isCreator,
    required this.username,
    required this.isCompact,
    required this.achievements,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<CommitteeAchievementsTab> createState() => _CommitteeAchievementsTabState();
}

class _CommitteeAchievementsTabState extends State<CommitteeAchievementsTab> {
  final TextEditingController _achievementController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _achievementController.dispose();
    super.dispose();
  }

  Future<void> _addAchievement() async {
    final achievement = _achievementController.text.trim();
    if (achievement.isEmpty) return;

    setState(() {
      _isAdding = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .update({
        'achievements': FieldValue.arrayUnion([achievement]),
      });

      _achievementController.clear();
      widget.onRefresh();
      _showMessage('Achievement added successfully!');
    } catch (e) {
      _showMessage('Error adding achievement: $e', isError: true);
    } finally {
      setState(() {
        _isAdding = false;
      });
    }
  }

  Future<void> _removeAchievement(String achievement) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .update({
        'achievements': FieldValue.arrayRemove([achievement]),
      });

      widget.onRefresh();
      _showMessage('Achievement removed successfully!');
    } catch (e) {
      _showMessage('Error removing achievement: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isCreator) ...[
          Container(
            margin: EdgeInsets.all(widget.isCompact ? 16 : 20),
            padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.withOpacity(0.1), Colors.orange.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: widget.isCompact ? 20 : 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add New Achievement',
                      style: GoogleFonts.poppins(
                        fontSize: widget.isCompact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isCompact ? 12 : 16),
                TextField(
                  controller: _achievementController,
                  maxLines: 2,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: widget.isCompact ? 12 : 14,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    hintText: 'Describe the achievement...',
                    hintStyle: GoogleFonts.poppins(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                    ),
                    contentPadding: EdgeInsets.all(widget.isCompact ? 12 : 16),
                  ),
                ),
                SizedBox(height: widget.isCompact ? 12 : 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAdding ? null : _addAchievement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 12 : 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAdding
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black87,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Add Achievement',
                            style: GoogleFonts.poppins(
                              fontSize: widget.isCompact ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],

        Expanded(
          child: widget.achievements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_outlined,
                        color: const Color(0xFF4FC3F7),
                        size: widget.isCompact ? 48 : 64,
                      ),
                      SizedBox(height: widget.isCompact ? 12 : 16),
                      Text(
                        'No achievements yet',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isCreator
                            ? 'Add your committee\'s first achievement'
                            : 'No achievements have been added yet',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 12 : 14,
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    widget.isCompact ? 16 : 20,
                    0,
                    widget.isCompact ? 16 : 20,
                    widget.isCompact ? 16 : 20,
                  ),
                  itemCount: widget.achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = widget.achievements[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.1),
                            Colors.orange.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(widget.isCompact ? 8 : 10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: widget.isCompact ? 20 : 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              achievement,
                              style: GoogleFonts.poppins(
                                fontSize: widget.isCompact ? 13 : 15,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                          ),
                          if (widget.isCreator) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _removeAchievement(achievement),
                              child: Container(
                                padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: widget.isCompact ? 16 : 18,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// Recruitment Tab
class CommitteeRecruitmentTab extends StatefulWidget {
  final String committeeId;
  final String communityId;
  final bool isCreator;
  final String username;
  final bool isCompact;

  const CommitteeRecruitmentTab({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.isCreator,
    required this.username,
    required this.isCompact,
  }) : super(key: key);

  @override
  State<CommitteeRecruitmentTab> createState() => _CommitteeRecruitmentTabState();
}

class _CommitteeRecruitmentTabState extends State<CommitteeRecruitmentTab> {
  List<Map<String, dynamic>> _recruitments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecruitments();
  }

  Future<void> _loadRecruitments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .collection('recruitments')
          .orderBy('createdAt', descending: true)
          .get();

      final recruitments = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        recruitments.add({
          'id': doc.id,
          ...data,
        });
      }

      setState(() {
        _recruitments = recruitments;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading recruitments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createRecruitment() async {
    // Implementation for creating recruitment posts
    _showMessage('Recruitment creation functionality coming soon!');
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF4FC3F7)),
      );
    }

    return Column(
      children: [
        if (widget.isCreator) ...[
          Container(
            margin: EdgeInsets.all(widget.isCompact ? 16 : 20),
            padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.withOpacity(0.1), Colors.teal.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_add,
                  color: Colors.green,
                  size: widget.isCompact ? 20 : 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Post Recruitment Announcements',
                    style: GoogleFonts.poppins(
                      fontSize: widget.isCompact ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _createRecruitment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isCompact ? 12 : 16,
                      vertical: widget.isCompact ? 6 : 8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Post',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        Expanded(
          child: _recruitments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        color: const Color(0xFF4FC3F7),
                        size: widget.isCompact ? 48 : 64,
                      ),
                      SizedBox(height: widget.isCompact ? 12 : 16),
                      Text(
                        'No recruitment posts',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.isCreator
                            ? 'Post recruitment announcements to find new members'
                            : 'No recruitment announcements have been posted yet',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 12 : 14,
                          color: Colors.white60,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
                  itemCount: _recruitments.length,
                  itemBuilder: (context, index) {
                    final recruitment = _recruitments[index];
                    return RecruitmentCard(
                      recruitment: recruitment,
                      isCompact: widget.isCompact,
                      isCreator: widget.isCreator,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class RecruitmentCard extends StatelessWidget {
  final Map<String, dynamic> recruitment;
  final bool isCompact;
  final bool isCreator;

  const RecruitmentCard({
    Key? key,
    required this.recruitment,
    required this.isCompact,
    required this.isCreator,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final deadline = recruitment['deadline'] as Timestamp?;
    final departments = List<String>.from(recruitment['departments'] ?? []);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.1),
            Colors.teal.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.work_outline,
                  color: Colors.green,
                  size: isCompact ? 16 : 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  recruitment['title'] ?? 'Recruitment Post',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 15 : 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isCompact ? 8 : 12),

          if (recruitment['description'] != null) ...[
            Text(
              recruitment['description'],
              style: GoogleFonts.poppins(
                fontSize: isCompact ? 12 : 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
            SizedBox(height: isCompact ? 8 : 12),
          ],

          if (departments.isNotEmpty) ...[
            Text(
              'Recruiting for:',
              style: GoogleFonts.poppins(
                fontSize: isCompact ? 11 : 13,
                color: Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: departments.map((dept) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dept,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 9 : 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              )).toList(),
            ),
            SizedBox(height: isCompact ? 8 : 12),
          ],

          if (deadline != null) ...[
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: Colors.orange,
                  size: isCompact ? 14 : 16,
                ),
                const SizedBox(width: 4),
                Text(
                  'Deadline: ${deadline.toDate().day}/${deadline.toDate().month}/${deadline.toDate().year}',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 11 : 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Calendar Tab
class CommitteeCalendarTab extends StatelessWidget {
  final String committeeId;
  final String communityId;
  final String username;
  final bool isCompact;

  const CommitteeCalendarTab({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.username,
    required this.isCompact,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CommitteeCalendar(
      committeeId: committeeId,
      communityId: communityId,
      isCompact: isCompact,
    );
  }
}