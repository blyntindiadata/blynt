import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/groups.dart/groupdetailscreen.dart';

class InviteRequestsScreen extends StatelessWidget {
  final String username;
  final String uid;

  const InviteRequestsScreen({
    super.key,
    required this.username,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = const LinearGradient(
      colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.black, // ✅ Black background
        title: ShaderMask(
          shaderCallback: (bounds) => gradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            "group invites",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('groupInvites')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.amber));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "you have no pending invites",
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          final invites = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: invites.length,
            itemBuilder: (context, index) {
              final invite = invites[index];
              final groupId = invite['groupId'] ?? 'Unknown';
              final groupName = invite['groupName'] ?? 'Unnamed Group';
              final invitedBy = invite['invitedBy'] ?? 'Unknown';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1C1C1C), Color(0xFF101010)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.amber.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group_add, color: Colors.amber, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            groupName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Group ID: $groupId",
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
                    ),
                    Text(
                      "Invited by: $invitedBy",
                      style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent[400],
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            try {
                              final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
                              final groupSnap = await groupRef.get();

                              if (!groupSnap.exists) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Group no longer exists")),
                                );
                                return;
                              }

                              await groupRef.update({
                                'pending': FieldValue.arrayRemove([username]),
                                'pendingUids': FieldValue.arrayRemove([uid]),
                                'members': FieldValue.arrayUnion([username]),
                                'memberUids': FieldValue.arrayUnion([uid]),
                                'memberJoinedAt.$username': Timestamp.now(),
                              });

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('groupInvites')
                                  .doc(groupId)
                                  .delete();

                              if (!context.mounted) return;

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(
                                    groupId: groupId,
                                    username: username,
                                    uid: uid,
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error accepting invite: $e")),
                              );
                            }
                          },
                          child: Text("Accept", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('groups')
                                  .doc(groupId)
                                  .update({
                                'pending': FieldValue.arrayRemove([username]),
                                'pendingUids': FieldValue.arrayRemove([uid]),
                              });

                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .collection('groupInvites')
                                  .doc(groupId)
                                  .delete();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error rejecting invite: $e")),
                              );
                            }
                          },
                          child: Text("Reject", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
