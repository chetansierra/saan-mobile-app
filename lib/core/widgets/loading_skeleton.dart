import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Shimmer loading skeleton for better perceived performance
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
    this.direction = ShimmerDirection.ltr,
    this.period = const Duration(milliseconds: 1500),
  });

  /// Child widget to show shimmer effect on
  final Widget child;

  /// Whether shimmer is enabled
  final bool enabled;

  /// Base color for shimmer
  final Color? baseColor;

  /// Highlight color for shimmer
  final Color? highlightColor;

  /// Direction of shimmer animation
  final ShimmerDirection direction;

  /// Duration of one shimmer cycle
  final Duration period;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.period,
      vsync: this,
    );

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(LoadingSkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final baseColor = widget.baseColor ?? 
        (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final highlightColor = widget.highlightColor ?? 
        (isDark ? Colors.grey[700]! : Colors.grey[100]!);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.1, 0.3, 0.4],
              begin: _getGradientBegin(),
              end: _getGradientEnd(),
              transform: _SlideGradientTransform(
                slidePercent: _controller.value,
                direction: widget.direction,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }

  Alignment _getGradientBegin() {
    switch (widget.direction) {
      case ShimmerDirection.ltr:
        return Alignment.centerLeft;
      case ShimmerDirection.rtl:
        return Alignment.centerRight;
      case ShimmerDirection.ttb:
        return Alignment.topCenter;
      case ShimmerDirection.btt:
        return Alignment.bottomCenter;
    }
  }

  Alignment _getGradientEnd() {
    switch (widget.direction) {
      case ShimmerDirection.ltr:
        return Alignment.centerRight;
      case ShimmerDirection.rtl:
        return Alignment.centerLeft;
      case ShimmerDirection.ttb:
        return Alignment.bottomCenter;
      case ShimmerDirection.btt:
        return Alignment.topCenter;
    }
  }
}

/// Shimmer direction enumeration
enum ShimmerDirection {
  ltr, // Left to right
  rtl, // Right to left
  ttb, // Top to bottom
  btt, // Bottom to top
}

/// Gradient transform for shimmer animation
class _SlideGradientTransform extends GradientTransform {
  const _SlideGradientTransform({
    required this.slidePercent,
    required this.direction,
  });

  final double slidePercent;
  final ShimmerDirection direction;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    switch (direction) {
      case ShimmerDirection.ltr:
        return Matrix4.translationValues(
          (bounds.width * 2 * slidePercent) - bounds.width,
          0.0,
          0.0,
        );
      case ShimmerDirection.rtl:
        return Matrix4.translationValues(
          bounds.width - (bounds.width * 2 * slidePercent),
          0.0,
          0.0,
        );
      case ShimmerDirection.ttb:
        return Matrix4.translationValues(
          0.0,
          (bounds.height * 2 * slidePercent) - bounds.height,
          0.0,
        );
      case ShimmerDirection.btt:
        return Matrix4.translationValues(
          0.0,
          bounds.height - (bounds.height * 2 * slidePercent),
          0.0,
        );
    }
  }
}

/// Pre-built skeleton components for common use cases
class SkeletonComponents {
  const SkeletonComponents._();

  /// Skeleton for text lines
  static Widget text({
    double? width,
    double height = 16,
    BorderRadius? borderRadius,
  }) {
    return LoadingSkeleton(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(4),
        ),
      ),
    );
  }

  /// Skeleton for avatar/profile pictures
  static Widget avatar({
    double size = 48,
    BoxShape shape = BoxShape.circle,
  }) {
    return LoadingSkeleton(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: shape,
          borderRadius: shape == BoxShape.rectangle 
              ? BorderRadius.circular(8)
              : null,
        ),
      ),
    );
  }

  /// Skeleton for rectangular containers
  static Widget container({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return LoadingSkeleton(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Skeleton for list tiles
  static Widget listTile({
    bool hasLeading = true,
    bool hasTrailing = false,
    int titleLines = 1,
    int subtitleLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      child: Row(
        children: [
          // Leading (avatar)
          if (hasLeading) ...[
            avatar(size: 48),
            const SizedBox(width: AppTheme.spacingM),
          ],
          
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title lines
                for (int i = 0; i < titleLines; i++) ...[
                  text(
                    width: i == titleLines - 1 ? 120 : double.infinity,
                    height: 18,
                  ),
                  if (i < titleLines - 1) const SizedBox(height: 4),
                ],
                
                // Spacing between title and subtitle
                if (subtitleLines > 0) const SizedBox(height: 8),
                
                // Subtitle lines
                for (int i = 0; i < subtitleLines; i++) ...[
                  text(
                    width: i == subtitleLines - 1 ? 80 : double.infinity,
                    height: 14,
                  ),
                  if (i < subtitleLines - 1) const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          
          // Trailing
          if (hasTrailing) ...[
            const SizedBox(width: AppTheme.spacingM),
            container(width: 24, height: 24),
          ],
        ],
      ),
    );
  }

  /// Skeleton for cards
  static Widget card({
    double? height,
    int titleLines = 2,
    int bodyLines = 3,
    bool hasImage = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingM),
      child: LoadingSkeleton(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                if (hasImage) ...[
                  container(
                    width: double.infinity,
                    height: 160,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                ],
                
                // Title lines
                for (int i = 0; i < titleLines; i++) ...[
                  text(
                    width: i == titleLines - 1 ? 160 : double.infinity,
                    height: 18,
                  ),
                  if (i < titleLines - 1) const SizedBox(height: 4),
                ],
                
                const SizedBox(height: AppTheme.spacingM),
                
                // Body lines
                for (int i = 0; i < bodyLines; i++) ...[
                  text(
                    width: i == bodyLines - 1 ? 120 : double.infinity,
                    height: 14,
                  ),
                  if (i < bodyLines - 1) const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Skeleton for form fields
  static Widget formField({
    String? label,
    double height = 56,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          text(width: 80, height: 14),
          const SizedBox(height: AppTheme.spacingS),
        ],
        container(
          width: double.infinity,
          height: height,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
      ],
    );
  }

  /// Skeleton for buttons
  static Widget button({
    double? width,
    double height = 48,
  }) {
    return LoadingSkeleton(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
      ),
    );
  }
}

/// Pre-built skeleton layouts for entire screens
class SkeletonLayouts {
  const SkeletonLayouts._();

  /// Skeleton for list screen
  static Widget listScreen({int itemCount = 8}) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonComponents.listTile(
        hasLeading: true,
        hasTrailing: true,
        titleLines: 1,
        subtitleLines: 2,
      ),
    );
  }

  /// Skeleton for grid screen
  static Widget gridScreen({
    int itemCount = 12,
    int crossAxisCount = 2,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.75,
        crossAxisSpacing: AppTheme.spacingM,
        mainAxisSpacing: AppTheme.spacingM,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonComponents.card(
        titleLines: 2,
        bodyLines: 2,
        hasImage: true,
      ),
    );
  }

  /// Skeleton for detail screen
  static Widget detailScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header image
          SkeletonComponents.container(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Title
          SkeletonComponents.text(width: 250, height: 24),
          
          const SizedBox(height: AppTheme.spacingS),
          
          // Subtitle
          SkeletonComponents.text(width: 180, height: 16),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Content blocks
          for (int i = 0; i < 3; i++) ...[
            SkeletonComponents.container(
              width: double.infinity,
              height: 120,
              borderRadius: BorderRadius.circular(AppTheme.radiusS),
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: SkeletonComponents.button(height: 48),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: SkeletonComponents.button(height: 48),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Skeleton for form screen
  static Widget formScreen({int fieldCount = 6}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form title
          SkeletonComponents.text(width: 200, height: 24),
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Form fields
          for (int i = 0; i < fieldCount; i++) ...[
            SkeletonComponents.formField(label: 'Field $i'),
            const SizedBox(height: AppTheme.spacingM),
          ],
          
          const SizedBox(height: AppTheme.spacingL),
          
          // Submit button
          SkeletonComponents.button(
            width: double.infinity,
            height: 48,
          ),
        ],
      ),
    );
  }
}