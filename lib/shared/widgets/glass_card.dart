import 'package:flutter/material.dart';

/// SınıfCepte - Yüksek Performanslı Modern Kart Bileşeni (Sıfır Klavye Kasmama Garantili)
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 18.0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardDecoration = BoxDecoration(
      color: isDark
          ? const Color(0xFF1E293B)
          : Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? const Color(0xFF334155)
            : const Color(0xFFE2E8F0),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 3),
        ),
      ],
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        decoration: cardDecoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(borderRadius),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      margin: margin,
      decoration: cardDecoration,
      child: child,
    );
  }
}
