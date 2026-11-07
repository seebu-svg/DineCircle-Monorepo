import 'package:flutter/material.dart';

/// DineCircle Partner design system, colour palette.
///
/// Identical tokens to the customer app so both clients read as one product:
/// near-black surfaces, warm amber primary, gold secondary.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bg = Color(0xFF0A090C);
  static const Color surface = Color(0xFF131116);
  static const Color surfaceElevated = Color(0xFF1B181F);
  static const Color surfaceHigh = Color(0xFF232028);

  // Borders
  static const Color border = Color(0xFF272430);
  static const Color borderLight = Color(0xFF3A3642);

  // Primary accent, warm amber/ember
  static const Color primary = Color(0xFFFF8A3D);
  static const Color primaryLight = Color(0xFFFFB347);
  static const Color primaryDark = Color(0xFFE67A2E);

  // Gold accent
  static const Color gold = Color(0xFFE9B872);
  static const Color goldLight = Color(0xFFF5D4A0);

  // Text
  static const Color textPrimary = Color(0xFFF5F3F0);
  static const Color textSecondary = Color(0xFF9A95A3);
  static const Color textTertiary = Color(0xFF6B6670);
  static const Color textDisabled = Color(0xFF4A4550);

  // Status
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFFF5C5C);
  static const Color info = Color(0xFF60A5FA);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [gold, goldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [surface, surfaceElevated],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Brand
  static const Color brandNavy = Color(0xFF08192C);
  static const Color scrim = Color(0x80000000);
  static const Color surfaceSunken = Color(0xFF0E0C10);

  // Chart palette, ordered so the first colour is the primary series.
  static const List<Color> chartPalette = [
    primary,
    gold,
    success,
    info,
    danger,
  ];

  /// Maps a server status string (reservation, event, deal, payout, ticket) to
  /// one consistent colour so the same state never looks different per screen.
  static Color forStatus(String status) {
    switch (status) {
      case 'confirmed':
      case 'active':
      case 'verified':
      case 'paid':
      case 'completed':
      case 'approved':
      case 'seated':
        return success;
      case 'pending':
      case 'pending_review':
      case 'requested':
      case 'draft':
      case 'paused':
      case 'unverified':
      case 'invited':
        return warning;
      case 'declined':
      case 'rejected':
      case 'cancelled':
      case 'no_show':
      case 'expired':
        return danger;
      case 'live':
      case 'open':
        return info;
      default:
        return textSecondary;
    }
  }
}
