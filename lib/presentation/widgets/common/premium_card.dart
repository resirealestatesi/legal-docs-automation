import 'package:flutter/material.dart';
import '../../../config/theme/app_colors.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? color;
  final List<BoxShadow>? shadows;
  final BorderSide? border;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
    this.color,
    this.shadows,
    this.border,
    this.margin,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color ?? (isDark ? AppColors.darkSurface : AppColors.surface),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: border?.color ?? (isDark ? AppColors.darkBorder : AppColors.border),
          width: border?.width ?? 1,
        ),
        boxShadow: shadows ?? [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.blueGrey).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}
