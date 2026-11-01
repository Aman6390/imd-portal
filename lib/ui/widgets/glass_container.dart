import 'dart:ui';
import 'package:flutter/material.dart';

/// Apple iOS Liquid Glass Container (Frosted Glassmorphism).
/// Features hardware-accelerated BackdropFilter blur, specular highlight borders,
/// directional translucent gradients, and ambient refraction shadows.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final double borderOpacity;
  final double surfaceOpacity;
  final VoidCallback? onTap;

  const GlassContainer({
    Key? key,
    required this.child,
    this.borderRadius = 20,
    this.blur = 18,
    this.padding,
    this.margin,
    this.tintColor,
    this.borderOpacity = 0.14,
    this.surfaceOpacity = 0.08,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        (tintColor ?? Colors.white).withOpacity(surfaceOpacity * 1.6),
                        (tintColor ?? Colors.white).withOpacity(surfaceOpacity * 0.6),
                      ]
                    : [
                        (tintColor ?? Colors.white).withOpacity(0.75),
                        (tintColor ?? Colors.white).withOpacity(0.45),
                      ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(borderOpacity)
                    : Colors.white.withOpacity(0.6),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: (tintColor ?? Colors.white).withOpacity(isDark ? 0.03 : 0.2),
                  blurRadius: 1,
                  offset: const Offset(-0.5, -0.5),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
