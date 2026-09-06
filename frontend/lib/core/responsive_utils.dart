import 'package:flutter/material.dart';

class ResponsiveUtils {
  static const double mobileBreakpoint = 850.0;
  static const double tabletBreakpoint = 1100.0;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  static bool isMobileWidth(double width) {
    return width < mobileBreakpoint;
  }

  static T valueByBreakpoint<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return mobile;
    } else if (width < tabletBreakpoint && tablet != null) {
      return tablet;
    }
    return desktop;
  }
}

