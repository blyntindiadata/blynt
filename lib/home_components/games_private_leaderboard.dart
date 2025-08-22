import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePrivateLeaderboardScreen extends StatefulWidget {
  final String communityId;
  final String username;
  final VoidCallback onCreated;

  const CreatePrivateLeaderboardScreen({
    Key? key,
    required this.communityId,
    required this.username,
    required this.onCreated,
  }) : super(key: key);

  @override
  State<CreatePrivateLeaderboardScreen> createState() => _CreatePrivateLeaderboardScreenState();
}

class _CreatePrivateLeaderboardScreenState extends State<CreatePrivateLeaderboardScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<String> selectedMembers = [];
  List<Map<String, dynamic>> availableUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  bool isLoading = false;
  bool isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      // Load users from the users collection and check community membership
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final List<Map<String, dynamic>> users = [];
      
      for (final userDoc in usersQuery.docs) {
        final userData = userDoc.data();
        final username = userData['username'];
        
        if (username != null && username != widget.username) {
          // Check if user is a member of this community
          final memberDoc = await FirebaseFirestore.instance
              .collection('communities')
              .doc(widget.communityId)
              .collection('members')
              .doc(username)
              .get();
          
          if (memberDoc.exists) {
            final memberData = memberDoc.data() ?? {};
            users.add({
              'username': username,
              'firstName': userData['firstName'] ?? '',
              'lastName': userData['lastName'] ?? '',
              'profileImageUrl': userData['profileImageUrl'],
              'branch': memberData['branch'] ?? userData['branch'] ?? '',
              'year': memberData['year'] ?? userData['year'] ?? '',
            });
          }
        }
      }

      setState(() {
        availableUsers = users;
        filteredUsers = users;
        isLoadingUsers = false;
      });
    } catch (e) {
      print('Error loading users: $e');
      setState(() {
        isLoadingUsers = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredUsers = availableUsers.where((user) {
        final username = user['username']?.toLowerCase() ?? '';
        final firstName = user['firstName']?.toLowerCase() ?? '';
        final lastName = user['lastName']?.toLowerCase() ?? '';
        return username.contains(query) || firstName.contains(query) || lastName.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4A1625),
              const Color(0xFF2D0F1A),
              const Color(0xFF1A0B11),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _buildForm(),
              ),
            ],
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
                const Color(0xFF4A1625).withOpacity(0.3),
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
                    colors: [const Color(0xFF8B2635), const Color(0xFF4A1625)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B2635).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add, 
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
                        colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                      ).createShader(bounds),
                      child: Text(
                        'create private leaderboard',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: isCompact ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                    Text(
                      'compete with friends',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 10 : 12,
                        color: const Color(0xFFE91E63),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Padding(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name Input
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8B2635).withOpacity(0.1),
                        const Color(0xFF4A1625).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B2635).withOpacity(0.3),
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
                            Icon(
                              Icons.edit,
                              color: const Color(0xFFE91E63),
                              size: isCompact ? 18 : 20,
                            ),
                            SizedBox(width: isCompact ? 8 : 10),
                            Text(
                              'Leaderboard Details',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 12 : 16),
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: isCompact ? 14 : 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Leaderboard Name',
                            labelStyle: GoogleFonts.poppins(color: Colors.white70),
                            hintText: 'Enter a creative name...',
                            hintStyle: GoogleFonts.poppins(color: Colors.white38),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: const Color(0xFFE91E63), width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a name';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isCompact ? 20 : 24),

                // Members Selection
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8B2635).withOpacity(0.1),
                        const Color(0xFF4A1625).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF8B2635).withOpacity(0.3),
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
                            Icon(
                              Icons.people,
                              color: const Color(0xFFE91E63),
                              size: isCompact ? 18 : 20,
                            ),
                            SizedBox(width: isCompact ? 8 : 10),
                            Text(
                              'Select Members',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 16 : 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 8 : 10,
                                vertical: isCompact ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${selectedMembers.length} selected',
                                style: GoogleFonts.poppins(
                                  fontSize: isCompact ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isCompact ? 12 : 16),

                        // Search Input
                        TextField(
                          controller: _searchController,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: isCompact ? 14 : 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Search Members',
                            labelStyle: GoogleFonts.poppins(color: Colors.white70),
                            prefixIcon: Icon(Icons.search, color: Colors.white70),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.white30),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: const Color(0xFFE91E63), width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                          ),
                        ),

                        // Selected Members
                        if (selectedMembers.isNotEmpty) ...[
                          SizedBox(height: isCompact ? 12 : 16),
                          Container(
                            height: isCompact ? 50 : 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: selectedMembers.length,
                              itemBuilder: (context, index) {
                                final username = selectedMembers[index];
                                return Container(
                                  margin: EdgeInsets.only(right: isCompact ? 8 : 10),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isCompact ? 12 : 16,
                                    vertical: isCompact ? 8 : 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                                    ),
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE91E63).withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '@$username',
                                        style: GoogleFonts.poppins(
                                          fontSize: isCompact ? 13 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: isCompact ? 6 : 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedMembers.remove(username);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.close,
                                            size: isCompact ? 14 : 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isCompact ? 16 : 20),

                // Available Users List
                Expanded(
                  child: isLoadingUsers
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: const Color(0xFFE91E63),
                              ),
                              SizedBox(height: isCompact ? 12 : 16),
                              Text(
                                'Loading members...',
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: isCompact ? 14 : 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : filteredUsers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: isCompact ? 40 : 48,
                                    color: Colors.white30,
                                  ),
                                  SizedBox(height: isCompact ? 12 : 16),
                                  Text(
                                    'No members found',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white60,
                                      fontSize: isCompact ? 16 : 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Try adjusting your search',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white38,
                                      fontSize: isCompact ? 13 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                final username = user['username'];
                                final isSelected = selectedMembers.contains(username);
                                
                                return _buildUserItem(user, isSelected, isCompact);
                              },
                            ),
                ),

                // Create Button
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(top: isCompact ? 16 : 20),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _createLeaderboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B2635),
                      padding: EdgeInsets.symmetric(
                        vertical: isCompact ? 16 : 20,
                        horizontal: isCompact ? 24 : 32,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Creating...',
                                style: GoogleFonts.poppins(
                                  fontSize: isCompact ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rocket_launch,
                                color: Colors.white,
                                size: isCompact ? 20 : 24,
                              ),
                              SizedBox(width: isCompact ? 8 : 12),
                              Text(
                                'Create Leaderboard',
                                style: GoogleFonts.poppins(
                                  fontSize: isCompact ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user, bool isSelected, bool isCompact) {
    final fullName = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedMembers.remove(user['username']);
          } else {
            selectedMembers.add(user['username']);
          }
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 8 : 10),
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: isSelected ? [
              const Color(0xFF8B2635).withOpacity(0.3),
              const Color(0xFF4A1625).withOpacity(0.2),
            ] : [
              Colors.white.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF8B2635).withOpacity(0.6)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF8B2635).withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Row(
          children: [
            // Profile Image
            Container(
              width: isCompact ? 45 : 50,
              height: isCompact ? 45 : 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFE91E63) : Colors.white30,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: user['profileImageUrl'] != null
                    ? Image.network(
                        user['profileImageUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildUserAvatar(fullName, isCompact),
                      )
                    : _buildUserAvatar(fullName, isCompact),
              ),
            ),
            SizedBox(width: isCompact ? 12 : 16),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName.isNotEmpty ? fullName : 'Unknown User',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user['username']}',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 12 : 13,
                      color: Colors.white60,
                    ),
                  ),
                  if (user['branch']?.isNotEmpty == true || user['year']?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (user['branch']?.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B2635).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF8B2635).withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              user['branch'],
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 9 : 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFE91E63),
                              ),
                            ),
                          ),
                        if (user['branch']?.isNotEmpty == true && 
                            user['year']?.isNotEmpty == true)
                          const SizedBox(width: 4),
                        if (user['year']?.isNotEmpty == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A1625).withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF4A1625).withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              user['year'],
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 9 : 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Selection Indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isCompact ? 8 : 10),
              decoration: BoxDecoration(
                gradient: isSelected ? LinearGradient(
                  colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
                ) : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.white30,
                  width: 1,
                ),
              ),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.add_circle_outline,
                color: isSelected ? Colors.white : Colors.white60,
                size: isCompact ? 20 : 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String fullName, bool isCompact) {
    final initials = fullName.isNotEmpty 
        ? fullName.split(' ')
            .where((name) => name.isNotEmpty)
            .take(2)
            .map((name) => name[0].toUpperCase())
            .join()
        : 'U';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE91E63), const Color(0xFF8B2635)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: isCompact ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _createLeaderboard() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please select at least one member',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Create leaderboard
      final leaderboardRef = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('private_leaderboards')
          .add({
        'name': _nameController.text.trim(),
        'createdBy': widget.username,
        'members': [widget.username], // Creator is automatically a member
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send requests to selected members
      final batch = FirebaseFirestore.instance.batch();
      
      for (final username in selectedMembers) {
        final requestRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('private_leaderboard_requests')
            .doc();

        batch.set(requestRef, {
          'leaderboardId': leaderboardRef.id,
          'leaderboardName': _nameController.text.trim(),
          'username': username,
          'invitedBy': widget.username,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      Navigator.pop(context);
      widget.onCreated();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Private leaderboard created! Invitations sent to ${selectedMembers.length} members.',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('Error creating leaderboard: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error creating leaderboard. Please try again.',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    setState(() {
      isLoading = false;
    });
  }
}