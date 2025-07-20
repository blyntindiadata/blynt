import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/groups.dart/group_helpers.dart';

class CreateGroupScreen extends StatefulWidget {
  final String username;
  final String uid;

  const CreateGroupScreen({
    super.key,
    required this.username,
    required this.uid,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();

  bool loading = false;

  String groupFeedback = '';
  bool isGroupValid = false;
  bool isGroupChecking = false;

  List<String> addedUsernames = [];
  Map<String, bool> userValidity = {};

  List<String> allUsernamesCache = [];

  Future<void> createGroup() async {
    final name = _nameController.text.trim();
    if (!isGroupValid || addedUsernames.isEmpty || userValidity.containsValue(false)) return;

    setState(() => loading = true);

    try {
      final id = await getNextGroupId();
      final now = Timestamp.now();

      final userSnaps = await FirebaseFirestore.instance
          .collection('users')
          .where('username', whereIn: addedUsernames)
          .get();

      final pendingUids = userSnaps.docs.map((doc) => doc.id).toList();
      final pendingUsernames = userSnaps.docs.map((doc) => doc['username'] as String).toList();

      await FirebaseFirestore.instance.collection('groups').doc(id).set({
        'groupId': id,
        'groupName': name,
        'createdBy': widget.username,
        'members': [widget.username],
        'memberUids': [widget.uid],
        'pending': pendingUsernames,
        'pendingUids': pendingUids,
        'createdAt': FieldValue.serverTimestamp(),
        'memberJoinedAt': {
          widget.username: now,
        },
      });

      for (int i = 0; i < pendingUids.length; i++) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(pendingUids[i])
            .collection('groupInvites')
            .doc(id)
            .set({
          'groupId': id,
          'groupName': name,
          'invitedBy': widget.username,
          'timestamp': now,
        });
      }

      if (mounted) Navigator.pop(context);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> checkGroupName(String name) async {
    setState(() {
      groupFeedback = '';
      isGroupValid = false;
      isGroupChecking = true;
    });

    if (name.trim().isEmpty) {
      groupFeedback = "Group name cannot be empty";
      isGroupChecking = false;
      setState(() {});
      return;
    }

    final groupSnap = await FirebaseFirestore.instance
        .collection('groups')
        .where('groupName', isEqualTo: name.trim())
        .get();

    if (groupSnap.docs.isEmpty) {
      groupFeedback = "✓ Group name available";
      isGroupValid = true;
    } else {
      groupFeedback = "Group name is already taken";
      isGroupValid = false;
    }

    isGroupChecking = false;
    setState(() {});
  }

  Future<void> loadAllUsernames() async {
    if (allUsernamesCache.isNotEmpty) return;

    final snap = await FirebaseFirestore.instance.collection('users').get();
    allUsernamesCache = snap.docs.map((doc) => doc['username'].toString()).toList();
  }

  Future<void> tryAddFriend(String username) async {
    await loadAllUsernames();

    final trimmed = username.trim();
    if (trimmed.isEmpty || trimmed == widget.username || addedUsernames.contains(trimmed)) return;

    final isValid = allUsernamesCache.contains(trimmed);
    setState(() {
      addedUsernames.add(trimmed);
      userValidity[trimmed] = isValid;
      _memberController.clear();
    });
  }

  void removeUser(String username) {
    setState(() {
      addedUsernames.remove(username);
      userValidity.remove(username);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFFFFD700);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'create group',
            style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'create a group and invite up to 20 friends to unlock event planning and expense splitting🎉',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CREATE GROUP NAME',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              onChanged: checkGroupName,
              style: GoogleFonts.poppins(color: Colors.white),
              cursorColor: themeColor,
              decoration: InputDecoration(
                labelText: "group name",
                labelStyle: GoogleFonts.poppins(color: Colors.grey),
                suffixIcon: isGroupChecking
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                      )
                    : groupFeedback.isNotEmpty
                        ? Icon(
                            isGroupValid ? Icons.check_circle : Icons.error,
                            color: isGroupValid ? Colors.greenAccent : Colors.redAccent,
                          )
                        : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeColor, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            if (groupFeedback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  groupFeedback,
                  style: GoogleFonts.poppins(
                    color: isGroupValid ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'SEARCH FRIENDS TO ADD',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memberController,
              onSubmitted: tryAddFriend,
              style: GoogleFonts.poppins(color: Colors.white),
              cursorColor: themeColor,
              decoration: InputDecoration(
                labelText: "type username",
                labelStyle: GoogleFonts.poppins(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white12),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: themeColor, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[900],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: addedUsernames.map((username) {
                final isValid = userValidity[username] ?? false;
                return Chip(
                  label: Text(
                    username,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      color: isValid ? Colors.white : Colors.redAccent,
                    ),
                  ),
                  avatar: Icon(
                    isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.greenAccent : Colors.redAccent,
                    size: 18,
                  ),
                  backgroundColor: Colors.grey[850],
                  deleteIconColor: Colors.white54,
                  onDeleted: () => removeUser(username),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            loading
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : GestureDetector(
                    onTap: (isGroupValid && addedUsernames.isNotEmpty && !userValidity.containsValue(false))
                        ? createGroup
                        : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: (isGroupValid && addedUsernames.isNotEmpty && !userValidity.containsValue(false))
                            ? const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFB77200)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(colors: [Colors.grey, Colors.grey]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: (isGroupValid && addedUsernames.isNotEmpty && !userValidity.containsValue(false))
                            ? [
                                BoxShadow(
                                  color: Colors.amberAccent.withOpacity(0.6),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 0),
                                ),
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF101010), Color(0xFF222222)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            "CREATE GROUP",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
