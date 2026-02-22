import 'package:flutter/material.dart';
import '../core/theme/custom_theme.dart';

class RetroButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final bool isLoading;
  final Widget? icon;

  const RetroButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = RetroTheme.pink,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isLoading ? SystemMouseCursors.wait : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          if (!widget.isLoading) {
            widget.onPressed();
          }
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(
            _isPressed ? 4.0 : 0.0,
            _isPressed ? 4.0 : 0.0,
            0.0,
          ),
          decoration: BoxDecoration(
            color: _isHovered && !_isPressed
                ? Color.lerp(widget.color, Colors.white, 0.15)!
                : widget.color,
            borderRadius: BorderRadius.circular(8.0),
            border: RetroTheme.thickerBorder,
            boxShadow: _isPressed ? [] : RetroTheme.sharpShadow,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 3.0,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        widget.icon!,
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.text.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
