import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/groups.dart/group_book_outlet.dart';
import 'package:startup/groups.dart/itineraryscreen.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String username;
  final String uid;
  const GroupDetailScreen({super.key, required this.groupId, required this.username, required this.uid});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Map<String, dynamic>? groupData;
  final TextEditingController _amountController = TextEditingController();

  final gradient = const LinearGradient(
    colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    loadGroup(widget.groupId);
  }

  Future<void> loadGroup(String groupId) async {
    final doc = await FirebaseFirestore.instance.collection('groups').doc(groupId).get();
    final data = doc.data() ?? {};
    if (!data.containsKey('wallet')) {
      data['wallet'] = 0;
      data['contributions'] = {widget.username: 0};
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        'wallet': 0,
        'contributions': {widget.username: 0},
      });
    }
    setState(() => groupData = data);
  }

  Future<void> _addMoneyDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Add Money to Wallet", style: GoogleFonts.poppins(color: Colors.amberAccent)),
        content: TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter amount",
            hintStyle: TextStyle(color: Colors.white54),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amberAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            onPressed: () async {
              final input = _amountController.text.trim();
              final amount = int.tryParse(input);
              if (amount == null || amount <= 0) return;

              final docRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
              final doc = await docRef.get();
              final data = doc.data() ?? {};

              int oldWallet = data['wallet'] ?? 0;
              final updatedWallet = oldWallet + amount;
              Map<String, dynamic> contributions = Map<String, dynamic>.from(data['contributions'] ?? {});
              contributions[widget.username] = (contributions[widget.username] ?? 0) + amount;

              await docRef.update({
                'wallet': updatedWallet,
                'contributions': contributions,
              });

              Navigator.pop(context);
              _amountController.clear();
              await loadGroup(widget.groupId);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  Widget _buildFancyButton({required String emoji, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: Center(
            child: Text("$emoji  $label", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (groupData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    final groupMembersList = List<String>.from(groupData?['members'] ?? []);
    final pending = List<String>.from(groupData?['pending'] ?? []);
    final creator = groupMembersList.isNotEmpty ? groupMembersList.first : "Unknown";
    final walletAmount = groupData?['wallet'] ?? 0;
    final contributions = Map<String, dynamic>.from(groupData?['contributions'] ?? {});

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => gradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            groupData?['groupName'] ?? '',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: gradient,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 20, color: Colors.black),
                  const SizedBox(width: 8),
                  Text("Created by @$creator", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          Text("👥 Members (${groupMembersList.length})", style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: groupMembersList.map((m) => Chip(
              label: Text(m, style: GoogleFonts.poppins(color: Colors.white)),
              avatar: const Icon(Icons.person, color: Colors.amber, size: 20),
              backgroundColor: const Color(0xFF1A1A1A),
              side: BorderSide(color: Colors.amber.withOpacity(0.5)),
            )).toList(),
          ),

          const SizedBox(height: 30),

          if (pending.isNotEmpty) ...[
            Text("⏳ Pending Invites (${pending.length})", style: GoogleFonts.poppins(color: Colors.red, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: pending.map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Color.fromARGB(255, 166, 29, 19)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 8),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_bottom, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(p, style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: 30),
          ],

          Text("💳 blynt wallet", style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF292929), Color(0xFF181818)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 16)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Group Balance", style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14)),
                const SizedBox(height: 6),
                Text("₹$walletAmount", style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.wallet, color: Colors.white60, size: 18),
                    const SizedBox(width: 6),
                    Text("Virtual Group Wallet", style: GoogleFonts.poppins(color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text("Member Contributions", style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Column(
            children: contributions.entries.map((entry) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: GoogleFonts.poppins(color: Colors.white70)),
                  Text("₹${entry.value}", style: GoogleFonts.poppins(color: Colors.greenAccent, fontWeight: FontWeight.w600)),
                ],
              ),
            )).toList(),
          ),

          const SizedBox(height: 20),
          GestureDetector(
            onTap: _addMoneyDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Center(
                child: Text("💰  ADD MONEY TO WALLET", style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
              ),
            ),
          ),

          const SizedBox(height: 32),
          Text("📅 Upcoming Bookings", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text("No upcoming bookings.", style: GoogleFonts.poppins(color: Colors.white54)),
            ),
          ),

          const SizedBox(height: 32),
          Text("🔍 Suggested Places", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text("No recommendations as of now.", style: GoogleFonts.poppins(color: Colors.white54)),
            ),
          ),

          const SizedBox(height: 32),
          Text("📖 Past Bookings", style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text("No past bookings found.", style: GoogleFonts.poppins(color: Colors.white54)),
            ),
          ),

          const SizedBox(height: 32),
          Row(
            children: [
              _buildFancyButton(
                emoji: "📍",
                label: "BOOK OUTLET",
                onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OutletRecommendationsScreen(
        // outletId: outletId, // or pass full outlet data
        groupId: widget.groupId,
        username: widget.username,
        uid: widget.uid,
      ),
    ),
  );
},

              ),
              const SizedBox(width: 16),
              _buildFancyButton(
  emoji: "🎉",
  label: "PLAN EVENT",
  onTap: () async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    final userData = userDoc.data() ?? {};

    final coordinates = userData['coordinates'] ?? {};
    final numPeople = userData['people'] ?? 2;

    if (coordinates is Map<String, dynamic> &&
        coordinates.containsKey('latitude') &&
        coordinates.containsKey('longitude')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ItineraryScreen(
            username: widget.username,
            coordinates: coordinates,
            numPeople: numPeople,
            groupMembers: groupMembersList,
            groupId:widget.groupId
            // numPlaces: 2,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User coordinates not found.")),
      );
    }
  },
),



            ],
          ),

          const SizedBox(height: 36),
        ]),
      ),
    );
  }
}
