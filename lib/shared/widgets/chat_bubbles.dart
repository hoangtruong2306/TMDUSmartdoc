import 'package:flutter/material.dart';
import '../../core/constants.dart';
import 'citation_chip.dart';
import 'skeleton_widgets.dart';

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
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primaryContainer,
            radius: 16,
            child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
          ),
          AppSpacing.hMd,
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: AppRadius.card.copyWith(
                  topLeft: AppRadius.bubbleTail,
                ),
                border: Border.all(color: AppColors.border),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  if (citations.isNotEmpty) ...[
                    AppSpacing.vMd,
                    const Divider(),
                    AppSpacing.vSm,
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
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
    );
  }
}

class UserChatBubble extends StatelessWidget {
  final String text;

  const UserChatBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.card.copyWith(
                  topRight: AppRadius.bubbleTail,
                ),
              ),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  height: 1.6,
                ),
              ),
            ),
          ),
          AppSpacing.hMd,
          const CircleAvatar(
            backgroundColor: AppColors.surfaceVariant,
            radius: 16,
            child: Icon(Icons.person, color: AppColors.textSecondary, size: 16),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.primaryContainer,
            radius: 16,
            child: Icon(Icons.auto_awesome, color: AppColors.primary, size: 16),
          ),
          AppSpacing.hMd,
          const Flexible(
            child: AIProcessingLoader(
              message: 'SmartDoc AI đang xử lý',
              detail: 'Đang quét tài liệu tham khảo và soạn câu trả lời ngắn gọn',
            ),
          ),
        ],
      ),
    ).appEntrance();
  }
}
