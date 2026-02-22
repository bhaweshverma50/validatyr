import 'package:flutter/material.dart';
import '../core/theme/custom_theme.dart';

class RetroCard extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const RetroCard({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.0),
        border: RetroTheme.thickerBorder,
        boxShadow: RetroTheme.sharpShadow,
      ),
      padding: padding,
      child: child,
    );
  }
}
