import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/core/widgets/custom_avatar.dart';
import '../../../../../themes/app_colors.dart';
import '../../../../../themes/app_text_styles.dart';
import 'package:dabbler/data/models/social/chat_message_model.dart';
import 'package:dabbler/data/models/authentication/user_model.dart';

/// A comprehensive chat input widget with text field, attachments,
/// emoji picker, voice messages, and reply functionality
class ChatInputWidget extends ConsumerStatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final ChatMessageModel? replyToMessage;
  final UserModel? replyToUser;
  final List<String> mentionSuggestions;
  final Function(String)? onSendText;
  final Function(List<String>)? onSendAttachments;
  final Function(String)? onSendVoice;
  final VoidCallback? onCancelReply;
  final Function(String)? onTypingChanged;
  final Function(String)? onMention;
  final VoidCallback? onEmojiTap;
  final VoidCallback? onAttachmentTap;
  final bool isRecording;
  final bool isUploading;
  final double uploadProgress;
  final EdgeInsetsGeometry? padding;
  final double maxHeight;

  const ChatInputWidget({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Type a message...',
    this.replyToMessage,
    this.replyToUser,
    this.mentionSuggestions = const [],
    this.onSendText,
    this.onSendAttachments,
    this.onSendVoice,
    this.onCancelReply,
    this.onTypingChanged,
    this.onMention,
    this.onEmojiTap,
    this.onAttachmentTap,
    this.isRecording = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.padding,
    this.maxHeight = 200,
  });

  @override
  ConsumerState<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends ConsumerState<ChatInputWidget>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _recordingAnimationController;
  late AnimationController _replyAnimationController;
  late Animation<double> _recordingPulseAnimation;
  late Animation<double> _replySlideAnimation;

  bool _showSendButton = false;
  bool _showMentionSuggestions = false;
  List<String> _filteredMentions = [];
  int _mentionStartIndex = -1;
  String _currentMention = '';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();

    _setupAnimations();
    _setupListeners();
  }

  void _setupAnimations() {
    _recordingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _replyAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _recordingPulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _recordingAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _replySlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _replyAnimationController, curve: Curves.easeOut),
    );

    // Show reply animation if there's a reply message
    if (widget.replyToMessage != null) {
      _replyAnimationController.forward();
    }
  }

  void _setupListeners() {
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ChatInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle reply animation
    if (widget.replyToMessage != null && oldWidget.replyToMessage == null) {
      _replyAnimationController.forward();
    } else if (widget.replyToMessage == null &&
        oldWidget.replyToMessage != null) {
      _replyAnimationController.reverse();
    }

    // Handle recording animation
    if (widget.isRecording && !oldWidget.isRecording) {
      _recordingAnimationController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _recordingAnimationController.stop();
      _recordingAnimationController.reset();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    _recordingAnimationController.dispose();
    _replyAnimationController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final oldShowSendButton = _showSendButton;

    setState(() {
      _showSendButton = text.trim().isNotEmpty;
    });

    // Notify typing changes
    if (oldShowSendButton != _showSendButton) {
      widget.onTypingChanged?.call(text);
    }

    // Handle mention detection
    _handleMentionDetection(text);
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      setState(() {
        _showMentionSuggestions = false;
      });
    }
  }

  void _handleMentionDetection(String text) {
    final cursorPosition = _controller.selection.base.offset;
    if (cursorPosition <= 0) {
      _hideMentionSuggestions();
      return;
    }

    // Find the last '@' before cursor
    final beforeCursor = text.substring(0, cursorPosition);
    final atIndex = beforeCursor.lastIndexOf('@');

    if (atIndex == -1) {
      _hideMentionSuggestions();
      return;
    }

    // Check if there's a space between @ and cursor (end of mention)
    final afterAt = beforeCursor.substring(atIndex + 1);
    if (afterAt.contains(' ')) {
      _hideMentionSuggestions();
      return;
    }

    // Extract mention text
    final mentionText = afterAt.toLowerCase();
    final filteredMentions = widget.mentionSuggestions
        .where((mention) => mention.toLowerCase().contains(mentionText))
        .toList();

    setState(() {
      _mentionStartIndex = atIndex;
      _currentMention = mentionText;
      _filteredMentions = filteredMentions;
      _showMentionSuggestions = filteredMentions.isNotEmpty;
    });
  }

  void _hideMentionSuggestions() {
    if (_showMentionSuggestions) {
      setState(() {
        _showMentionSuggestions = false;
        _filteredMentions.clear();
        _mentionStartIndex = -1;
        _currentMention = '';
      });
    }
  }

  void _insertMention(String mention) {
    final text = _controller.text;
    final newText = text.replaceRange(
      _mentionStartIndex,
      _mentionStartIndex + _currentMention.length + 1,
      '@$mention ',
    );

    _controller.text = newText;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _mentionStartIndex + mention.length + 2),
    );

    _hideMentionSuggestions();
    widget.onMention?.call(mention);
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText?.call(text);
      _controller.clear();
      setState(() {
        _showSendButton = false;
      });
      HapticFeedback.lightImpact();
    }
  }

  void _handleVoiceRecord() {
    HapticFeedback.mediumImpact();
    // In real implementation, start/stop voice recording
    if (widget.isRecording) {
      // Stop recording
      widget.onSendVoice?.call('voice_message_url');
    } else {
      // Start recording
      // This would typically start the recording service
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_showMentionSuggestions) _buildMentionSuggestions(),
        if (widget.replyToMessage != null) _buildReplyPreview(),
        if (widget.isUploading) _buildUploadProgress(),
        Container(
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: theme.dividerColor, width: 0.5),
            ),
          ),
          child: SafeArea(child: _buildInputRow()),
        ),
      ],
    );
  }

  Widget _buildMentionSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _filteredMentions.length,
        itemBuilder: (context, index) {
          final mention = _filteredMentions[index];
          return ListTile(
            dense: true,
            leading: CustomAvatar(radius: 16),
            title: Text(
              mention,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => _insertMention(mention),
          );
        },
      ),
    );
  }

  Widget _buildReplyPreview() {
    return AnimatedBuilder(
      animation: _replySlideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(_replySlideAnimation),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withOpacity(0.5),
              border: Border(
                left: BorderSide(color: AppColors.primary, width: 4),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.reply, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${widget.replyToUser?.displayName ?? 'User'}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.replyToMessage?.content ?? 'Message',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancelReply,
                  icon: const Icon(Icons.close),
                  iconSize: 16,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Uploading...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${(widget.uploadProgress * 100).toInt()}%',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: widget.uploadProgress,
            backgroundColor: AppColors.surfaceVariant.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildAttachmentButton(),
        const SizedBox(width: 8),
        Expanded(child: _buildTextField()),
        const SizedBox(width: 8),
        if (!_showSendButton) _buildEmojiButton(),
        if (!_showSendButton) const SizedBox(width: 8),
        _buildActionButton(),
      ],
    );
  }

  Widget _buildAttachmentButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onAttachmentTap ?? _showAttachmentOptions,
          child: Icon(
            Icons.add,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focusNode.hasFocus
              ? AppColors.primary.withOpacity(0.3)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: AppTextStyles.bodyMedium,
        onSubmitted: (_) => _handleSend(),
      ),
    );
  }

  Widget _buildEmojiButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onEmojiTap,
          child: Icon(
            Icons.emoji_emotions_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_showSendButton) {
      return _buildSendButton();
    } else {
      return _buildVoiceButton();
    }
  }

  Widget _buildSendButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _handleSend,
          child: const Icon(Icons.send, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return AnimatedBuilder(
      animation: _recordingPulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isRecording ? _recordingPulseAnimation.value : 1.0,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.isRecording
                  ? Colors.red
                  : AppColors.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _handleVoiceRecord,
                child: Icon(
                  widget.isRecording ? Icons.stop : Icons.mic,
                  color: widget.isRecording
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    // Handle camera
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    // Handle gallery
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    // Handle document
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_city,
                  label: 'Location',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    // Handle location
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version for smaller spaces
class CompactChatInput extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String)? onSendText;
  final String? hintText;

  const CompactChatInput({
    super.key,
    this.controller,
    this.onSendText,
    this.hintText = 'Type a message...',
  });

  @override
  Widget build(BuildContext context) {
    return ChatInputWidget(
      controller: controller,
      onSendText: onSendText,
      hintText: hintText,
      padding: const EdgeInsets.all(8),
      maxHeight: 80,
    );
  }
}
