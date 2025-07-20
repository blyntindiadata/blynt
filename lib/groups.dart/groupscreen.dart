import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/groups.dart/creategroupscreen.dart';
import 'package:startup/groups.dart/group_invites_screen.dart';
import 'package:startup/groups.dart/groupdetailscreen.dart';
import 'package:startup/helpers/page_animation.dart';

class GroupScreen extends StatefulWidget {
  final String username;
  final String uid;

  const GroupScreen({super.key, required this.username, required this.uid});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  List<DocumentSnapshot> myGroups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchGroups();
  }

  Future<void> fetchGroups() async {
    setState(() => isLoading = true);

    final snap = await FirebaseFirestore.instance
        .collection('groups')
        .where('members', arrayContains: widget.username)
        .orderBy('createdAt', descending: true)
        .get();

    setState(() {
      myGroups = snap.docs;
      isLoading = false;
    });
  }

  bool isRecentlyJoined(Map<String, dynamic> groupData) {
    if (groupData['memberJoinedAt'] == null ||
        groupData['memberJoinedAt'][widget.username] == null) {
      return false;
    }

    final Timestamp joinedAt = groupData['memberJoinedAt'][widget.username];
    final now = DateTime.now();
    final joinedDate = joinedAt.toDate();

    return now.difference(joinedDate).inHours < 24;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Text(
              'your groups',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 22,
              ),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InviteRequestsScreen(
                      username: widget.username,
                      uid: widget.uid,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFB87333), // bronze
                      Color.fromARGB(255, 240, 166, 37), // amber
                      Color.fromARGB(255, 179, 130, 8), // golden
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : myGroups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.group_off, color: Colors.white24, size: 80),
                      const SizedBox(height: 16),
                      Text(
                        "You are not in any group",
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        onPressed: () async {
  navigateWithBlurFade(
    context,
    CreateGroupScreen(
      username: widget.username,
      uid: widget.uid,
    ),
  );
  fetchGroups();
},

                        child: Text("Create Group",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            )),
                      )
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: myGroups.length + 1,
                  itemBuilder: (context, index) {
                    if (index == myGroups.length) {
                      return Padding(
                        padding: const EdgeInsets.only(
                            top: 30, bottom: 20, left: 24, right: 24),
                        child: Text(
                          "create groups with your friends and craft moments that matter ✨",
                          style: GoogleFonts.poppins(
                            color: Colors.white24,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final group = myGroups[index].data() as Map<String, dynamic>;
                    final bool recentlyJoined = isRecentlyJoined(group);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4E342E),
                              Color(0xFF8B5E3C),
                              Color(0xFFB77800),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.amberAccent.withOpacity(0.9),
                            width: 1.4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              title: Text(
                                group['groupName'],
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                "Group ID: ${group['groupId']}",
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.amberAccent,
                                size: 16,
                              ),
                             onTap: () => navigateWithBlurFade(
  context,
  GroupDetailScreen(
    groupId: group['groupId'],
    username: widget.username,
    uid: widget.uid,
  ),
),

                            ),
                            if (recentlyJoined)
                              Positioned(
                                top: 10,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'recently joined',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: GestureDetector(
       onTap: () async {
  navigateWithBlurFade(
    context,
    CreateGroupScreen(
      username: widget.username,
      uid: widget.uid,
    ),
  );
  fetchGroups();
},

        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFFB87333), Color(0xFF3E2723)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.amberAccent,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
