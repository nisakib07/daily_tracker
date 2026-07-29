import 'package:flutter/material.dart';

import '../../data/ai_service.dart';
import '../../data/money_chat_context.dart';
import '../../data/money_repository.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_state_widgets.dart';
import '../../shared/widgets/aurora_background.dart';

Future<void> showMoneyChatSheet({
  required BuildContext context,
  required DashboardSnapshot snapshot,
  AiService? aiService,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) =>
          MoneyChatSheet(snapshot: snapshot, aiService: aiService),
    ),
  );
}

class MoneyChatSheet extends StatefulWidget {
  const MoneyChatSheet({super.key, required this.snapshot, this.aiService});

  final DashboardSnapshot snapshot;
  final AiService? aiService;

  @override
  State<MoneyChatSheet> createState() => _MoneyChatSheetState();
}

/// role is 'user', 'assistant', or 'error' - an 'error' entry is a system
/// failure notice, never a fabricated assistant reply, since there's no
/// local fallback for an open-ended question.
class _ChatEntry {
  const _ChatEntry({required this.role, required this.text});

  final String role;
  final String text;
}

class _MoneyChatSheetState extends State<MoneyChatSheet> {
  late final AiService _aiService = widget.aiService ?? AiService();
  late final MoneyChatContext _chatContext = buildMoneyChatContext(
    snapshot: widget.snapshot,
  );
  final _entries = <_ChatEntry>[];
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _isSending) return;

    final priorTurns = _entries
        .where((entry) => entry.role == 'user' || entry.role == 'assistant')
        .map((entry) => AiChatTurn(role: entry.role, text: entry.text))
        .toList();
    if (priorTurns.length > 10) {
      priorTurns.removeRange(0, priorTurns.length - 10);
    }

    setState(() {
      _entries.add(_ChatEntry(role: 'user', text: question));
      _isSending = true;
    });
    _controller.clear();

    try {
      final answer = await _aiService.askAboutMoney(
        question: question,
        context: _chatContext,
        history: priorTurns,
      );
      if (!mounted) return;
      setState(() {
        _entries.add(_ChatEntry(role: 'assistant', text: answer));
        _isSending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _entries.add(_ChatEntry(role: 'error', text: error.toString()));
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Ask Your Money'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: _entries.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: AppEmptyState(
                              icon: Icons.auto_awesome_outlined,
                              title: 'Ask about your money',
                              message:
                                  'Try: "How much did I spend on transport last month?"',
                              color: AppTheme.neonCyan,
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: const ValueKey('money-chat-list'),
                          padding: const EdgeInsets.all(16),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) =>
                              _ChatBubble(entry: _entries[index]),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('money-chat-input'),
                          controller: _controller,
                          enabled: !_isSending,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: 'Ask a question…',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const ValueKey('money-chat-send'),
                        onPressed: _isSending ? null : _send,
                        icon: _isSending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.entry});

  final _ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.role == 'error') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppInlineNotice(
          icon: Icons.info_outline,
          message: entry.text,
          color: AppTheme.neonAmber,
        ),
      );
    }

    final isUser = entry.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.neonEmerald.withValues(alpha: 0.16)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isUser
                ? AppTheme.neonEmerald.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(entry.text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
