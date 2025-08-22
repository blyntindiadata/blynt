import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommitteeCalendar extends StatefulWidget {
  final String committeeId;
  final String communityId;
  final bool isCompact;

  const CommitteeCalendar({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.isCompact,
  }) : super(key: key);

  @override
  State<CommitteeCalendar> createState() => _CommitteeCalendarState();
}

class _CommitteeCalendarState extends State<CommitteeCalendar> {
  DateTime _currentMonth = DateTime.now();
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .collection('events')
          .where('status', isEqualTo: 'upcoming')
          .orderBy('eventDateTime')
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

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    return _events.where((event) {
      final eventDate = (event['eventDateTime'] as Timestamp).toDate();
      return eventDate.year == date.year &&
             eventDate.month == date.month &&
             eventDate.day == date.day;
    }).toList();
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  Color _getEventTypeColor(String? eventType) {
    switch (eventType?.toLowerCase()) {
      case 'meeting':
        return const Color(0xFF4FC3F7);
      case 'workshop':
        return const Color(0xFF66BB6A);
      case 'social':
        return const Color(0xFFFFB74D);
      case 'urgent':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  void _showDayEvents(DateTime date, List<Map<String, dynamic>> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events for ${date.day}/${date.month}/${date.year}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...events.map((event) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getEventTypeColor(event['eventType']).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getEventTypeColor(event['eventType']),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'] ?? 'Untitled Event',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (event['description'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            event['description'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: _getEventTypeColor(event['eventType']),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatEventTime(event['eventDateTime']),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: _getEventTypeColor(event['eventType']),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  String _formatEventTime(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: const Color(0xFF4FC3F7)),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isCompact ? 16 : 20),
      child: Column(
        children: [
          _buildCalendarHeader(),
          SizedBox(height: widget.isCompact ? 16 : 20),
          _buildCalendarGrid(),
          SizedBox(height: widget.isCompact ? 16 : 20),
          _buildUpcomingEvents(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Container(
      padding: EdgeInsets.all(widget.isCompact ? 12 : 16),
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
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _changeMonth(-1),
            child: Container(
              padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_left,
                color: const Color(0xFF4FC3F7),
                size: widget.isCompact ? 18 : 22,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: GoogleFonts.poppins(
                  fontSize: widget.isCompact ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _changeMonth(1),
            child: Container(
              padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.chevron_right,
                color: const Color(0xFF4FC3F7),
                size: widget.isCompact ? 18 : 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday

    final dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
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
        children: [
          // Day headers
          Container(
            padding: EdgeInsets.symmetric(
              vertical: widget.isCompact ? 8 : 12,
              horizontal: widget.isCompact ? 8 : 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: dayNames.map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.poppins(
                      fontSize: widget.isCompact ? 10 : 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4FC3F7),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),

          // Calendar days
          for (int week = 0; week < 6; week++) ...[
            Row(
              children: List.generate(7, (dayIndex) {
                final dayNumber = week * 7 + dayIndex - firstWeekday + 1;
                
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return Expanded(child: Container());
                }

                final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                final events = _getEventsForDate(date);
                final isToday = DateTime.now().year == date.year &&
                               DateTime.now().month == date.month &&
                               DateTime.now().day == date.day;

                return Expanded(
                  child: GestureDetector(
                    onTap: events.isNotEmpty ? () => _showDayEvents(date, events) : null,
                    child: Container(
                      height: widget.isCompact ? 40 : 50,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: isToday 
                            ? const Color(0xFF4FC3F7).withOpacity(0.3)
                            : events.isNotEmpty
                                ? const Color(0xFF29B6F6).withOpacity(0.2)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday ? Border.all(
                          color: const Color(0xFF4FC3F7),
                          width: 2,
                        ) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            dayNumber.toString(),
                            style: GoogleFonts.poppins(
                              fontSize: widget.isCompact ? 12 : 14,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                              color: isToday 
                                  ? Colors.white
                                  : events.isNotEmpty
                                      ? const Color(0xFF4FC3F7)
                                      : Colors.white70,
                            ),
                          ),
                          if (events.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ...events.take(3).map((event) => Container(
                                  width: widget.isCompact ? 4 : 5,
                                  height: widget.isCompact ? 4 : 5,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: _getEventTypeColor(event['eventType']),
                                    shape: BoxShape.circle,
                                  ),
                                )),
                                if (events.length > 3)
                                  Text(
                                    '+',
                                    style: GoogleFonts.poppins(
                                      fontSize: widget.isCompact ? 8 : 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4FC3F7),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUpcomingEvents() {
    final upcomingEvents = _events
        .where((event) {
          final eventDate = (event['eventDateTime'] as Timestamp).toDate();
          return eventDate.isAfter(DateTime.now());
        })
        .take(5)
        .toList();

    if (upcomingEvents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
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
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.event_available,
                size: 48,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No upcoming events',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Upcoming Events',
              style: GoogleFonts.poppins(
                fontSize: widget.isCompact ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          ...upcomingEvents.map((event) {
            final eventDate = (event['eventDateTime'] as Timestamp).toDate();
            final isToday = DateTime.now().year == eventDate.year &&
                           DateTime.now().month == eventDate.month &&
                           DateTime.now().day == eventDate.day;
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isToday 
                    ? const Color(0xFF4FC3F7).withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getEventTypeColor(event['eventType']).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getEventTypeColor(event['eventType']),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'] ?? 'Untitled Event',
                          style: GoogleFonts.poppins(
                            fontSize: widget.isCompact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${eventDate.day}/${eventDate.month}/${eventDate.year}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatEventTime(event['eventDateTime']),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        if (event['description'] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            event['description'],
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4FC3F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Today',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}