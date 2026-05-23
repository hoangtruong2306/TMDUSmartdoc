import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import 'citation_chip.dart';

// =============================================================================
// CHAT BUBBLES — TDMU SmartDoc redesign
// Màu chủ đạo: TDMU Blue #1565C0
// AI bubble  : nền xanh nhạt #F0F7FF, viền trái accent 3px, avatar gradient
// User bubble: gradient xanh dương, đuôi bubble topRight, avatar vuông
// Typing     : 3 chấm nhảy với stagger animation
// =============================================================================

// ── Gradient AI Avatar ────────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    const double size = 34;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.28),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.47),
    );
  }
}

// ── User Avatar ───────────────────────────────────────────────────────────────

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    const double size = 34;
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(Icons.person_rounded,
          color: AppColors.textSecondary, size: size * 0.52),
    );
  }
}

// ── AI Chat Bubble ────────────────────────────────────────────────────────────

class AIChatBubble extends StatelessWidget {
  final String text;
  final List<CitationData> citations;

  const AIChatBubble({
    super.key,
    required this.text,
    this.citations = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label "SmartDoc AI"
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'SmartDoc AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 5, height: 5,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bubble
                GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: text));
                    HapticFeedback.mediumImpact();
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft:     Radius.circular(4),
                      topRight:    Radius.circular(18),
                      bottomLeft:  Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F7FF),
                        borderRadius: const BorderRadius.only(
                          topLeft:     Radius.circular(4),
                          topRight:    Radius.circular(18),
                          bottomLeft:  Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                        border: Border.all(
                          color: const Color(0xFFBBDEFB),
                          width: 1,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 3,
                              color: AppColors.primary,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      text,
                                      style: const TextStyle(
                                        color: Color(0xFF1A1A2E),
                                        fontSize: 14,
                                        height: 1.65,
                                      ),
                                    ),
                                    if (citations.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 1,
                                        color: const Color(0xFFBBDEFB),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: citations
                                            .map((c) => CitationChip(citation: c))
                                            .toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Copy hint cho tin dài
                if (text.length > 120)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4),
                    child: Text(
                      'Giữ để sao chép',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── User Chat Bubble ──────────────────────────────────────────────────────────

class UserChatBubble extends StatelessWidget {
  final String text;
  const UserChatBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(18),
                  topRight:    Radius.circular(4),
                  bottomLeft:  Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const _UserAvatar(),
        ],
      ),
    );
  }
}

// ── Typing Indicator — 3 bouncing dots ───────────────────────────────────────

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AiAvatar(),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  'SmartDoc AI đang soạn...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft:     Radius.circular(4),
                  topRight:    Radius.circular(18),
                  bottomLeft:  Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F7FF),
                    borderRadius: const BorderRadius.only(
                      topLeft:     Radius.circular(4),
                      topRight:    Radius.circular(18),
                      bottomLeft:  Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: const Color(0xFFBBDEFB),
                      width: 1,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 3,
                          color: AppColors.primary,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                          child: _BouncingDots(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).appEntrance();
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(controller: _ctrl, delay: 0.00),
        const SizedBox(width: 5),
        _Dot(controller: _ctrl, delay: 0.18),
        const SizedBox(width: 5),
        _Dot(controller: _ctrl, delay: 0.36),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final AnimationController controller;
  final double delay;
  const _Dot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = ((controller.value - delay) % 1.0);
        // Half-sine curve: điểm cao nhất ở giữa chu kỳ
        final bounce = math.max(0.0, math.sin(t * math.pi)) * 6.0;
        final opacity = 0.45 + 0.55 * math.max(0.0, math.sin(t * math.pi));
        return Transform.translate(
          offset: Offset(0, -bounce),
          child: Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: opacity),
            ),
          ),
        );
      },
    );
  }
}
