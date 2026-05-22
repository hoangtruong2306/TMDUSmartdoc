// =============================================================================
// FLASH CARD WIDGET — Flip animation với 3D rotation
// =============================================================================
//
// THUẬT TOÁN ANIMATION (3D Flip):
//   1. Tạo AnimationController với duration 500ms
//   2. Dùng CurvedAnimation với Curves.easeInOutCubic
//   3. Y-axis rotation: 0 → π (180°) tạo hiệu ứng lật
//   4. Dùng AnimatedBuilder rebuild widget theo từng frame
//   5. Khi angle < π/2 (đang lật nửa chừng):
//      → hiển thị MẶT TRƯỚC (front)
//   6. Khi angle ≥ π/2:
//      → hiển thị MẶT SAU (back) với rotationY = π để văn bản không bị mirror
//
// HAPTIC:
//   HapticFeedback.mediumImpact() khi lật thẻ để tăng cảm giác vật lý.
// =============================================================================

import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';

import '../../flashcards/models/flashcard_model.dart';

class FlipCardWidget extends StatefulWidget {
  final FlashCard card;
  final bool showAnswer;
  final VoidCallback onFlip;
  final Color color;

  const FlipCardWidget({
    super.key,
    required this.card,
    required this.showAnswer,
    required this.onFlip,
    required this.color,
  });

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant FlipCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showAnswer != widget.showAnswer) {
      if (widget.showAnswer) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    HapticFeedback.mediumImpact();
    widget.onFlip();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)      // perspective
              ..rotateY(angle),
            child: angle < pi / 2
                ? _buildFront()
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    return _CardContainer(
      color: widget.color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category badge
          if (widget.card.category != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.card.category!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.color,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.help_outline_rounded,
              size: 36,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 24),
          // Front text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.card.front,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nhấn để lật thẻ',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return _CardContainer(
      color: widget.color,
      isBack: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Check icon
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 32,
              color: Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 24),
          // Back text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.card.back,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.55,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (widget.card.hint != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: AppRadius.control,
                border: Border.all(
                  color: const Color(0xFFFFA726).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: const Color(0xFFFFA726),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.card.hint!,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFCA6D00),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Nhấn để quay lại',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card container ────────────────────────────────────────────────────

class _CardContainer extends StatelessWidget {
  final Color color;
  final Widget child;
  final bool isBack;

  const _CardContainer({
    required this.color,
    required this.child,
    this.isBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(minHeight: 340),
      decoration: BoxDecoration(
        gradient: isBack
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF0FDF4),
                  Colors.white,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.04),
                  Colors.white,
                ],
              ),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: isBack
              ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
              : color.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
