import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class BiddingScreen extends StatefulWidget {
  const BiddingScreen({super.key});

  @override
  State<BiddingScreen> createState() => _BiddingScreenState();
}

class _BiddingScreenState extends State<BiddingScreen> {
  bool showPast = false;
  String sortBy = 'endingSoon'; // default

  void switchView() => setState(() => showPast = !showPast);
void showTutorialOverlay() {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Tutorial",
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const SizedBox.shrink(); // Required but unused
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      final fade = Tween<double>(begin: 0, end: 1)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: Center(
            child: _HowItWorksCard(onClose: () => Navigator.of(context).pop()),
          ),
        ),
      );
    },
  );
}






Widget _stepBullet(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4.0),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("• ", style: TextStyle(color: Colors.amber)),
      Expanded(
        child: Text(text,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
      ),
    ],
  ),
);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
     appBar: AppBar(
  backgroundColor: Colors.black,
  elevation: 0,
  centerTitle: true,
  actions: [
    IconButton(
      onPressed: showTutorialOverlay,
      icon: const Icon(Icons.info_outline, color: Colors.amber),
      tooltip: 'How it works',
    )
  ],
),

      body: Column(
        children: [
          const SizedBox(height: 10),
          Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    GestureDetector(
      onTap: switchView,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFC107), Color(0xFFFFA000)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          children: [
            Icon(showPast ? Icons.arrow_back : Icons.history, color: Colors.black),
            const SizedBox(width: 6),
            Text(
              showPast ? "View Active Bids" : "View Past Bids",
              style: GoogleFonts.poppins(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    ),
    DropdownButton<String>(
      dropdownColor: Colors.grey[900],
      value: sortBy,
      style: GoogleFonts.poppins(color: Colors.amber),
      iconEnabledColor: Colors.amber,
      items: const [
        DropdownMenuItem(value: 'latest', child: Text('Latest First')),
        DropdownMenuItem(value: 'endingSoon', child: Text('Ending Soon')),
        DropdownMenuItem(value: 'mostBids', child: Text('Most Bids')),
        DropdownMenuItem(value: 'highestMin', child: Text('Highest Min Price')),
      ],
      onChanged: (val) => setState(() => sortBy = val!),
    )
  ],
),

          const SizedBox(height: 20),
          Expanded(child: TenderList(showExpired: showPast, sortBy: sortBy)),
        ],
      ),
    );
  }
}

class TenderList extends StatelessWidget {
  final bool showExpired;
  final String sortBy;
  const TenderList({super.key, required this.showExpired, required this.sortBy});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tenders')
          .orderBy('expiresAt')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }

        final now = DateTime.now();
        var tenders = snapshot.data!.docs.where((doc) {
          final expiry = (doc['expiresAt'] as Timestamp).toDate();
          return showExpired ? now.isAfter(expiry) : now.isBefore(expiry);
        }).toList();
        tenders = tenders.toList(); // ensure it's a list

tenders.sort((a, b) {
  final dataA = a.data() as Map<String, dynamic>;
  final dataB = b.data() as Map<String, dynamic>;

  switch (sortBy) {
    case 'latest':
      final tsA = (dataA['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final tsB = (dataB['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      return tsB.compareTo(tsA);
    case 'mostBids':
      final countA = (dataA['bids'] as Map?)?.length ?? 0;
      final countB = (dataB['bids'] as Map?)?.length ?? 0;
      return countB.compareTo(countA);
    case 'highestMin':
      final minA = (dataA['minPrice'] ?? 0) as num;
      final minB = (dataB['minPrice'] ?? 0) as num;
      return minB.compareTo(minA);
    case 'endingSoon':
    default:
      final endA = (dataA['expiresAt'] as Timestamp).toDate();
      final endB = (dataB['expiresAt'] as Timestamp).toDate();
      return endA.compareTo(endB);
  }
});

        if (tenders.isEmpty) {
          return Center(
            child: Text(
              showExpired ? "No past tenders." : "No active tenders available.",
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: tenders.length,
          separatorBuilder: (_, __) => Divider(color: Colors.white24),
          itemBuilder: (context, index) {
            final doc = tenders[index];
            final data = doc.data() as Map<String, dynamic>;
            final expiry = (data['expiresAt'] as Timestamp).toDate();
            final hasExpired = DateTime.now().isAfter(expiry);
            return TenderCard(
              id: doc.id,
              data: data,
              hasExpired: hasExpired,
              showBids: showExpired,
            );
          },
        );
      },
    );
  }
}
class TenderCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool hasExpired;
  final bool showBids;

  const TenderCard({
    super.key,
    required this.id,
    required this.data,
    required this.hasExpired,
    required this.showBids,
  });

  @override
  State<TenderCard> createState() => _TenderCardState();
}

class _TenderCardState extends State<TenderCard> {
  final TextEditingController _controller = TextEditingController();
  Duration _remaining = Duration.zero;
  Timer? _timer;
  String? userBid;
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    if (!widget.hasExpired) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateRemaining());
    }
    _loadUserBid();
  }



Widget _stepBullet(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4.0),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text("• ", style: TextStyle(color: Colors.amber)),
      Expanded(
        child: Text(text,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
      ),
    ],
  ),
);

  Future<void> _loadUserBid() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final username = userDoc['username'];
    final bids = Map<String, dynamic>.from(widget.data['bids'] ?? {});
    if (bids.containsKey(username)) {
      setState(() => userBid = bids[username]['amount'].toString());
    }
  }
   

  void _calculateRemaining() {
    final expiry = (widget.data['expiresAt'] as Timestamp).toDate();
    setState(() => _remaining = expiry.difference(DateTime.now()));
  }

  Future<void> _submitBid() async {
    if (userBid != null) return; // Prevent multiple bids
    final bid = double.tryParse(_controller.text.trim());
    final min = widget.data['minPrice']?.toDouble() ?? 0.0;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || bid == null || bid <= min) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final username = userDoc['username'] ?? 'anonymous';

    final tenderRef = FirebaseFirestore.instance.collection('tenders').doc(widget.id);
    final tenderSnap = await tenderRef.get();
    final bids = Map<String, dynamic>.from(tenderSnap['bids'] ?? {});
    bids[username] = {
      'amount': bid,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await tenderRef.update({'bids': bids});
    _controller.clear();

    setState(() => userBid = bid.toString());

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Bid submitted!', style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: Colors.green,
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String formatDuration(Duration d) {
    if (d.isNegative) return "Expired";
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  double getPercentRemaining() {
    final total = Duration(hours: 6).inSeconds;
    final left = _remaining.inSeconds.clamp(0, total);
    return left / total;
  }

  @override
  Widget build(BuildContext context) {
    final bids = Map<String, dynamic>.from(widget.data['bids'] ?? {});
    final sortedBids = bids.entries.toList()
      ..sort((a, b) {
  final aVal = a.value['amount'] as num;
  final bVal = b.value['amount'] as num;

  // If amount is different, sort by amount descending
  if (bVal != aVal) return bVal.compareTo(aVal);

  // Else, sort by timestamp ascending (earlier wins)
  final aTime = a.value['timestamp'] as Timestamp?;
  final bTime = b.value['timestamp'] as Timestamp?;

  if (aTime != null && bTime != null) {
    return aTime.compareTo(bTime);
  }
  return 0;
});


    final winner = sortedBids.isEmpty ? null : sortedBids.first;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF0C0C0C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.15),
            blurRadius: 14,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.data['title'] ?? '',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: Colors.amber,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: 4),
        Text("📍 ${widget.data['location']}",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
        const Divider(color: Colors.white12, height: 22),
        if (!widget.hasExpired)
  Column(
    children: [
      LinearProgressIndicator(
        value: getPercentRemaining(),
        backgroundColor: Colors.white12,
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
      ),
      const SizedBox(height: 6),
      Text("⏳ ${formatDuration(_remaining)}",
          style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 12)),
      const SizedBox(height: 12),
    ],
  ),
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    _infoTile("💰 Min Bid", "₹${widget.data['minPrice']}"),
    _infoTile(
      "Status",
      widget.hasExpired ? "Closed" : "Active",
      color: widget.hasExpired ? Colors.redAccent : Colors.greenAccent,
    ),
    _infoTile(
      "Your Bid",
      userBid != null ? "₹$userBid" : "No Bid",
      color: userBid != null ? Colors.amber : Colors.white60,
    ),
  ],
),


        if (!widget.hasExpired) ...[
          const SizedBox(height: 12),
          if (userBid == null) ...[
  TextField(
    controller: _controller,
    keyboardType: TextInputType.number,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: "enter your bid",
      hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Poppins_Regular'),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    ),
  ),
  const SizedBox(height: 10),
  SizedBox(
    width: double.infinity,
    child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amberAccent.withOpacity(0.6),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: MaterialButton(
        onPressed: _submitBid,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Text("PLACE BID",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
      ),
    ),
  ),
] else ...[
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      "✅ You placed a bid of ₹$userBid",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.amber,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    ),
  ),
],


        ],
        if (widget.hasExpired && winner != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(top: 12),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFC107), Color(0xFFFFA000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.amberAccent.withOpacity(0.7),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.orangeAccent.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Winner: ${winner.key} @ ₹${winner.value['amount']}",
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        if (widget.hasExpired && widget.showBids && sortedBids.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => expanded = !expanded),
            child: Row(
              children: [
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  expanded ? "Hide Bids" : "Show All Bids",
                  style: GoogleFonts.poppins(
                      color: Colors.amber, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
  duration: const Duration(milliseconds: 300),
  crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
  firstChild: Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedBids.map((entry) {
        final timestamp = entry.value['timestamp'];
        String timeText = "-";
        if (timestamp is Timestamp) {
          timeText = DateFormat('dd MMM, hh:mm a').format(timestamp.toDate());
        }
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${entry.key}", style: GoogleFonts.poppins(color: Colors.white70)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₹${entry.value['amount']}", style: GoogleFonts.poppins(color: Colors.amber)),
                  Text(timeText, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    ),
  ),
  secondChild: const SizedBox.shrink(),
)

        ],
      ]),
    );
  }

 Widget _infoTile(String label, String value, {Color? color}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label,
          style: GoogleFonts.poppins(fontSize: 11, color: Colors.white60)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.amber,
            )),
      ),
    ],
  );
}
}
class _HowItWorksCard extends StatelessWidget {
  final VoidCallback onClose;

  const _HowItWorksCard({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rules = [
      {"text": "Browse active tenders and tap to view details.", "icon": Icons.search_rounded},
      {"text": "Place a bid higher than the minimum bid.", "icon": Icons.price_change_outlined},
      {"text": "Only one bid allowed per tender per user.", "icon": Icons.lock_clock},
      {"text": "Highest bid wins when timer ends (early wins if tie).", "icon": Icons.emoji_events_outlined},
      {"text": "View past tenders and winners anytime.", "icon": Icons.history_edu_outlined},
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.12),
              blurRadius: 24,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("how this madness works",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 22,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 16),
            ...rules.map((item) => _bubble(item["text"]!, item["icon"]!)),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onClose,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.6),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text("Got it!",
                  style: GoogleFonts.poppins(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _bubble(String text, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amberAccent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
