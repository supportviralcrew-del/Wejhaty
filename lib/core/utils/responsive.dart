import 'dart:io';
import 'package:flutter/material.dart';

enum ScreenSize { mobile, tablet, desktop, largeDesktop }

abstract final class Responsive {
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  static const double largeDesktopBreakpoint = 1600;
  static const double maxContentWidth = 1400;

  static ScreenSize screenSizeOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= largeDesktopBreakpoint) return ScreenSize.largeDesktop;
    if (width >= desktopBreakpoint) return ScreenSize.desktop;
    if (width >= tabletBreakpoint) return ScreenSize.tablet;
    return ScreenSize.mobile;
  }

  static bool isMobile(BuildContext context) =>
      screenSizeOf(context) == ScreenSize.mobile;

  static bool isTablet(BuildContext context) =>
      screenSizeOf(context) == ScreenSize.tablet;

  static bool isDesktop(BuildContext context) =>
      screenSizeOf(context) == ScreenSize.desktop ||
      screenSizeOf(context) == ScreenSize.largeDesktop;

  static bool isLargeDesktop(BuildContext context) =>
      screenSizeOf(context) == ScreenSize.largeDesktop;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static bool isCompactHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 700;

  static bool isPortrait(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.portrait;

  static bool isChromebook() {
    if (!Platform.isAndroid) return false;
    try {
      return Platform.environment.containsKey('CHROMEBOOK');
    } catch (_) {
      return false;
    }
  }

  static double horizontalPadding(BuildContext context) {
    final size = screenSizeOf(context);
    final width = MediaQuery.sizeOf(context).width;
    return switch (size) {
      ScreenSize.mobile => width < 360 ? 16 : 20,
      ScreenSize.tablet => 32,
      ScreenSize.desktop => 48,
      ScreenSize.largeDesktop => 64,
    };
  }

  static int gridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= largeDesktopBreakpoint) return 5;
    if (width >= desktopBreakpoint) return 4;
    if (width >= tabletBreakpoint) return 3;
    if (width >= mobileBreakpoint) return 2;
    return 2;
  }

  static double gridChildAspectRatio(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= largeDesktopBreakpoint) return 1.3;
    if (width >= desktopBreakpoint) return 1.2;
    if (width >= tabletBreakpoint) return 1.15;
    if (width < 360) return 0.92;
    return width > 420 ? 1.16 : 1.02;
  }

  static double scaledFontSize(BuildContext context, double base) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= largeDesktopBreakpoint) return base * 1.15;
    if (width >= desktopBreakpoint) return base * 1.1;
    if (isCompactHeight(context)) return base * 0.9;
    return base;
  }

  static double illustrationHeight(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    if (isWide(context)) return height * 0.85;
    if (isCompactHeight(context)) return height * 0.26;
    return height * 0.32;
  }

  static double adaptiveSpacing(BuildContext context, double base) {
    final size = screenSizeOf(context);
    return switch (size) {
      ScreenSize.mobile => base,
      ScreenSize.tablet => base * 1.2,
      ScreenSize.desktop => base * 1.4,
      ScreenSize.largeDesktop => base * 1.6,
    };
  }

  static double adaptiveIconSize(BuildContext context, double base) {
    final size = screenSizeOf(context);
    return switch (size) {
      ScreenSize.mobile => base,
      ScreenSize.tablet => base * 1.1,
      ScreenSize.desktop => base * 1.2,
      ScreenSize.largeDesktop => base * 1.3,
    };
  }
}

class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Responsive.maxContentWidth,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
