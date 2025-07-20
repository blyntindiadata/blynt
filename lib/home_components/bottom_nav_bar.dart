import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

class BottomNavBar extends StatefulWidget {
  final Function(int) onTabChange;

  const BottomNavBar({super.key, required this.onTabChange});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _shimmerController;

  final List<IconData> _icons = [
    Icons.explore,
    Icons.groups_sharp,
    Icons.star,
    Icons.book,
  ];

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.15),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5),
            ),
          ),
          child: GNav(
            selectedIndex: _selectedIndex,
            onTabChange: (index) {
              setState(() {
                _selectedIndex = index;
                _shimmerController.reset();
                _shimmerController.forward();
              });
              widget.onTabChange(index); // ✅ notify parent
            },
            backgroundColor: Colors.transparent,
            gap: 6,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            tabBorderRadius: 16,
            tabBackgroundColor: Colors.transparent,
            tabActiveBorder: Border.all(color: Colors.transparent),
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            tabs: List.generate(_icons.length, (index) {
              final isActive = _selectedIndex == index;

              return GButton(
                icon: Icons.circle,
                iconColor: Colors.transparent,
                leading: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Container(
                    key: ValueKey("tab$index$isActive"),
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        if (isActive)
                          Positioned(
                            top: -10,
                            child: AnimatedBuilder(
                              animation: _shimmerController,
                              builder: (context, child) {
                                final shimmerOffset =
                                    _shimmerController.value * 2 - 1;
                                return ShaderMask(
                                  shaderCallback: (bounds) {
                                    return LinearGradient(
                                      colors: const [
                                        Color(0xFFB29500),
                                        Color(0xFF806600),
                                        Color(0xFFB29500),
                                      ],
                                      begin: Alignment(-1 + shimmerOffset, 0),
                                      end: Alignment(1 + shimmerOffset, 0),
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcIn,
                                  child: Container(
                                    width: 30,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, child) {
                            final shimmerOffset =
                                _shimmerController.value * 2 - 1;
                            return ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  colors: const [
                                    Color(0xFFB29500),
                                    Color(0xFF806600),
                                    Color(0xFFB29500),
                                  ],
                                  begin: Alignment(-1 + shimmerOffset, 0),
                                  end: Alignment(1 + shimmerOffset, 0),
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: Icon(
                                _icons[index],
                                size: isActive ? 28 : 26,
                                color: isActive ? Colors.white : Colors.grey[700],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                text: '',
              );
            }),
          ),
        ),
      ),
    );
  }
}
