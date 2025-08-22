import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/polloptionwidget.dart';

class PollDisplayWidget extends StatefulWidget {
  final Map<String, dynamic> poll;
  final String communityId;
  final String userId;
  final String username;
  final Function(String) onViewVotes;

  const PollDisplayWidget({
    Key? key,
    required this.poll,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.onViewVotes,
  }) : super(key: key);

  @override
  State<PollDisplayWidget> createState() => _PollDisplayWidgetState();
}

class _PollDisplayWidgetState extends State<PollDisplayWidget> {
  late Stream<DocumentSnapshot> _pollStream;
  Map<String, dynamic> _currentPollData = {};
  String? _userVote;

  @override
  void initState() {
    super.initState();
    _currentPollData = Map<String, dynamic>.from(widget.poll);
    _initRealTimeListener();
    _checkUserVote();
  }

  void _initRealTimeListener() {
    final pollId = widget.poll['id'] ?? widget.poll['pollId'];
    
    if (pollId != null) {
      _pollStream = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('polls')
          .doc(pollId)
          .snapshots();
      
      _pollStream.listen((snapshot) {
        if (snapshot.exists && mounted) {
          final updatedData = snapshot.data() as Map<String, dynamic>;
          setState(() {
            _currentPollData = {
              'id': pollId,
              ...updatedData,
            };
          });
          _checkUserVote();
        }
      });
    }
  }

  void _checkUserVote() {
    final votes = Map<String, dynamic>.from(_currentPollData['votes'] ?? {});
    _userVote = null;
    
    for (int i = 0; i < (_currentPollData['options']?.length ?? 0); i++) {
      final optionKey = 'option_$i';
      if (votes[optionKey] is List) {
        final voters = List<String>.from(votes[optionKey]);
        if (voters.contains(widget.username)) {
          _userVote = optionKey;
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isCompact = screenWidth < 350;
    
    final options = List<String>.from(_currentPollData['options'] ?? []);
    final optionCounts = List<int>.from(_currentPollData['optionCounts'] ?? []);
    final totalVotes = _currentPollData['totalVotes'] ?? 0;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : (isCompact ? 12 : 16),
        vertical: isTablet ? 16 : (isCompact ? 8 : 12),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B263B).withOpacity(0.3),
            const Color(0xFF0D1B2A).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 24 : (isCompact ? 16 : 20)),
        border: Border.all(
          color: const Color(0xFF1B263B).withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B263B).withOpacity(0.3),
            blurRadius: isTablet ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : (isCompact ? 16 : 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPollHeader(isTablet, isCompact, totalVotes),
            SizedBox(height: isTablet ? 24 : (isCompact ? 16 : 20)),
            _buildPollQuestion(isTablet, isCompact),
            SizedBox(height: isTablet ? 24 : (isCompact ? 16 : 20)),
            _buildPollOptions(isTablet, isCompact, options, optionCounts, totalVotes),
            SizedBox(height: isTablet ? 20 : (isCompact ? 12 : 16)),
            _buildPollFooter(isTablet, isCompact, totalVotes),
          ],
        ),
      ),
    );
  }

  Widget _buildPollHeader(bool isTablet, bool isCompact, int totalVotes) {
    final creatorUsername = _currentPollData['creatorUsername'] ?? 'Unknown';
    final creatorRole = _currentPollData['creatorRole'] ?? 'member';
    final createdAt = _currentPollData['createdAt'] as Timestamp?;
    
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 14 : (isCompact ? 8 : 10)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.poll,
            color: Colors.white,
            size: isTablet ? 24 : (isCompact ? 16 : 20),
          ),
        ),
        SizedBox(width: isTablet ? 16 : (isCompact ? 8 : 12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '@$creatorUsername',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64B5F6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (creatorRole != 'member') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 8 : (isCompact ? 4 : 6),
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: creatorRole == 'admin' 
                              ? [Colors.amber, Colors.orange]
                              : [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        creatorRole.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 9 : (isCompact ? 6 : 7),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (createdAt != null)
                Text(
                  _formatTimestamp(createdAt),
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 12 : (isCompact ? 9 : 10),
                    color: Colors.white60,
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : (isCompact ? 6 : 8),
            vertical: isTablet ? 6 : (isCompact ? 3 : 4),
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 13 : (isCompact ? 9 : 11),
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPollQuestion(bool isTablet, bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : (isCompact ? 12 : 16)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Text(
        _currentPollData['question'] ?? '',
        style: GoogleFonts.poppins(
          fontSize: isTablet ? 18 : (isCompact ? 13 : 15),
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPollOptions(bool isTablet, bool isCompact, List<String> options, List<int> optionCounts, int totalVotes) {
    return Column(
      children: options.asMap().entries.map((entry) {
        final index = entry.key;
        final option = entry.value;
        final voteCount = index < optionCounts.length ? optionCounts[index] : 0;
        final isSelected = _userVote == 'option_$index';
        
        return PollOptionWidget(
          option: option,
          index: index,
          voteCount: voteCount,
          totalVotes: totalVotes,
          isSelected: isSelected,
          pollId: _currentPollData['id'] ?? _currentPollData['pollId'] ?? '',
          communityId: widget.communityId,
          userId: widget.userId,
          username: widget.username,
          onVote: () {
            // Real-time updates are handled by the stream listener
          },
        );
      }).toList(),
    );
  }

  Widget _buildPollFooter(bool isTablet, bool isCompact, int totalVotes) {
    return Row(
      children: [
        if (totalVotes > 0) ...[
          Expanded(
            child: TextButton.icon(
              onPressed: () => widget.onViewVotes(_currentPollData['id'] ?? _currentPollData['pollId'] ?? ''),
              icon: Icon(
                Icons.visibility_outlined,
                color: const Color(0xFF64B5F6),
                size: isTablet ? 18 : (isCompact ? 14 : 16),
              ),
              label: Text(
                'View Votes',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : (isCompact ? 11 : 12),
                  color: const Color(0xFF64B5F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : (isCompact ? 8 : 12),
                  vertical: isTablet ? 8 : (isCompact ? 4 : 6),
                ),
                backgroundColor: const Color(0xFF64B5F6).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : (isCompact ? 6 : 8),
            vertical: isTablet ? 6 : (isCompact ? 3 : 4),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade600.withOpacity(0.2),
                Colors.green.shade400.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.how_to_vote,
                color: Colors.green.shade400,
                size: isTablet ? 14 : (isCompact ? 10 : 12),
              ),
              const SizedBox(width: 4),
              Text(
                'Live Poll',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 11 : (isCompact ? 8 : 9),
                  color: Colors.green.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}