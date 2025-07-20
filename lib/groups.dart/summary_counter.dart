import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SummaryCounter extends StatefulWidget {
  final List<Map<String, dynamic>> itinerary;
  final Map<int, List<String>> selectedTimeSlots;
  final Map<int, List<String>> outletMembers;

  const SummaryCounter({
    super.key,
    required this.itinerary,
    required this.selectedTimeSlots,
    required this.outletMembers,
  });

  @override
  State<SummaryCounter> createState() => _SummaryCounterState();
}

class _SummaryCounterState extends State<SummaryCounter>
    with SingleTickerProviderStateMixin {
  bool isDarkMode = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _controller.forward();
  }

  void switchView() {
    setState(() => isDarkMode = !isDarkMode);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double computeGrandTotal() {
    return widget.itinerary.asMap().entries.fold(0.0, (acc, entry) {
      final index = entry.key;
      final item = entry.value;
      final members = widget.outletMembers[index] ?? [];
      final costPerPerson = double.tryParse(
            item["Cost Per Person"]
                    ?.toString()
                    .replaceAll(RegExp(r'[^\d.]'), '') ??
                '0',
          ) ??
          0;
      return acc + (costPerPerson * members.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double grandTotal = computeGrandTotal();

    final backgroundGradient = isDarkMode
        ? const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF2A1F1F)])
        : const LinearGradient(colors: [Color(0xFFFDF3D0), Color(0xFFF9E8B5)]);

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final headingColor =
        isDarkMode ? Colors.amber.shade200 : Colors.brown.shade900;
    final subTextColor =
        isDarkMode ? Colors.white70 : Colors.brown.shade600;

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
            'billing summary',
            style: GoogleFonts.poppins(
              fontSize: 22,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "make sure everything is correct before proceeding🍾",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            GestureDetector(
  onTap: switchView,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFC107), Color(0xFFFFA000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.amberAccent.withOpacity(0.7),
          blurRadius: 12,
          spreadRadius: 1,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: Colors.orangeAccent.withOpacity(0.3),
          blurRadius: 4,
          offset: const Offset(0, 0),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
          size: 16,
          color: Colors.black,
        ),
        const SizedBox(width: 8),
        Text(
          isDarkMode ? "VIEW IN CLASSICAL MODE" : "BACK TO NIGHT VIEW",
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  ),
),


            const SizedBox(height: 20),

            // Ticket Card
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: 1 - (_controller.value * 0.3),
                  child: Transform.scale(
                    scale: 1 - (_controller.value * 0.02),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      padding: const EdgeInsets.all(8),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Card(
                            elevation: 14,
                            color: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ClipPath(
                              clipper: DiagonalTicketClipper(),
                              child: Container(
                                decoration: BoxDecoration(gradient: backgroundGradient),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Text(
                                        '🎫 one step away',
                                        style: GoogleFonts.dmSerifDisplay(
                                          fontSize: 24,
                                          color: headingColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    ...List.generate(widget.itinerary.length, (index) {
                                      final item = widget.itinerary[index];
                                      final members = widget.outletMembers[index] ?? [];
                                      final slots = widget.selectedTimeSlots[index] ?? [];
                                      final costPerPerson = double.tryParse(
                                            item["Cost Per Person"]
                                                    ?.toString()
                                                    .replaceAll(RegExp(r'[^\d.]'), '') ?? '0',
                                          ) ?? 0;
                                      final total = costPerPerson * members.length;

                                      return Stack(
                                        children: [
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: Center(
                                                child: Opacity(
                                                  opacity: 0.04,
                                                  child: Text(
                                                    'blynt',
                                                    style: GoogleFonts.dmSerifDisplay(
                                                      fontSize: 90,
                                                      color: headingColor,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Divider(color: headingColor.withOpacity(0.8)),
                                                const SizedBox(height: 6),
                                                Text(
                                                  item["Place"] ?? "Unknown Place",
                                                  style: GoogleFonts.dmSerifDisplay(
                                                    fontSize: 18, color: headingColor),
                                                ),
                                                Text(
                                                  item["Location"] ?? "No location",
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 12, color: subTextColor),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  "👥 Members: ${members.join(', ')}",
                                                  style: GoogleFonts.poppins(fontSize: 12, color: textColor),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "⏰ Time Slots: ${slots.join(', ')}",
                                                  style: GoogleFonts.poppins(fontSize: 12, color: textColor),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  "💰 ₹${costPerPerson.toStringAsFixed(2)} x ${members.length} = ₹${total.toStringAsFixed(2)}",
                                                  style: GoogleFonts.robotoMono(
                                                    fontSize: 12,
                                                    color: textColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                    const SizedBox(height: 20),
                                    Divider(color: headingColor.withOpacity(0.8), thickness: 1),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Grand Total',
                                            style: GoogleFonts.dmSerifDisplay(fontSize: 18, color: headingColor),
                                          ),
                                          TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0, end: grandTotal),
                                            duration: const Duration(milliseconds: 1000),
                                            builder: (context, value, _) => Text(
                                              '₹${value.toStringAsFixed(2)}',
                                              style: GoogleFonts.robotoMono(
                                                fontSize: 18,
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Positioned(left: -6, top: 40, child: _PunchHole()),
                          const Positioned(left: -6, bottom: 40, child: _PunchHole()),
                          const Positioned(right: -6, top: 40, child: _PunchHole()),
                          const Positioned(right: -6, bottom: 40, child: _PunchHole()),
                          const Positioned(top: -6, left: 80, child: _PunchHole()),
                          const Positioned(top: -6, right: 80, child: _PunchHole()),
                          const Positioned(bottom: -6, left: 80, child: _PunchHole()),
                          const Positioned(bottom: -6, right: 80, child: _PunchHole()),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 30),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Proceeding to next step..."),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFC107), Color(0xFFFFA000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  "PROCEED",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// Same clipper & punch hole
class DiagonalTicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double slice = 16;
    final path = Path();
    path.moveTo(0, slice);
    path.lineTo(slice, 0);
    path.lineTo(size.width - slice, 0);
    path.lineTo(size.width, slice);
    path.lineTo(size.width, size.height - slice);
    path.lineTo(size.width - slice, size.height);
    path.lineTo(slice, size.height);
    path.lineTo(0, size.height - slice);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _PunchHole extends StatelessWidget {
  const _PunchHole();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
    );
  }
}
