import 'package:flutter/material.dart';
import 'package:medicare_ai/widgets/theme_scope.dart';

/// Animated light/dark switch with sliding thumb and sun / moon icons.
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key, this.size = 1.0});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = ThemeScope.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final isDark = c.isDark;
        return Semantics(
          label: isDark
              ? 'Theme: dark. Activate to use light mode.'
              : 'Theme: light. Activate to use dark mode.',
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => c.toggle(),
              borderRadius: BorderRadius.circular(32),
              child: SizedBox(
                width: 72 * size,
                height: 40 * size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeInOutCubic,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: isDark
                            ? const Color(0xFF1E1E2A)
                            : cs.secondaryContainer.withValues(alpha: 0.55),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.45),
                          width: 1,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12 * size,
                      child: Icon(
                        Icons.light_mode_rounded,
                        size: 18 * size,
                        color: cs.onSurfaceVariant.withValues(
                          alpha: isDark ? 0.22 : 0.88,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12 * size,
                      child: Icon(
                        Icons.dark_mode_rounded,
                        size: 18 * size,
                        color: cs.onSurfaceVariant.withValues(
                          alpha: isDark ? 0.9 : 0.22,
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeInOutCubicEmphasized,
                      alignment:
                          isDark ? Alignment.centerRight : Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4 * size),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          width: 32 * size,
                          height: 32 * size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? const Color(0xFF2A2540) : Colors.white,
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) {
                              return RotationTransition(
                                turns: Tween<double>(begin: 0.15, end: 1.0)
                                    .animate(anim),
                                child: FadeTransition(
                                  opacity: anim,
                                  child: child,
                                ),
                              );
                            },
                            child: Icon(
                              isDark
                                  ? Icons.nights_stay_rounded
                                  : Icons.wb_sunny_rounded,
                              key: ValueKey<bool>(isDark),
                              size: 20 * size,
                              color: isDark
                                  ? const Color(0xFFB8A8FF)
                                  : const Color(0xFF916CF2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Compact icon control for dense app bars.
class ThemeModeIconButton extends StatelessWidget {
  const ThemeModeIconButton({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = ThemeScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return IconButton.filledTonal(
          onPressed: () => c.toggle(),
          style: IconButton.styleFrom(
            backgroundColor:
                cs.secondaryContainer.withValues(alpha: 0.45),
            foregroundColor: cs.onSurface,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.all(10),
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              return RotationTransition(
                turns: Tween<double>(begin: 0.82, end: 1.0).animate(anim),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.0).animate(anim),
                  child: child,
                ),
              );
            },
            child: Icon(
              c.isDark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
              key: ValueKey<bool>(c.isDark),
              size: size,
            ),
          ),
        );
      },
    );
  }
}
