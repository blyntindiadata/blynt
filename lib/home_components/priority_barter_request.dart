import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PriorityRequestsPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;

  const PriorityRequestsPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
  }) : super(key: key);

  @override
  State<PriorityRequestsPage> createState() => _PriorityRequestsPageState();
}

class _PriorityRequestsPageState extends State<PriorityRequestsPage> {
  final ValueNotifier<List<Map<String, dynamic>>> _requestsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadPriorityRequests();
  }

  @override
  void dispose() {
    _requestsNotifier.dispose();
    _isLoadingNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadPriorityRequests() async {
    try {
      _isLoadingNotifier.value = true;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('priority_requests')
          .where('processed', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      final requests = <Map<String, dynamic>>[];
      for (var doc in snapshot.docs) {
        requests.add({
          'id': doc.id,
          ...doc.data(),
        });
      }

      _requestsNotifier.value = requests;
    } catch (e) {
      print('Error loading priority requests: $e');
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  Future<void> _processPriorityRequest(String requestId, String barterId, bool approve) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update the priority request
      final requestRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('priority_requests')
          .doc(requestId);
      
      batch.update(requestRef, {
        'processed': true,
        'approved': approve,
        'processedBy': widget.userId,
        'processedAt': FieldValue.serverTimestamp(),
      });

      // Update the barter
      final barterRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('barters')
          .doc(barterId);
      
      batch.update(barterRef, {
        'priorityApproved': approve,
      });

      await batch.commit();
      
      _loadPriorityRequests();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Priority request approved' : 'Priority request rejected',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: approve ? Colors.green.shade700 : Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing request: $e', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _showConfirmationDialog(String requestId, String barterId, String username, String request, bool approve) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (approve ? Colors.green : Colors.red).withOpacity(0.3),
              width: 1,
            ),
          ),
          title: Text(
            '${approve ? 'Approve' : 'Reject'} Priority Request',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User: $username',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF7B42C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Request: $request',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Text(
                approve 
                  ? 'This barter will be marked as priority and appear at the top of the feed.'
                  : 'This barter will remain as a normal barter without priority status.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white60,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                approve ? 'Approve' : 'Reject',
                style: GoogleFonts.poppins(
                  color: approve ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _processPriorityRequest(requestId, barterId, approve);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Priority Requests',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFF7B42C)),
            onPressed: _loadPriorityRequests,
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoadingNotifier,
        builder: (context, isLoading, child) {
          if (isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFF7B42C)),
            );
          }

          return ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: _requestsNotifier,
            builder: (context, requests, child) {
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.priority_high,
                        size: 64,
                        color: Colors.white30,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No pending priority requests',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All priority requests have been processed',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  // Header info
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF7B42C).withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFF7B42C), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${requests.length} priority ${requests.length == 1 ? 'request' : 'requests'} awaiting your review',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Requests list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        final createdAt = (request['createdAt'] as Timestamp?)?.toDate();
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF7B42C).withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF7B42C).withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.priority_high,
                                      color: Colors.black87,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          request['username'] ?? 'Unknown User',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (createdAt != null)
                                          Text(
                                            'Requested ${_getTimeAgo(createdAt)}',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white60,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'PENDING',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.orange,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Request content
                              Text(
                                'Priority Request:',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFF7B42C),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                request['request'] ?? '',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Action buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showConfirmationDialog(
                                        request['id'],
                                        request['barterId'],
                                        request['username'] ?? 'Unknown',
                                        request['request'] ?? '',
                                        false,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.red.withOpacity(0.8), Colors.red.withOpacity(0.6)],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.close, color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Reject',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => _showConfirmationDialog(
                                        request['id'],
                                        request['barterId'],
                                        request['username'] ?? 'Unknown',
                                        request['request'] ?? '',
                                        true,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF10B981).withOpacity(0.3),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.check, color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Approve',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}