import 'package:flutter/material.dart';
import '../core/theme/custom_theme.dart';

/// A shimmering placeholder that matches RetroCard dimensions.
/// Use as loading state in list views to indicate content shape.
class RetroSkeletonCard extends StatefulWidget {
  final int lineCount;
  final bool showAvatar;

  const RetroSkeletonCard({
    super.key,
    this.lineCount = 3,
    this.showAvatar = true,
  });

  @override
  State<RetroSkeletonCard> createState() => _RetroSkeletonCardState();
}

class _RetroSkeletonCardState extends State<RetroSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = RetroColors.of(context);
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) {
        final shimmerColor = Color.lerp(
          colors.borderSubtle,
          colors.surface,
          _shimmer.value,
        )!;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(RetroTheme.radiusLg),
            border: Border.all(color: colors.borderSubtle, width: RetroTheme.borderWidthMedium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showAvatar) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(RetroTheme.radiusMd),
                  ),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title bar
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Content lines
                    for (int i = 0; i < widget.lineCount; i++) ...[
                      Container(
                        height: 10,
                        width: i == widget.lineCount - 1
                            ? MediaQuery.of(context).size.width * 0.4
                            : double.infinity,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      if (i < widget.lineCount - 1) const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A loading state that displays multiple skeleton cards.
class RetroSkeletonList extends StatelessWidget {
  final int itemCount;
  final int lineCount;
  final bool showAvatar;

  const RetroSkeletonList({
    super.key,
    this.itemCount = 4,
    this.lineCount = 2,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: RetroTheme.contentPaddingMobile,
        vertical: RetroTheme.spacingMd,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: RetroTheme.spacingMd),
      itemBuilder: (_, __) => RetroSkeletonCard(
        lineCount: lineCount,
        showAvatar: showAvatar,
      ),
    );
  }
}
