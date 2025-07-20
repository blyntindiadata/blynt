import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/events/category_selection.dart';
import 'package:startup/events/joineventscreen.dart';
import 'package:startup/events/pastevents.dart';

class ChooseEventScreen extends StatelessWidget {
  final String uid;
  final String username;
  final String firstName;
  final String lastName;
  const ChooseEventScreen({super.key, required this.uid, required this.username, required this.firstName, required this.lastName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
            'events @blynt',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1C1C1C),
              Color(0xFF0F0F0F),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F1F1F),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2A2A2A),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "🔮 Find or host events that spark your vibe.\nLet the city feel your energy.",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFFB0B0B0),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 35),
                  _buildStunningCard(
                    context,
                    title: "Host an Event",
                    subtitle: "Create unforgettable moments",
                    icon: Icons.rocket_launch_rounded,
                    primaryColor: const Color(0xFFF9B233),
                    accentColor: const Color(0xFFFF8008),
                    gradientColors: [
                      const Color(0xFFF9B233).withOpacity(0.2),
                      const Color(0xFFFF8008).withOpacity(0.15),
                      const Color(0xFFB95E00).withOpacity(0.1),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HostCategoryScreen(uid: uid,username: username,firstName: firstName,lastName: lastName,),
                        ),
                      );
                    },
                    description:
                        "🎤 Curate unforgettable gatherings, from turf matches to rooftop jams. Set your vibe and invite the tribe!",
                    features: ["Private or Public", "5–200 guests", "Takes 2 mins to setup"],
                  ),
                  const SizedBox(height: 25),
                  _buildStunningCard(
                    context,
                    title: "Join an Event",
                    subtitle: "Discover amazing experiences",
                    icon: Icons.handshake_rounded,
                    primaryColor: const Color(0xFFFF8008),
                    accentColor: const Color(0xFFB95E00),
                    gradientColors: [
                      const Color(0xFFFF8008).withOpacity(0.2),
                      const Color(0xFFB95E00).withOpacity(0.15),
                      const Color(0xFF8B4513).withOpacity(0.1),
                    ],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JoinEventScreen(uid: uid,username: username,firstName: firstName,lastName: lastName,),
                        ),
                      );
                    },
                    description:
                        "🎟️ Explore spontaneous hangouts, secret jamming sessions or coffee catchups. Jump in anytime!",
                    features: ["Browse nearby", "Real-time spots", "No commitment"],
                  ),
                  const SizedBox(height: 25),
                  _buildStunningCard(
                    context,
                    title: "Past Events",
                    subtitle: "Relive your memories",
                    icon: Icons.history_rounded,
                    primaryColor: const Color(0xFFB95E00),
                    accentColor: const Color(0xFF8B4513),
                    gradientColors: [
                      const Color(0xFFB95E00).withOpacity(0.2),
                      const Color(0xFF8B4513).withOpacity(0.15),
                      const Color(0xFF654321).withOpacity(0.1),
                    ],
                    onTap: () {
                      // Navigate to past events screen
                      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => PastEventScreen(
      uid: uid,
      username: username,
    ),
  ),
);

                    },
                    description:
                        "📸 Browse through your event history, share memories and reconnect with people you've met along the way.",
                    features: ["Photo galleries", "Event history", "Reconnect with friends"],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStunningCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required Color accentColor,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required String description,
    required List<String> features,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFF1A1A1A),
          border: Border.all(
            color: const Color(0xFF2A2A2A),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF3A3A3A),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: primaryColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF808080),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.2),
                              accentColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242424),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF3A3A3A),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFFB0B0B0),
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF3A3A3A),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: const Color(0xFF808080),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          features.join(' · '),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF909090),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}