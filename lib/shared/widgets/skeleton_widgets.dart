import 'package:flutter/material.dart';
import '../../core/constants.dart';

class Shimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const Shimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final offset = _controller.value * 2.4 - 1.2;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(offset - 1, -0.3),
              end: Alignment(offset + 1, 0.3),
              colors: [
                AppColors.surfaceVariant,
                AppColors.surfaceElevated,
                AppColors.surfaceVariant,
              ],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: borderRadius ?? AppRadius.medium,
        ),
      ),
    );
  }
}

class DocumentCardSkeleton extends StatelessWidget {
  const DocumentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPaddingCompact,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SkeletonBox(width: 42, height: 42),
              SkeletonBox(width: 26, height: 26, borderRadius: AppRadius.chip),
            ],
          ),
          const SizedBox(height: 16), // fixed height thay Spacer (tránh unbounded constraint trong SliverList)
          const SkeletonBox(height: 14),
          AppSpacing.vSm,
          const SkeletonBox(width: 120, height: 14),
          AppSpacing.vMd,
          const SkeletonBox(width: 88, height: 12),
          AppSpacing.vXs,
          const SkeletonBox(width: 72, height: 12),
        ],
      ),
    );
  }
}

class ChatBubbleSkeleton extends StatelessWidget {
  final bool isUser;

  const ChatBubbleSkeleton({super.key, this.isUser = false});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final longLine = screenWidth < 380 ? 170.0 : 260.0;
    final mediumLine = screenWidth < 380 ? 140.0 : 220.0;
    final shortLine = screenWidth < 380 ? 96.0 : 160.0;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceElevated,
        borderRadius: AppRadius.card.copyWith(
          topLeft: isUser ? AppRadius.card.topLeft : AppRadius.bubbleTail,
          topRight: isUser ? AppRadius.bubbleTail : AppRadius.card.topRight,
        ),
        border: Border.all(
          color: isUser ? AppColors.primaryContainer : AppColors.border,
        ),
        boxShadow: isUser ? [] : AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: longLine, height: 14),
          AppSpacing.vSm,
          SkeletonBox(width: mediumLine, height: 14),
          AppSpacing.vSm,
          SkeletonBox(width: shortLine, height: 14),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            SkeletonBox(width: 32, height: 32, borderRadius: AppRadius.chip),
            AppSpacing.hMd,
          ],
          Flexible(child: bubble),
          if (isUser) ...[
            AppSpacing.hMd,
            SkeletonBox(width: 32, height: 32, borderRadius: AppRadius.chip),
          ],
        ],
      ),
    );
  }
}

class AIProcessingLoader extends StatelessWidget {
  final String message;
  final String detail;

  const AIProcessingLoader({
    super.key,
    this.message = 'SmartDoc AI is thinking',
    this.detail = 'Reading context and preparing a grounded answer',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: AppRadius.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AIPulse(),
          AppSpacing.hMd,
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.vXs,
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                AppSpacing.vMd,
                SkeletonBox(
                  width: 180,
                  height: 8,
                  borderRadius: AppRadius.chip,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AIPulse extends StatefulWidget {
  const _AIPulse();

  @override
  State<_AIPulse> createState() => _AIPulseState();
}

class _AIPulseState extends State<_AIPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Shimmer(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: AppRadius.control,
            boxShadow: AppShadows.soft,
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}
