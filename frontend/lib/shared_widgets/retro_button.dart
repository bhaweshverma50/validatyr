import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/custom_theme.dart';

enum RetroButtonSize { regular, small }

class RetroButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Color color;
  final bool isLoading;
  final Widget? icon;
  final RetroButtonSize size;

  const RetroButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.color = RetroTheme.pink,
    this.isLoading = false,
    this.icon,
    this.size = RetroButtonSize.regular,
  });

  @override
  State<RetroButton> createState() => _RetroButtonState();
}

class _RetroButtonState extends State<RetroButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSmall = widget.size == RetroButtonSize.small;
    final pressOffset = isSmall ? 2.0 : 4.0;
    final padding = isSmall
        ? const EdgeInsets.symmetric(vertical: 10.0, horizontal: 14.0)
        : const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0);
    final fontSize = isSmall ? 11.0 : 16.0;
    final iconSize = isSmall ? 13.0 : null; // null = use icon's own size
    final shadow = isSmall
        ? RetroTheme.shadowSmOf(context)
        : RetroTheme.shadowOf(context);
    final border = isSmall
        ? RetroTheme.mediumBorderOf(context)
        : RetroTheme.borderOf(context);

    return Semantics(
      button: true,
      enabled: !widget.isLoading,
      label: widget.isLoading ? '${widget.text}, loading' : widget.text,
      child: MouseRegion(
        cursor: widget.isLoading ? SystemMouseCursors.wait : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            if (!widget.isLoading) {
              HapticFeedback.lightImpact();
              widget.onPressed();
            }
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(
              _isPressed ? pressOffset : 0.0,
              _isPressed ? pressOffset : 0.0,
              0.0,
            ),
            decoration: BoxDecoration(
              color: _isHovered && !_isPressed
                  ? Color.lerp(widget.color, RetroColors.of(context).surface, 0.15)!
                  : widget.color,
              borderRadius: BorderRadius.circular(isSmall ? 6.0 : 8.0),
              border: border,
              boxShadow: _isPressed ? [] : shadow,
            ),
            padding: padding,
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      height: isSmall ? 16 : 24,
                      width: isSmall ? 16 : 24,
                      child: CircularProgressIndicator(
                        color: RetroTheme.onAccent,
                        strokeWidth: isSmall ? 2.0 : 3.0,
                      ),
                    )
                  : IconTheme(
                      data: IconThemeData(color: RetroTheme.onAccent, size: iconSize),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            widget.icon!,
                            SizedBox(width: isSmall ? 4 : 10),
                          ],
                          Flexible(
                            child: Text(
                              widget.text.toUpperCase(),
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w900,
                                letterSpacing: isSmall ? 0.5 : 1.0,
                                color: RetroTheme.onAccent,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
