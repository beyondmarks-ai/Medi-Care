import 'package:flutter/material.dart';

/// Semantic colors for Medicare AI (dock, CTA, badges) in light and dark.
@immutable
class PortalThemeX extends ThemeExtension<PortalThemeX> {
  const PortalThemeX({
    required this.dock,
    required this.ctaStart,
    required this.ctaEnd,
    required this.verifiedBackground,
    required this.subtleCardShadow,
    required this.onDockIcon,
  });

  final Color dock;
  final Color ctaStart;
  final Color ctaEnd;
  final Color verifiedBackground;
  final Color subtleCardShadow;
  final Color onDockIcon;

  static const light = PortalThemeX(
    dock: Color(0xFF2B1B4A),
    ctaStart: Color(0xFFC7A7FF),
    ctaEnd: Color(0xFF916CF2),
    verifiedBackground: Color(0xFFF2F8EE),
    subtleCardShadow: Color(0x0F000000),
    onDockIcon: Color(0xFFFFFFFF),
  );

  static const dark = PortalThemeX(
    dock: Color(0xFF12081F),
    ctaStart: Color(0xFF7A5FCC),
    ctaEnd: Color(0xFF5A3DAD),
    verifiedBackground: Color(0xFF15261A),
    subtleCardShadow: Color(0x2EFFFFFF),
    onDockIcon: Color(0xE6FFFFFF),
  );

  @override
  PortalThemeX copyWith({
    Color? dock,
    Color? ctaStart,
    Color? ctaEnd,
    Color? verifiedBackground,
    Color? subtleCardShadow,
    Color? onDockIcon,
  }) {
    return PortalThemeX(
      dock: dock ?? this.dock,
      ctaStart: ctaStart ?? this.ctaStart,
      ctaEnd: ctaEnd ?? this.ctaEnd,
      verifiedBackground: verifiedBackground ?? this.verifiedBackground,
      subtleCardShadow: subtleCardShadow ?? this.subtleCardShadow,
      onDockIcon: onDockIcon ?? this.onDockIcon,
    );
  }

  @override
  PortalThemeX lerp(ThemeExtension<PortalThemeX>? other, double t) {
    if (other is! PortalThemeX) return this;
    return PortalThemeX(
      dock: Color.lerp(dock, other.dock, t)!,
      ctaStart: Color.lerp(ctaStart, other.ctaStart, t)!,
      ctaEnd: Color.lerp(ctaEnd, other.ctaEnd, t)!,
      verifiedBackground: Color.lerp(verifiedBackground, other.verifiedBackground, t)!,
      subtleCardShadow: Color.lerp(subtleCardShadow, other.subtleCardShadow, t)!,
      onDockIcon: Color.lerp(onDockIcon, other.onDockIcon, t)!,
    );
  }
}

extension PortalThemeXBuildContext on BuildContext {
  PortalThemeX get portalX =>
      Theme.of(this).extension<PortalThemeX>() ?? PortalThemeX.light;
  ColorScheme get medicareColorScheme => Theme.of(this).colorScheme;
}
