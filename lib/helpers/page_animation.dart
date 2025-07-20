import 'dart:ui';
import 'package:flutter/material.dart';

void navigateWithBlurFade(BuildContext context, Widget page) {
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curve = CurvedAnimation(parent: animation, curve: Curves.easeInOut);

        return Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10 * (1 - curve.value),
                sigmaY: 10 * (1 - curve.value),
              ),
              child: Container(
                color: Colors.black.withOpacity(0.1),
              ),
            ),
            FadeTransition(
              opacity: curve,
              child: child,
            ),
          ],
        );
      },
      transitionDuration: Duration(milliseconds: 600),
    ),
  );
}
