// =============================================================================
// FLASHCARD SETUP SCREEN — Chọn số thẻ trước khi bắt đầu học
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../providers/flashcard_provider.dart';
import 'flashcard_study_screen.dart';

const _cardCounts = [10, 20, 50];

class FlashCardSetupScreen extends StatefulWidget {
  final String notebookId;
  final String notebookName;

  const FlashCardSetupScreen({
    super.key,
    required this.notebookId,
    required this.notebookName,
  });

  @override
  State<FlashCardSetupScreen> createState() => _FlashCardSetupScreenState();
}

class _FlashCardSetupScreenState extends State<FlashCardSetupScreen> {
  int _selectedNum = 10;

  void _start() {
    context.read<FlashCardProvider>().generateDeck(
      notebookId:   widget.notebookId,
      notebookName: widget.notebookName,
      numCards:     _selectedNum,
    );
  }

  @override
  void initState() {
    super.initState();
    // Listen once: khi generate xong → navigate sang Study với cùng provider
    final provider = context.read<FlashCardProvider>();
    provider.addListener(_onDeckReady);
  }

  void _onDeckReady() {
    final provider = context.read<FlashCardProvider>();
    if (provider.deck != null && !provider.isLoading && provider.error == null) {
      provider.removeListener(_onDeckReady);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: FlashCardStudyScreen(
              notebookId: widget.notebookId,
              notebookName: widget.notebookName,
            ),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    context.read<FlashCardProvider>().removeListener(_onDeckReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FlashCardProvider>();
    final isLoading = provider.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.notebookName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: isLoading
            ? _LoadingView(notebookName: widget.notebookName)
            : _SetupView(
                notebookName: widget.notebookName,
                selectedNum: _selectedNum,
                onNumChanged: (v) => setState(() => _selectedNum = v),
                onStart: _start,
                key: const ValueKey('setup'),
              ),
      ),
    );
  }
}

// ── Loading View ─────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  final String notebookName;
  const _LoadingView({required this.notebookName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI đang tạo flashcards...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Phân tích tài liệu: $notebookName',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Setup View ───────────────────────────────────────────────────────────────

class _SetupView extends StatelessWidget {
  final String notebookName;
  final int selectedNum;
  final ValueChanged<int> onNumChanged;
  final VoidCallback onStart;

  const _SetupView({
    required this.notebookName,
    required this.selectedNum,
    required this.onNumChanged,
    required this.onStart,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.style_rounded,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Học Flashcards',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI sẽ tạo thẻ ghi nhớ từ tài liệu trong notebook',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Số thẻ
          _SectionLabel(icon: Icons.style, title: 'Số lượng thẻ'),
          const SizedBox(height: 10),
          Row(
            children: _cardCounts.map((n) {
              final isSelected = n == selectedNum;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onNumChanged(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceElevated,
                        borderRadius: AppRadius.control,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Tips
          _SectionLabel(icon: Icons.lightbulb_outline_rounded, title: 'Mẹo học'),
          const SizedBox(height: 10),
          _TipItem(
            icon: Icons.flip_rounded,
            text: 'Lật thẻ để xem đáp án, đánh dấu "Đã thuộc" nếu nhớ ngay.',
          ),
          _TipItem(
            icon: Icons.replay_rounded,
            text: 'Thẻ đánh "Cần ôn lại" sẽ được ôn lại ở phần sau.',
          ),
          _TipItem(
            icon: Icons.swipe_rounded,
            text: 'Vuốt trái/phải hoặc dùng nút bấm để đánh dấu nhanh.',
          ),

          const SizedBox(height: 28),

          // Nút bắt đầu
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              'Bắt đầu học',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionLabel({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
