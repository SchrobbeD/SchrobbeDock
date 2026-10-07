import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/feedback_message.dart';

class FeedbackChatWidget extends StatefulWidget {
  final String reportId;
  final bool isAdmin;
  final String? headerTitle;
  final VoidCallback? onClose;
  final VoidCallback? onReportUpdated;

  const FeedbackChatWidget({
    super.key,
    required this.reportId,
    this.isAdmin = false,
    this.headerTitle,
    this.onClose,
    this.onReportUpdated,
  });

  @override
  State<FeedbackChatWidget> createState() => _FeedbackChatWidgetState();
}

class _FeedbackChatWidgetState extends State<FeedbackChatWidget> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<FeedbackMessage> _messages = [];
  RealtimeChannel? _realtimeChannel;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeRealtime();
    _markAsRead();
  }

  @override
  void didUpdateWidget(covariant FeedbackChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reportId != widget.reportId) {
      _realtimeChannel?.unsubscribe();
      _loadMessages();
      _subscribeRealtime();
      _markAsRead();
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      await _client.rpc(
        'mark_feedback_as_read',
        params: {'target_report_id': widget.reportId},
      );
    } catch (e) {
      debugPrint('[FeedbackChatWidget] mark_feedback_as_read error: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _client
          .from('feedback_messages')
          .select()
          .eq('report_id', widget.reportId)
          .order('created_at', ascending: true);

      final loaded = (res as List<dynamic>)
          .map((m) => FeedbackMessage.fromJson(m as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() {
        _messages = loaded;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Fout bij het laden van de chat: $e';
        _isLoading = false;
      });
    }
  }

  void _subscribeRealtime() {
    final channelName = 'fb_chat_${widget.reportId}_${DateTime.now().millisecondsSinceEpoch}';
    _realtimeChannel = _client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'feedback_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'report_id',
            value: widget.reportId,
          ),
          callback: (payload) {
            final newMsg = FeedbackMessage.fromJson(payload.newRecord);
            if (!mounted) return;
            setState(() {
              if (!_messages.any((m) => m.id == newMsg.id)) {
                _messages.add(newMsg);
              }
            });
            _markAsRead();
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Je moet ingelogd zijn om te reageren.')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // 1. Probeer Edge Function send-feedback-message aan te roepen (met GitHub sync)
      bool sentViaEdge = false;
      try {
        final res = await _client.functions.invoke(
          'send-feedback-message',
          body: {
            'report_id': widget.reportId,
            'message': text,
          },
        );

        if (res.status == 200 && res.data is Map<String, dynamic>) {
          sentViaEdge = true;
          final msgData = res.data['message'];
          if (msgData is Map<String, dynamic> && mounted) {
            final newMsg = FeedbackMessage.fromJson(msgData);
            setState(() {
              if (!_messages.any((m) => m.id == newMsg.id)) {
                _messages.add(newMsg);
              }
            });
          }
        }
      } catch (edgeErr) {
        debugPrint('[FeedbackChatWidget] Edge function failed, fallback naar database: $edgeErr');
      }

      // 2. Directe fallback insert als Edge Function offline is
      if (!sentViaEdge) {
        final profileRes = await _client
            .from('profiles')
            .select('first_name, last_name, email')
            .eq('id', user.id)
            .maybeSingle();

        String senderName = 'Gebruiker';
        if (profileRes != null) {
          final first = profileRes['first_name'] as String? ?? '';
          final last = profileRes['last_name'] as String? ?? '';
          final full = '$first $last'.trim();
          senderName = full.isNotEmpty
              ? full
              : (profileRes['email'] != null
                  ? (profileRes['email'] as String).split('@').first
                  : (widget.isAdmin ? 'Beheerder' : 'Gebruiker'));
        }

        final inserted = await _client
            .from('feedback_messages')
            .insert({
              'report_id': widget.reportId,
              'sender_id': user.id,
              'sender_role': widget.isAdmin ? 'admin' : 'user',
              'sender_name': senderName,
              'message': text,
            })
            .select()
            .single();

        if (mounted) {
          final newMsg = FeedbackMessage.fromJson(inserted);
          setState(() {
            if (!_messages.any((m) => m.id == newMsg.id)) {
              _messages.add(newMsg);
            }
          });
        }
      }

      _textController.clear();
      _scrollToBottom();
      widget.onReportUpdated?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Fout bij versturen van bericht: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _focusNode.requestFocus();
      }
    }
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header indien opgegeven
          if (widget.headerTitle != null || widget.onClose != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.headerTitle ?? 'Communicatie & Chat',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.onClose != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.onClose,
                      tooltip: 'Sluiten',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

          // Berichten lijst
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 40, color: theme.colorScheme.error),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.colorScheme.error),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _loadMessages,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Opnieuw proberen'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 48,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nog geen reacties',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.isAdmin
                                        ? 'Typ hier een reactie of vraag om de melder op de hoogte te brengen.'
                                        : 'Heb je aanvullende details of vragen? Stuur hier een bericht naar de beheerder.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              return _buildMessageBubble(context, msg);
                            },
                          ),
          ),

          // Invoerveld balk
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: KeyboardListener(
                    focusNode: FocusNode(),
                    onKeyEvent: (event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _sendMessage();
                      }
                    },
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: widget.isAdmin
                            ? 'Typ een reactie als beheerder...'
                            : 'Typ een reactie of vraag...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  tooltip: 'Versturen',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, FeedbackMessage msg) {
    final theme = Theme.of(context);
    final isMe = widget.isAdmin ? msg.isFromAdmin : msg.isFromUser;

    Color bubbleColor;
    Color textColor;
    CrossAxisAlignment alignment;
    Widget? roleBadge;

    if (isMe) {
      bubbleColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
      alignment = CrossAxisAlignment.end;
    } else {
      bubbleColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
      alignment = CrossAxisAlignment.start;

      if (msg.isFromAdmin) {
        roleBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.amber.shade700,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Beheerder',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      } else if (msg.isFromGitHub) {
        roleBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF24292E),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.code, size: 10, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'GitHub',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      } else {
        roleBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Melder',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      }
    }

    final formattedDate =
        '${msg.createdAt.day.toString().padLeft(2, '0')}-${msg.createdAt.month.toString().padLeft(2, '0')} ${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Afzender info
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe && roleBadge != null) ...[
                  roleBadge,
                  const SizedBox(width: 6),
                ],
                Text(
                  isMe ? 'Jij' : msg.senderName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          // Bubble container
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  msg.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    height: 1.35,
                  ),
                ),

                // Eventuele bijlagen
                if (msg.attachmentUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: msg.attachmentUrls.map((url) {
                      return InkWell(
                        onTap: () => _showImagePreview(context, url),
                        borderRadius: BorderRadius.circular(8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 70,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 100,
                                height: 70,
                                color: Colors.black12,
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
