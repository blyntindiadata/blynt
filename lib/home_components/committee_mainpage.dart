import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/committee_details.dart';
import 'package:startup/home_components/committee_request.dart';

class CommitteesPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const CommitteesPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  }) : super(key: key);

  @override
  State<CommitteesPage> createState() => _CommitteesPageState();
}

class _CommitteesPageState extends State<CommitteesPage> with TickerProviderStateMixin {
  final ValueNotifier<List<Map<String, dynamic>>> _committeesNotifier = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> _requestsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isSearching = false;
  String _searchQuery = '';
  final Map<String, Map<String, dynamic>?> _userCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.userRole == 'admin' ? 3 : 2, 
      vsync: this
    );
    _initAnimations();
    _loadCommittees();
    if (widget.userRole == 'admin') {
      _loadRequests();
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
    _fadeController.forward();
  }

  @override
  void dispose() {
    _committeesNotifier.dispose();
    _requestsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _searchController.dispose();
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCommittees() async {
    try {
      _isLoadingNotifier.value = true;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .where('status', isEqualTo: 'approved')
          // .orderBy('createdAt', descending: true)
          .get();

      final committees = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final committeeData = {
          'id': doc.id,
          ...data,
        };
        committees.add(committeeData);
      }

      _committeesNotifier.value = committees;
    } catch (e) {
      print('Error loading committees: $e');
      if (mounted) {
        _showMessage('Error loading committees: $e', isError: true);
      }
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  Future<void> _loadRequests() async {
    if (widget.userRole != 'admin') return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committee_requests')
          .where('status', isEqualTo: 'pending')
          // .orderBy('createdAt', descending: true)
          .get();

      final requests = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final requestData = {
          'id': doc.id,
          ...data,
        };
        requests.add(requestData);
      }

      _requestsNotifier.value = requests;
    } catch (e) {
      print('Error loading requests: $e');
    }
  }

  Future<void> _approveRequest(String requestId) async {
    try {
      final requestDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committee_requests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) return;

      final requestData = requestDoc.data()!;
      
      // Create the committee
      final committeeRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc();

      final committeeData = {
        ...requestData,
        'id': committeeRef.id,
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': widget.username,
        'followerCount': 0,
        'followers': <String>[],
      };

      await committeeRef.set(committeeData);

      // Update request status
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committee_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': widget.username,
        'committeeId': committeeRef.id,
      });

      _showMessage('Committee approved successfully!');
      _loadCommittees();
      _loadRequests();
    } catch (e) {
      _showMessage('Error approving committee: $e', isError: true);
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committee_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': widget.username,
      });

      _showMessage('Committee request rejected');
      _loadRequests();
    } catch (e) {
      _showMessage('Error rejecting request: $e', isError: true);
    }
  }

  Future<void> _followCommittee(String committeeId, bool isFollowing) async {
    try {
      final committeeRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(committeeId);

      if (isFollowing) {
        // Unfollow
        await committeeRef.update({
          'followers': FieldValue.arrayRemove([widget.username]),
          'followerCount': FieldValue.increment(-1),
        });
      } else {
        // Follow
        await committeeRef.update({
          'followers': FieldValue.arrayUnion([widget.username]),
          'followerCount': FieldValue.increment(1),
        });
      }

      _loadCommittees();
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
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildTabBarView(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildCreateFAB(),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.fromLTRB(
            isCompact ? 16 : 20, 
            isCompact ? 16 : 20, 
            isCompact ? 16 : 20, 
            isCompact ? 12 : 16
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: EdgeInsets.all(isCompact ? 10 : 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF1E3A5F), const Color(0xFF0A1628)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A5F).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.groups, 
                      color: Colors.white, 
                      size: isCompact ? 20 : 24
                    ),
                  ),
                  SizedBox(width: isCompact ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)],
                          ).createShader(bounds),
                          child: Text(
                            'committees',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: isCompact ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5
                            ),
                          ),
                        ),
                        Text(
                          'organize & participate',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 10 : 12,
                            color: const Color(0xFF4FC3F7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh, 
                      color: const Color(0xFF4FC3F7),
                      size: isCompact ? 20 : 24,
                    ),
                    onPressed: () {
                      _loadCommittees();
                      if (widget.userRole == 'admin') {
                        _loadRequests();
                      }
                    },
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 12 : 16),
              _buildSearchBar(isCompact),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(bool isCompact) {
    return Container(
      height: isCompact ? 40 : 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(
          color: Colors.white, 
          fontSize: isCompact ? 12 : 14
        ),
        textAlignVertical: TextAlignVertical.top,
        decoration: InputDecoration(
          hintText: 'Search committees...',
          hintStyle: GoogleFonts.poppins(color: Colors.white38), 
          prefixIcon: Icon(
            Icons.search, 
            color: const Color(0xFF4FC3F7), 
            size: isCompact ? 18 : 20
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 20, 
            vertical: isCompact ? 6 : 12
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
            _isSearching = value.isNotEmpty;
          });
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 20, 
            vertical: isCompact ? 8 : 10
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFF1E3A5F).withOpacity(0.3)),
          ),
          child: TabBar(
            controller: _tabController,
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
              fontSize: isCompact ? 12 : 14
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 12 : 14
            ),
            dividerColor: Colors.transparent,
            tabs: [
              const Tab(text: 'All'),
              const Tab(text: 'Following'),
              if (widget.userRole == 'admin') const Tab(text: 'Requests'),
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
        _buildCommitteesList(false), // All committees
        _buildCommitteesList(true),  // Following
        if (widget.userRole == 'admin') _buildRequestsList(),
      ],
    );
  }

  Widget _buildCommitteesList(bool followingOnly) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(color: const Color(0xFF4FC3F7)),
          );
        }

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _committeesNotifier,
          builder: (context, committees, child) {
            var visibleCommittees = committees;

            if (followingOnly) {
              visibleCommittees = committees.where((committee) {
                final followers = List<String>.from(committee['followers'] ?? []);
                return followers.contains(widget.username);
              }).toList();
            }

            if (_isSearching) {
              visibleCommittees = visibleCommittees.where((committee) {
                final name = (committee['name'] ?? '').toString().toLowerCase();
                final description = (committee['description'] ?? '').toString().toLowerCase();
                
                return name.contains(_searchQuery) ||
                       description.contains(_searchQuery);
              }).toList();
            }

            if (visibleCommittees.isEmpty) {
              return _buildEmptyState(followingOnly);
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return ListView.builder(
                  padding: EdgeInsets.all(constraints.maxWidth < 400 ? 12 : 16),
                  itemCount: visibleCommittees.length,
                  itemBuilder: (context, index) {
                    final committee = visibleCommittees[index];
                    return CommitteeCard(
                      committee: committee,
                      currentUsername: widget.username,
                      onFollow: (isFollowing) => _followCommittee(
                        committee['id'], 
                        isFollowing
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommitteeDetailPage(
                            committeeId: committee['id'],
                            communityId: widget.communityId,
                            userId: widget.userId,
                            username: widget.username,
                            userRole: widget.userRole,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsList() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: _requestsNotifier,
      builder: (context, requests, child) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined, 
                  color: const Color(0xFF4FC3F7), 
                  size: 64
                ),
                const SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return ListView.builder(
              padding: EdgeInsets.all(constraints.maxWidth < 400 ? 12 : 16),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return RequestCard(
                  request: request,
                  onApprove: () => _approveRequest(request['id']),
                  onReject: () => _rejectRequest(request['id']),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool followingOnly) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                followingOnly ? Icons.favorite_border : Icons.groups_outlined, 
                color: const Color(0xFF4FC3F7), 
                size: isCompact ? 48 : 64
              ),
              SizedBox(height: isCompact ? 12 : 16),
              Text(
                followingOnly ? 'No committees followed' : 'No committees available',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 16 : 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                followingOnly 
                    ? 'Start following committees to see them here!'
                    : 'Be the first to create a committee!',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 12 : 14, 
                  color: Colors.white60
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateFAB() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = MediaQuery.of(context).size.width < 400;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF29B6F6).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreateCommitteeRequestPage(
                    communityId: widget.communityId,
                    userId: widget.userId,
                    username: widget.username,
                    userRole: widget.userRole,
                  ),
                ),
              );
              if (result == true) {
                _loadCommittees();
                if (widget.userRole == 'admin') {
                  _loadRequests();
                }
              }
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: Text(
              'create committee',
              style: GoogleFonts.poppins(
                fontSize: isCompact ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            icon: Icon(
              Icons.add,
              color: Colors.white,
              size: isCompact ? 18 : 20,
            ),
          ),
        );
      },
    );
  }
}

class CommitteeCard extends StatelessWidget {
  final Map<String, dynamic> committee;
  final String currentUsername;
  final Function(bool) onFollow;
  final VoidCallback onTap;

  const CommitteeCard({
    Key? key,
    required this.committee,
    required this.currentUsername,
    required this.onFollow,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final followers = List<String>.from(committee['followers'] ?? []);
    final isFollowing = followers.contains(currentUsername);
    final followerCount = committee['followerCount'] ?? 0;
    final departments = List<String>.from(committee['departments'] ?? []);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.only(bottom: isCompact ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.2),
                const Color(0xFF0A1628).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1E3A5F).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: isCompact ? 6 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with name and follow button
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
                            Icons.groups,
                            color: Colors.white,
                            size: isCompact ? 16 : 20,
                          ),
                        ),
                        SizedBox(width: isCompact ? 8 : 12),
                        Expanded(
                          child: Text(
                            committee['name'] ?? 'Unnamed Committee',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onFollow(isFollowing),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 8 : 12,
                              vertical: isCompact ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: isFollowing 
                                  ? LinearGradient(
                                      colors: [Colors.red.shade400, Colors.red.shade600]
                                    )
                                  : LinearGradient(
                                      colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)]
                                    ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 10 : 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isCompact ? 8 : 12),

                    // Description
                    if (committee['description'] != null) ...[
                      Text(
                        committee['description'],
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 12 : 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isCompact ? 8 : 12),
                    ],

                    // Departments
                    if (departments.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: departments.take(3).map((dept) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 6 : 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4FC3F7).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4FC3F7).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            dept,
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 9 : 10,
                              color: const Color(0xFF4FC3F7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                      ),
                      if (departments.length > 3)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 6 : 8,
                            vertical: 2,
                          ),
                          child: Text(
                            '+${departments.length - 3} more',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 9 : 10,
                              color: Colors.white60,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      SizedBox(height: isCompact ? 8 : 12),
                    ],

                    // Footer with stats
                    Row(
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.white60,
                          size: isCompact ? 14 : 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$followerCount follower${followerCount != 1 ? 's' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 10 : 12,
                            color: Colors.white60,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Tap to view details',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 9 : 11,
                            color: const Color(0xFF4FC3F7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const RequestCard({
    Key? key,
    required this.request,
    required this.onApprove,
    required this.onReject,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final departments = List<String>.from(request['departments'] ?? []);
    final createdAt = request['createdAt'] as Timestamp?;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.only(bottom: isCompact ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.orange.withOpacity(0.1),
                Colors.amber.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: isCompact ? 6 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isCompact ? 8 : 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange, Colors.amber],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.pending_actions,
                        color: Colors.white,
                        size: isCompact ? 16 : 20,
                      ),
                    ),
                    SizedBox(width: isCompact ? 8 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request['name'] ?? 'Unnamed Committee',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 16 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Requested by @${request['creatorUsername'] ?? 'Unknown'}',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 10 : 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isCompact ? 12 : 16),

                // Description
                if (request['description'] != null) ...[
                  Text(
                    request['description'],
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 12 : 14,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isCompact ? 8 : 12),
                ],

                // Departments
                if (departments.isNotEmpty) ...[
                  Text(
                    'Departments:',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 11 : 13,
                      color: Colors.white60,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: departments.map((dept) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 6 : 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        dept,
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 9 : 10,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )).toList(),
                  ),
                  SizedBox(height: isCompact ? 12 : 16),
                ],

                // Action buttons
                Row(
                  children: [
                    if (createdAt != null) ...[
                      Expanded(
                        child: Text(
                          'Requested ${_formatTimestamp(createdAt)}',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 9 : 11,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                    TextButton.icon(
                      onPressed: onReject,
                      icon: Icon(
                        Icons.close,
                        color: Colors.red,
                        size: isCompact ? 14 : 16,
                      ),
                      label: Text(
                        'Reject',
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 11 : 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onApprove,
                      icon: Icon(
                        Icons.check,
                        color: Colors.green,
                        size: isCompact ? 14 : 16,
                      ),
                      label: Text(
                        'Approve',
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 11 : 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}