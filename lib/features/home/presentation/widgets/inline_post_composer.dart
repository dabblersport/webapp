import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/utils/enums/social_enums.dart';
import 'package:dabbler/data/social/social_repository.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:go_router/go_router.dart';
// [DISABLED] Sport tags & @mentions – re-enable when ready
// import 'package:dabbler/features/social/presentation/widgets/create_post/sport_tag_selector.dart';
// import 'package:dabbler/features/social/presentation/widgets/create_post/mention_suggestions.dart';
// import 'package:dabbler/data/models/authentication/user_model.dart';
import 'package:dabbler/services/moderation_service.dart';
// import 'package:supabase_flutter/supabase_flutter.dart'; // [DISABLED] used by @mentions
import 'dart:async';

final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(),
);

enum ComposerMode { post, comment }

enum CreationType { post, game }

class InlinePostComposer extends ConsumerStatefulWidget {
  const InlinePostComposer({
    super.key,
    this.mode = ComposerMode.post,
    this.parentPostId,
  });

  final ComposerMode mode;
  final String? parentPostId;

  @override
  ConsumerState<InlinePostComposer> createState() => _InlinePostComposerState();
}

class _InlinePostComposerState extends ConsumerState<InlinePostComposer> {
  final _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isPosting = false;
  String _selectedKind = 'moment'; // 'moment', 'dab', 'kickin'
  dynamic _selectedVibeId;
  List<Map<String, dynamic>> _availableVibes = [];
  bool _isLoadingVibes = false;
  final List<XFile> _selectedMedia = [];
  CreationType _creationType = CreationType.post;

  // [DISABLED] Sport tags & @mentions – re-enable when ready
  // List<String> _selectedSports = [];
  // List<UserModel> _mentionSuggestions = [];
  // bool _showMentionSuggestions = false;
  // Timer? _mentionDebounceTimer;
  // final List<Map<String, String>> _mentionedUsers = [];

  // Moderation
  int _blocklistHits = 0;
  Timer? _blocklistDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadVibes();
    // Auto-focus to open keyboard on Android
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    // _mentionDebounceTimer?.cancel(); // [DISABLED] @mentions
    _blocklistDebounceTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Text change handlers (blocklist + @mention detection)
  // ---------------------------------------------------------------------------

  void _onTextChanged(String text) {
    // Debounce blocklist check
    _blocklistDebounceTimer?.cancel();
    if (text.trim().isNotEmpty) {
      _blocklistDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkBlocklist(text);
      });
    } else {
      setState(() => _blocklistHits = 0);
    }

    // [DISABLED] @mentions
    // _checkForMentionTrigger(text);

    setState(() {}); // refresh UI for post button
  }

  Future<void> _checkBlocklist(String text) async {
    try {
      final moderationService = ref.read(moderationServiceProvider);
      final hits = await moderationService.contentHitsBlocklist(text);
      if (mounted) {
        setState(() => _blocklistHits = hits);
      }
    } catch (_) {
      // Silently fail
    }
  }

  // ---------------------------------------------------------------------------
  // [DISABLED] @Mention support – re-enable when ready
  // ---------------------------------------------------------------------------
  /*
  void _checkForMentionTrigger(String text) {
    _mentionDebounceTimer?.cancel();

    final cursorPos = _textController.selection.baseOffset;
    if (cursorPos <= 0) {
      _hideMentionSuggestions();
      return;
    }

    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) {
      _hideMentionSuggestions();
      return;
    }

    if (atIndex > 0 &&
        textBeforeCursor[atIndex - 1] != ' ' &&
        textBeforeCursor[atIndex - 1] != '\n') {
      _hideMentionSuggestions();
      return;
    }

    final query = textBeforeCursor.substring(atIndex + 1);
    if (query.contains(' ') || query.contains('\n') || query.isEmpty) {
      _hideMentionSuggestions();
      return;
    }

    _mentionDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchMentionProfiles(query);
    });
  }

  Future<void> _searchMentionProfiles(String query) async {
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, user_id, display_name, username, avatar_url')
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .order('display_name', ascending: true)
          .limit(6);

      if (mounted) {
        final suggestions = (rows as List).map((row) {
          return UserModel(
            id: row['user_id'] ?? row['id'] ?? '',
            username: row['username']?.toString(),
            fullName: row['display_name']?.toString(),
            email: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }).toList();

        setState(() {
          _mentionSuggestions = suggestions;
          _showMentionSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (_) {
      _hideMentionSuggestions();
    }
  }

  void _hideMentionSuggestions() {
    if (_showMentionSuggestions) {
      setState(() {
        _showMentionSuggestions = false;
        _mentionSuggestions = [];
      });
    }
  }

  void _onMentionSelected(UserModel user) {
    final text = _textController.text;
    final cursorPos = _textController.selection.baseOffset;
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');

    if (atIndex == -1) return;

    final displayName = user.username ?? user.displayName;
    final beforeAt = text.substring(0, atIndex);
    final afterCursor = cursorPos < text.length
        ? text.substring(cursorPos)
        : '';
    final newText = '$beforeAt@$displayName $afterCursor';

    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: atIndex + displayName.length + 2,
    );

    if (!_mentionedUsers.any((m) => m['id'] == user.id)) {
      _mentionedUsers.add({'id': user.id, 'displayName': displayName});
    }

    _hideMentionSuggestions();
    setState(() {});
  }
  */

  Future<void> _loadVibes() async {
    setState(() {
      _isLoadingVibes = true;
    });

    try {
      final repo = ref.read(socialRepositoryProvider);
      final vibes = await repo.getVibesForKind(_selectedKind);
      setState(() {
        _availableVibes = vibes;
        if (vibes.isNotEmpty) {
          _selectedVibeId = vibes.first['id'];
        }
        _isLoadingVibes = false;
      });
    } catch (e) {
      print('Error loading vibes: $e');
      setState(() {
        _isLoadingVibes = false;
      });
    }
  }

  void _onKindChanged(String kind) {
    setState(() {
      _selectedKind = kind;
    });
  }

  Future<void> _handlePost() async {
    if (_textController.text.isEmpty && _selectedMedia.isEmpty) return;

    setState(() {
      _isPosting = true;
    });

    try {
      final repo = ref.read(socialRepositoryProvider);

      if (widget.mode == ComposerMode.comment) {
        // Handle comment creation
        await repo.createComment(
          postId: widget.parentPostId!,
          body: _textController.text,
        );
      } else {
        // Handle post creation
        // [DISABLED] Sport tags & @mentions – re-enable when ready
        // final mentionProfileIds = _mentionedUsers.map((m) => m['id']!).toList();

        await repo.createPost(
          kind: _selectedKind,
          visibility: PostVisibility.public,
          body: _textController.text,
          primaryVibeId: _selectedVibeId?.toString(),
          // tags: _selectedSports,
          // mentionProfileIds: mentionProfileIds,
        );
      }

      // Refresh posts
      ref.invalidate(latestFeedPostsProvider);

      // Clear form
      _textController.clear();
      setState(() {
        _selectedMedia.clear();
        // _selectedSports.clear();   // [DISABLED]
        // _mentionedUsers.clear();  // [DISABLED]
        _blocklistHits = 0;
        _isPosting = false;
      });

      if (mounted) {
        // Dismiss the bottom sheet
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.mode == ComposerMode.post
                  ? 'Post created!'
                  : 'Comment added!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print(
        'Error creating ${widget.mode == ComposerMode.post ? "post" : "comment"}: $e',
      );
      setState(() {
        _isPosting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${widget.mode == ComposerMode.post ? "post" : "comment"}. Try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedMedia.add(image);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  void _showAttachmentOptions() {
    final platform = Theme.of(context).platform;

    if (platform == TargetPlatform.iOS) {
      showCupertinoModalPopup<void>(
        context: context,
        builder: (context) {
          return CupertinoActionSheet(
            title: const Text('Add to your post'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
                child: const Text('Camera'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
                child: const Text('Gallery'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(context),
              isDefaultAction: true,
              child: const Text('Cancel'),
            ),
          );
        },
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        final colorScheme = Theme.of(context).colorScheme;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text('Add to your post', style: textTheme.titleSmall),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Iconsax.camera_copy, color: colorScheme.primary),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Iconsax.gallery_copy, color: colorScheme.primary),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showPostTypeOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose post type',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              RadioListTile<String>(
                value: 'moment',
                groupValue: _selectedKind,
                onChanged: (value) {
                  Navigator.pop(context);
                  _onKindChanged(value!);
                },
                title: Text('Moment'),
                subtitle: Text('Share what\'s happening now'),
                secondary: Icon(Iconsax.flash_1_copy),
              ),
              RadioListTile<String>(
                value: 'dab',
                groupValue: _selectedKind,
                onChanged: (value) {
                  Navigator.pop(context);
                  _onKindChanged(value!);
                },
                title: Text('Dab'),
                subtitle: Text('Celebrate an achievement'),
                secondary: Icon(Iconsax.medal_copy),
              ),
              RadioListTile<String>(
                value: 'kickin',
                groupValue: _selectedKind,
                onChanged: (value) {
                  Navigator.pop(context);
                  _onKindChanged(value!);
                },
                title: Text('Kick-in'),
                subtitle: Text('Invite others to join'),
                secondary: Icon(Iconsax.people_copy),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showVibeOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'How are you feeling?',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _isLoadingVibes
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _availableVibes.length,
                          itemBuilder: (context, index) {
                            final vibe = _availableVibes[index];
                            final vibeId = vibe['id'];
                            final emoji = (vibe['emoji'] ?? '😊').toString();
                            final label =
                                (vibe['label_en'] ?? vibe['key'] ?? 'Unknown')
                                    .toString();
                            final isSelected = _selectedVibeId == vibeId;

                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  _selectedVibeId = vibeId;
                                });
                                Navigator.pop(context);
                              },
                              title: Text(label),
                              secondary: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.primaryContainer
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasContent =
        _textController.text.isNotEmpty || _selectedMedia.isNotEmpty;

    return Card(
      elevation: 2,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Creation type toggle (Post vs Game)
            if (widget.mode == ComposerMode.post)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<CreationType>(
                        segments: [
                          ButtonSegment<CreationType>(
                            value: CreationType.post,
                            label: Text('Create Post'),
                            // icon: Icon(Iconsax.message_text_copy),
                          ),
                          ButtonSegment<CreationType>(
                            value: CreationType.game,
                            label: Text('Create Game'),
                            // icon: Icon(Iconsax.game_copy),
                          ),
                        ],
                        selected: {_creationType},
                        onSelectionChanged: (Set<CreationType> newSelection) {
                          setState(() {
                            _creationType = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return _creationType == CreationType.post
                                  ? colorScheme.categorySocial
                                  : colorScheme.categorySports;
                            }
                            return colorScheme.surfaceContainer;
                          }),
                          foregroundColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return colorScheme.onPrimary;
                            }
                            return colorScheme.onSurfaceVariant;
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Text input
            TextFormField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: null,
              minLines: 1,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: widget.mode == ComposerMode.post
                    ? "What's on your mind?"
                    : 'Write a comment...',
                filled: true,
                fillColor: colorScheme.surfaceContainer,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: colorScheme.categorySocial,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => _onTextChanged(_textController.text),
            ),

            // Blocklist warning
            if (_blocklistHits > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 16,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contains inappropriate content ($_blocklistHits violation${_blocklistHits > 1 ? 's' : ''}). Please revise.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // [DISABLED] @Mention suggestions – re-enable when ready
            // if (_showMentionSuggestions) ...[
            //   const SizedBox(height: 4),
            //   MentionSuggestions(
            //     suggestions: _mentionSuggestions,
            //     onMentionSelected: _onMentionSelected,
            //   ),
            // ],

            // [DISABLED] Sport/Activity tags – re-enable when ready
            // if (widget.mode == ComposerMode.post &&
            //     _creationType == CreationType.post) ...[
            //   const SizedBox(height: 12),
            //   SportTagSelector(
            //     selectedSports: _selectedSports,
            //     onSportsChanged: (sports) {
            //       setState(() => _selectedSports = sports);
            //     },
            //   ),
            // ],

            // Media preview
            if (_selectedMedia.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedMedia.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          // Image container
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              color: colorScheme.surfaceContainer,
                              child: Center(
                                child: Icon(
                                  Iconsax.gallery_copy,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),

                          // Remove button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton.filledTonal(
                              onPressed: () {
                                setState(() {
                                  _selectedMedia.removeAt(index);
                                });
                              },
                              icon: const Icon(
                                Iconsax.close_circle_copy,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: colorScheme.errorContainer,
                                foregroundColor: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Controls row
            Row(
              children: [
                // Show controls only for posts (not comments) and when creating posts
                if (widget.mode == ComposerMode.post &&
                    _creationType == CreationType.post) ...[
                  // Attachment button
                  IconButton.filledTonal(
                    onPressed: _showAttachmentOptions,
                    icon: const Icon(Iconsax.add_copy),
                    tooltip: 'Add media',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.secondaryContainer,
                      foregroundColor: colorScheme.onSecondaryContainer,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Vibe chip
                  FilterChip(
                    label: Builder(
                      builder: (context) {
                        final fallback = _availableVibes.isNotEmpty
                            ? _availableVibes.first
                            : null;
                        final selected = _availableVibes.firstWhere(
                          (v) => v['id'] == _selectedVibeId,
                          orElse: () =>
                              fallback ??
                              {'emoji': '😊', 'label_en': 'Neutral'},
                        );
                        final emoji = (selected['emoji'] ?? '😊').toString();
                        final label =
                            (selected['label_en'] ??
                                    selected['key'] ??
                                    'Neutral')
                                .toString();

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 4),
                            Text(label),
                          ],
                        );
                      },
                    ),
                    onSelected: (_) => _showVibeOptions(),
                    backgroundColor: colorScheme.tertiaryContainer,
                    selectedColor: colorScheme.tertiaryContainer,
                    labelStyle: AppTypography.labelLarge.copyWith(
                      color: colorScheme.onTertiaryContainer,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  const Spacer(),

                  // Post type chip
                  FilterChip(
                    label: Text(
                      _selectedKind == 'moment'
                          ? 'Moment'
                          : _selectedKind == 'dab'
                          ? 'Dab'
                          : 'Kick-in',
                    ),
                    onSelected: (_) => _showPostTypeOptions(),
                    backgroundColor: colorScheme.categorySocial.withValues(
                      alpha: 0.2,
                    ),
                    selectedColor: colorScheme.categorySocial.withValues(
                      alpha: 0.2,
                    ),
                    labelStyle: AppTypography.labelLarge.copyWith(
                      color: colorScheme.categorySocial,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],

                // Game creation button
                if (widget.mode == ComposerMode.post &&
                    _creationType == CreationType.game) ...[
                  FilledButton.icon(
                    onPressed: () {
                      // Navigate to game creation screen
                      Navigator.of(context).pop();
                      context.push('/create-game');
                    },
                    icon: Icon(Iconsax.game_copy),
                    label: Text('Create Game'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.categorySports,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],

                const SizedBox(width: 24),

                // Post/Comment button
                if (hasContent && _creationType == CreationType.post)
                  IconButton.filled(
                    onPressed: _isPosting ? null : _handlePost,
                    icon: _isPosting
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : Icon(
                            widget.mode == ComposerMode.post
                                ? Iconsax.send_2_copy
                                : Iconsax.message_text_copy,
                            size: 20,
                          ),
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.categorySocial,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
