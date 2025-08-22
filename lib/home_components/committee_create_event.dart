import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateEventPage extends StatefulWidget {
  final String committeeId;
  final String communityId;
  final String userId;
  final String username;

  const CreateEventPage({
    Key? key,
    required this.committeeId,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> with TickerProviderStateMixin {
  final ValueNotifier<bool> _isCreatingNotifier = ValueNotifier(false);
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _maxParticipantsController = TextEditingController();
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _requiresRegistration = false;
  bool _trackAttendance = false;
  String _eventType = 'general'; // general, workshop, meeting, competition

  @override
  void initState() {
    super.initState();
    _initAnimations();
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
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    _isCreatingNotifier.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4FC3F7),
              onPrimary: Colors.white,
              surface: Color(0xFF1E3A5F),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4FC3F7),
              onPrimary: Colors.white,
              surface: Color(0xFF1E3A5F),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  bool _canCreateEvent() {
    return _titleController.text.trim().isNotEmpty &&
           _descriptionController.text.trim().isNotEmpty &&
           _locationController.text.trim().isNotEmpty &&
           _selectedDate != null &&
           _selectedTime != null &&
           (!_requiresRegistration || _maxParticipantsController.text.trim().isNotEmpty);
  }

  Future<void> _createEvent() async {
    if (!_canCreateEvent()) return;

    try {
      _isCreatingNotifier.value = true;

      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final eventData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'eventType': _eventType,
        'eventDateTime': Timestamp.fromDate(eventDateTime),
        'requiresRegistration': _requiresRegistration,
        'trackAttendance': _trackAttendance,
        'maxParticipants': _requiresRegistration 
            ? int.tryParse(_maxParticipantsController.text.trim()) ?? 0
            : null,
        'currentParticipants': 0,
        'registeredUsers': <String>[],
        'attendedUsers': <String>[],
        'committeeId': widget.committeeId,
        'communityId': widget.communityId,
        'creatorId': widget.userId,
        'creatorUsername': widget.username,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'upcoming',
      };

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committees')
          .doc(widget.committeeId)
          .collection('events')
          .add(eventData);

      if (mounted) {
        _showMessage('Event created successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMessage('Error creating event: $e', isError: true);
    } finally {
      _isCreatingNotifier.value = false;
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width < 400 ? 16 : 20),
                    child: _buildForm(),
                  ),
                ),
                _buildCreateButton(),
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
          child: Row(
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
                  Icons.event_available, 
                  color: Colors.white, 
                  size: isCompact ? 20 : 24
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)],
                      ).createShader(bounds),
                      child: Text(
                        'create event',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: isCompact ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                    Text(
                      'organize committee event',
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
      },
    );
  }

  Widget _buildForm() {
    final isCompact = MediaQuery.of(context).size.width < 400;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event Title
        _buildFormField(
          'Event Title',
          _titleController,
          'Enter event title...',
          isCompact,
        ),

        SizedBox(height: isCompact ? 20 : 24),

        // Event Type
        _buildEventTypeSelector(isCompact),

        SizedBox(height: isCompact ? 20 : 24),

        // Description
        _buildFormField(
          'Description',
          _descriptionController,
          'Describe your event...',
          isCompact,
          maxLines: 4,
        ),

        SizedBox(height: isCompact ? 20 : 24),

        // Location
        _buildFormField(
          'Location',
          _locationController,
          'Event location...',
          isCompact,
        ),

        SizedBox(height: isCompact ? 20 : 24),

        // Date and Time
        _buildDateTimeSelector(isCompact),

        SizedBox(height: isCompact ? 20 : 24),

        // Registration Settings
        _buildRegistrationSettings(isCompact),

        SizedBox(height: isCompact ? 20 : 24),

        // Attendance Tracking
        _buildAttendanceSettings(isCompact),
      ],
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String hint, bool isCompact, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4FC3F7),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: GoogleFonts.poppins(
              color: Colors.white, 
              fontSize: isCompact ? 12 : 14
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventTypeSelector(bool isCompact) {
    final eventTypes = [
      {'value': 'general', 'label': 'General Event', 'icon': Icons.event},
      {'value': 'workshop', 'label': 'Workshop', 'icon': Icons.work},
      {'value': 'meeting', 'label': 'Meeting', 'icon': Icons.people},
      {'value': 'competition', 'label': 'Competition', 'icon': Icons.emoji_events},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Type',
          style: GoogleFonts.poppins(
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4FC3F7),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: eventTypes.map((type) {
            final isSelected = _eventType == type['value'];
            return GestureDetector(
              onTap: () => setState(() => _eventType = type['value'] as String),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: isCompact ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected 
                      ? LinearGradient(
                          colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFF4FC3F7)
                        : Colors.white.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      type['icon'] as IconData,
                      color: Colors.white,
                      size: isCompact ? 16 : 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type['label'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDateTimeSelector(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & Time',
          style: GoogleFonts.poppins(
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4FC3F7),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: const Color(0xFF4FC3F7),
                        size: isCompact ? 18 : 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                              : 'Select Date',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 12 : 14,
                            color: _selectedDate != null ? Colors.white : Colors.white60,
                          ),
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
                onTap: _selectTime,
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: const Color(0xFF4FC3F7),
                        size: isCompact ? 18 : 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Select Time',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 12 : 14,
                            color: _selectedTime != null ? Colors.white : Colors.white60,
                          ),
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
    );
  }

  Widget _buildRegistrationSettings(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.app_registration,
                color: const Color(0xFF4FC3F7),
                size: isCompact ? 18 : 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Registration Settings',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Requires Registration Toggle
          Container(
            padding: EdgeInsets.all(isCompact ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Require Registration',
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 13 : 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Users need to register to attend',
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 10 : 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _requiresRegistration,
                  onChanged: (value) => setState(() => _requiresRegistration = value),
                  activeColor: const Color(0xFF4FC3F7),
                ),
              ],
            ),
          ),

          if (_requiresRegistration) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _maxParticipantsController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(
                color: Colors.white, 
                fontSize: isCompact ? 12 : 14
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                hintText: 'Maximum participants (optional)',
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 16,
                  vertical: isCompact ? 10 : 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceSettings(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.fact_check,
            color: const Color(0xFF4FC3F7),
            size: isCompact ? 18 : 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Track Attendance',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Mark who attended the event',
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 11 : 13,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _trackAttendance,
            onChanged: (value) => setState(() => _trackAttendance = value),
            activeColor: const Color(0xFF4FC3F7),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    final isCompact = MediaQuery.of(context).size.width < 400;
    
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      child: ValueListenableBuilder<bool>(
        valueListenable: _isCreatingNotifier,
        builder: (context, isCreating, child) {
          final canCreate = _canCreateEvent();
          
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: canCreate 
                  ? LinearGradient(
                      colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                    )
                  : null,
              color: canCreate ? null : Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              boxShadow: canCreate ? [
                BoxShadow(
                  color: const Color(0xFF29B6F6).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            child: ElevatedButton(
              onPressed: canCreate && !isCreating ? _createEvent : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: isCompact ? 14 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isCreating
                  ? SizedBox(
                      height: isCompact ? 16 : 20,
                      width: isCompact ? 16 : 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          color: canCreate ? Colors.white : Colors.grey,
                          size: isCompact ? 18 : 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create Event',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: canCreate ? Colors.white : Colors.grey,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}