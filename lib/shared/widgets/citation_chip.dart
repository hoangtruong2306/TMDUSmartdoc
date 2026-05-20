import 'package:flutter/material.dart';
import '../../core/constants.dart';

class CitationData {
  final String label;
  final String value;
  final String snippet;
  final String filename;

  CitationData(
    this.label,
    this.value, {
    this.snippet = '',
    this.filename = '',
  });
}

class CitationChip extends StatefulWidget {
  final CitationData citation;

  const CitationChip({super.key, required this.citation});

  @override
  State<CitationChip> createState() => _CitationChipState();
}

class _CitationChipState extends State<CitationChip> {
  bool _isPressed = false;

  void _showSnippet() {
    if (widget.citation.snippet.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.format_quote_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  widget.citation.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                if (widget.citation.value.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    'tr. ${widget.citation.value}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
                if (widget.citation.filename.isNotEmpty) ...[
                  const Spacer(),
                  Flexible(
                    child: Text(
                      widget.citation.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                widget.citation.snippet,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSnippet = widget.citation.snippet.isNotEmpty;
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _showSnippet();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.diagonal3Values(
          _isPressed ? 0.93 : 1.0,
          _isPressed ? 0.93 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.only(left: 4, right: 10, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.chip,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.chip,
              ),
              child: Text(
                widget.citation.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.citation.value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            if (hasSnippet) ...[
              const SizedBox(width: 3),
              const Icon(Icons.expand_more_rounded,
                  size: 12, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}
