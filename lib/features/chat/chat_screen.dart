import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
// Sprint 3 — Voice Input
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants.dart';
import '../../shared/widgets/widgets.dart';
import '../home/providers/document_provider.dart';
import '../notebooks/providers/notebook_provider.dart';
import 'providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatProvider>().loadHistory();
        context.read<DocumentProvider>().loadDocuments();
        context.read<NotebookProvider>().loadNotebooks();
      }
    });
  }

  void _handleSend(BuildContext context) {
    if (_controller.text.trim().isEmpty) return;
    context.read<ChatProvider>().sendMessage(_controller.text);
    _controller.clear();
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: AppMotion.normal,
          curve: AppMotion.curve,
        );
      }
    });
  }

  /// Bottom sheet chọn tài liệu / notebook làm ngữ cảnh hỏi đáp.
  void _showContextPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final docs = ctx.read<DocumentProvider>().documents;
        final notebooks = ctx.read<NotebookProvider>().notebooks;
        final chatProvider = ctx.read<ChatProvider>();

        return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  children: [
                    Text(
                      'Chọn nguồn hỏi đáp',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (chatProvider.activeDocId != null ||
                        chatProvider.activeNotebookId != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          chatProvider.clearActiveContext();
                        },
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Bỏ chọn'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    // ── Notebooks ────────────────────────────────────────
                    if (notebooks.isNotEmpty) ...[
                      _PickerSectionHeader(
                        icon: Icons.auto_stories_rounded,
                        label: 'Notebooks',
                      ),
                      ...notebooks.map((nb) {
                        final nbColor = nb.flutterColor;
                        final isActive =
                            chatProvider.activeNotebookId == nb.id;
                        return _PickerTile(
                          isActive: isActive,
                          leading: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: nbColor.withValues(alpha: 0.15),
                              borderRadius: AppRadius.control,
                            ),
                            child: Icon(Icons.auto_stories_rounded,
                                size: 18, color: nbColor),
                          ),
                          title: nb.name,
                          subtitle: nb.summary.isNotEmpty
                              ? nb.summary
                              : '${nb.suggestions.length} gợi ý AI',
                          onTap: () {
                            Navigator.pop(ctx);
                            chatProvider.setActiveNotebook(nb.id,
                                notebookName: nb.name);
                          },
                        );
                      }),
                      const SizedBox(height: 8),
                    ],

                    // ── Tài liệu ─────────────────────────────────────────
                    _PickerSectionHeader(
                      icon: Icons.article_outlined,
                      label: 'Tài liệu',
                    ),
                    if (docs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Text(
                          'Chưa có tài liệu nào. Hãy tải lên trước.',
                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      )
                    else
                      ...docs.map((doc) {
                        final isActive = chatProvider.activeDocId == doc.id;
                        return _PickerTile(
                          isActive: isActive,
                          leading: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: (doc.type == 'pdf'
                                      ? AppColors.documentPdf
                                      : AppColors.documentSlide)
                                  .withValues(alpha: 0.12),
                              borderRadius: AppRadius.control,
                            ),
                            child: Icon(
                              doc.type == 'pdf'
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.slideshow_rounded,
                              size: 18,
                              color: doc.type == 'pdf'
                                  ? AppColors.documentPdf
                                  : AppColors.documentSlide,
                            ),
                          ),
                          title: doc.title,
                          subtitle: '${doc.pageCount} trang · ${doc.shortTime}',
                          onTap: () {
                            Navigator.pop(ctx);
                            chatProvider.setActiveDoc(doc.id,
                                docTitle: doc.title);
                          },
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.messages;
    final isTyping = chatProvider.isTyping;
    final isLoadingHistory = chatProvider.isLoadingHistory;
    final horizontalPadding = AppBreakpoints.horizontalPadding(context);

    // Hiển thị welcome hero khi chỉ có 1 tin nhắn chào (và chưa chọn ngữ cảnh)
    final hasContext = chatProvider.activeDocId != null ||
        chatProvider.activeNotebookId != null;
    final showWelcome =
        !isLoadingHistory && messages.length == 1 && !hasContext;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F8FE),
      endDrawer: _buildConversationsDrawer(context),

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient AI icon
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'SmartDoc AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          chatProvider.activeNotebookName != null
                              ? '📚 ${chatProvider.activeNotebookName!}'
                              : chatProvider.activeDocTitle != null
                                  ? '📄 ${chatProvider.activeDocTitle!}'
                                  : 'Đang hoạt động',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: chatProvider.activeNotebookName != null ||
                                    chatProvider.activeDocTitle != null
                                ? AppColors.primary
                                : const Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded,
                color: AppColors.textSecondary, size: 22),
            tooltip: 'Hội thoại',
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),

      // ── Body ────────────────────────────────────────────────────────────────
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: showWelcome
                  ? _buildWelcomeState(context)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: isLoadingHistory
                          ? 3
                          : messages.length + (isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (isLoadingHistory) {
                          return ChatBubbleSkeleton(isUser: index == 1)
                              .appEntrance(
                                  delay: AppMotion.stagger(index));
                        }
                        if (index == messages.length && isTyping) {
                          return const TypingIndicator();
                        }
                        final message = messages[index];
                        return (message.isAi
                                ? AIChatBubble(
                                    text: message.text,
                                    citations: message.citations,
                                  )
                                : UserChatBubble(text: message.text))
                            .appEntrance(
                                delay: AppMotion.stagger(index));
                      },
                    ),
            ),
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  // ── Welcome State ──────────────────────────────────────────────────────────

  Widget _buildWelcomeState(BuildContext context) {
    final suggestions = [
      ('Tóm tắt tài liệu của tôi', Icons.summarize_outlined),
      ('Tạo câu hỏi ôn tập', Icons.quiz_outlined),
      ('Giải thích khái niệm khó', Icons.lightbulb_outline_rounded),
      ('Lập kế hoạch học tập', Icons.calendar_today_outlined),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: AppBreakpoints.horizontalPadding(context),
        vertical: 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Hero icon ────────────────────────────────────────────────
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 22),

              // ── Title ────────────────────────────────────────────────────
              const Text(
                'SmartDoc AI',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Trợ lý học tập thông minh dành cho sinh viên TDMU\nHỏi bất cứ điều gì về tài liệu của bạn',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 36),

              // ── Suggested questions ──────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'GỢI Ý CÂU HỎI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textTertiary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .map((s) => _SuggestionChip(
                          text: s.$1,
                          icon: s.$2,
                          onTap: () {
                            _controller.text = s.$1;
                            _handleSend(context);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 28),

              // ── Context hint ─────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBBDEFB)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Nhấn nút + ở ô chat để chọn tài liệu hoặc notebook làm nguồn hỏi đáp chính xác hơn',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input Area (pill design) ────────────────────────────────────────────────

  Widget _buildInputArea(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final isCompact = AppBreakpoints.isCompact(context);
    final hasContext = chatProvider.activeDocId != null ||
        chatProvider.activeNotebookId != null;

    final contextLabel = chatProvider.activeNotebookName != null
        ? chatProvider.activeNotebookName!
        : chatProvider.activeDocTitle;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 12 : 16,
        10,
        isCompact ? 12 : 16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Context chip ─────────────────────────────────────────────
              if (hasContext && contextLabel != null) ...[
                GestureDetector(
                  onTap: () => _showContextPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          chatProvider.activeNotebookId != null
                              ? Icons.auto_stories_rounded
                              : Icons.article_outlined,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.52,
                          ),
                          child: Text(
                            contextLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: () => context
                              .read<ChatProvider>()
                              .clearActiveContext(),
                          child: const Icon(Icons.close_rounded,
                              size: 13, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── Pill input container ─────────────────────────────────────
              AnimatedContainer(
                duration: AppMotion.fast,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: hasContext
                        ? AppColors.primary.withValues(alpha: 0.30)
                        : const Color(0xFFDDE3EF),
                    width: hasContext ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // "+" / swap context button
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: IconButton(
                        icon: Icon(
                          hasContext
                              ? Icons.swap_horiz_rounded
                              : Icons.add_rounded,
                          color: hasContext
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 22,
                        ),
                        padding: const EdgeInsets.all(9),
                        constraints: const BoxConstraints(
                            minWidth: 42, minHeight: 42),
                        tooltip: hasContext ? 'Đổi nguồn' : 'Chọn tài liệu',
                        onPressed: () => _showContextPicker(context),
                      ),
                    ),

                    // Text field — no border, blends into pill
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _handleSend(context),
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        decoration: InputDecoration(
                          hintText: chatProvider.activeNotebookName != null
                              ? 'Hỏi về notebook...'
                              : chatProvider.activeDocTitle != null
                                  ? 'Hỏi về tài liệu...'
                                  : 'Hỏi bất kỳ điều gì...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 12),
                          hintStyle: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),

                    // Voice button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _VoiceButton(
                        onResult: (text) {
                          if (text.isEmpty) return;
                          _controller.text = text;
                          HapticFeedback.lightImpact();
                          context.read<ChatProvider>().sendMessage(text);
                          _controller.clear();
                          _scrollToBottom();
                        },
                      ),
                    ),

                    // Send button — gradient when active
                    Padding(
                      padding: const EdgeInsets.only(right: 4, bottom: 4),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, child) {
                          final hasText = value.text.trim().isNotEmpty;
                          return AnimatedContainer(
                            duration: AppMotion.fast,
                            curve: AppMotion.curve,
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: hasText
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF2196F3),
                                        Color(0xFF1565C0),
                                      ],
                                    )
                                  : null,
                              color: hasText ? null : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: hasText
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF1565C0)
                                            .withValues(alpha: 0.30),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_upward_rounded,
                                color: hasText
                                    ? Colors.white
                                    : AppColors.textTertiary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed:
                                  hasText ? () => _handleSend(context) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('Hội thoại'),
            backgroundColor: AppColors.surface,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                if (chatProvider.isLoadingConversations) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (chatProvider.conversations.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 52,
                            color: AppColors.textTertiary,
                          ),
                          AppSpacing.vMd,
                          Text(
                            'Chưa có hội thoại nào.\nUpload tài liệu để bắt đầu.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          AppSpacing.vLg,
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.go('/upload');
                            },
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Tải tài liệu lên'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => chatProvider.loadConversations(),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: chatProvider.conversations.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.border),
                    itemBuilder: (context, index) {
                      final conv = chatProvider.conversations[index];
                      final isActive = conv.docId == chatProvider.activeDocId;

                      return ListTile(
                        selected: isActive,
                        selectedTileColor:
                            AppColors.primary.withValues(alpha: 0.08),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isActive
                                    ? AppColors.primary
                                    : AppColors.textTertiary)
                                .withValues(alpha: 0.1),
                            borderRadius: AppRadius.control,
                          ),
                          child: Icon(
                            Icons.article_outlined,
                            size: 20,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        title: Text(
                          conv.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isActive
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: conv.lastMessage.isNotEmpty
                            ? Text(
                                conv.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textTertiary),
                              )
                            : null,
                        trailing: Text(
                          _formatTime(conv.updatedAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          context.read<ChatProvider>().setActiveDoc(
                                conv.docId,
                                docTitle: conv.title,
                              );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút';
    if (diff.inDays < 1) return '${diff.inHours} giờ';
    if (diff.inDays < 7) return '${diff.inDays} ngày';
    return '${dt.day}/${dt.month}';
  }
}

// =============================================================================
// VOICE BUTTON — Sprint 3: Voice Input
// Tap để bắt đầu nhận giọng nói tiếng Việt.
// Nút nhấp nháy đỏ khi đang nghe; im lặng 3s → tự dừng và gửi kết quả.
// =============================================================================

class _VoiceButton extends StatefulWidget {
  /// Callback trả về văn bản đã nhận dạng được (finalResult).
  final ValueChanged<String> onResult;

  const _VoiceButton({required this.onResult});

  @override
  State<_VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<_VoiceButton>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;

  // Animation controller cho hiệu ứng nhấp nháy khi đang nghe
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true); // tự động lặp lại
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  /// Bật/tắt voice recognition.
  Future<void> _toggle() async {
    if (_listening) {
      // Đang nghe → dừng lại
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    // Xin quyền microphone lần đầu
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cần quyền microphone để dùng tính năng giọng nói'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Khởi tạo speech engine
    final available = await _speech.initialize(
      onError: (e) {
        debugPrint('[VoiceButton] STT error: ${e.errorMsg}');
        if (mounted) setState(() => _listening = false);
      },
      onStatus: (status) {
        // done / notListening → reset trạng thái
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
    );

    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thiết bị không hỗ trợ nhận dạng giọng nói'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (mounted) setState(() => _listening = true);
    HapticFeedback.mediumImpact();

    await _speech.listen(
      onResult: (result) {
        // Chỉ xử lý khi kết quả là finalResult (người dùng đã nói xong)
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          widget.onResult(result.recognizedWords);
          if (mounted) setState(() => _listening = false);
        }
      },
      // v7.x: tất cả options gom vào SpeechListenOptions
      listenOptions: SpeechListenOptions(
        localeId: 'vi_VN',                         // tiếng Việt
        listenFor: const Duration(seconds: 30),    // tối đa 30s
        pauseFor: const Duration(seconds: 3),      // dừng sau 3s im lặng
        partialResults: false,                     // chỉ lấy finalResult
        cancelOnError: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, __) {
          // Khi đang nghe: nền đỏ nhấp nháy; khi nghỉ: trong suốt
          final bgAlpha = _listening ? (0.08 + 0.10 * _pulseCtrl.value) : 0.0;
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withValues(alpha: bgAlpha),
            ),
            child: Icon(
              _listening ? Icons.mic_rounded : Icons.mic_none_rounded,
              size: 22,
              color: _listening ? AppColors.error : AppColors.textSecondary,
            ),
          );
        },
      ),
    );
  }
}

// ── Picker widgets ─────────────────────────────────────────────────────────────

class _PickerSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PickerSectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _PickerTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: isActive,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: leading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textTertiary,
            ),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle_rounded,
              color: AppColors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

// ── Suggestion chip ─────────────────────────────────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFDDE3EF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
