import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
  }

  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  static double getResponsiveFontSize(BuildContext context, double size) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 600) {
      return size * 1.2; // Tablet
    } else if (screenWidth < 360) {
      return size * 0.9; // Small phone
    }
    return size; // Normal phone
  }

  static EdgeInsets getResponsivePadding(BuildContext context) {
    return EdgeInsets.all(isTablet(context) ? 24 : 20);
  }

  static double getResponsiveIconSize(BuildContext context, double size) {
    return isTablet(context) ? size * 1.2 : size;
  }
}