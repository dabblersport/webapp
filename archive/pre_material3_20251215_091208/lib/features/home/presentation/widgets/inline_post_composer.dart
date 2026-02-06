import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:dabbler/utils/enums/social_enums.dart';
import 'package:dabbler/data/social/social_repository.dart';
import 'package:dabbler/features/home/presentation/providers/home_providers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/themes/material3_extensions.dart';
import 'package:go_router/go_router.dart';

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
    super.dispose();
  }

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
        await repo.createPost(
          kind: _selectedKind,
          visibility: PostVisibility.public,
          body: _textController.text,
          primaryVibeId: _selectedVibeId?.toString(),
          // TODO: Upload media
        );
      }

      // Refresh posts
      ref.invalidate(latestFeedPostsProvider);

      // Clear form
      _textController.clear();
      setState(() {
        _selectedMedia.clear();
        _isPosting = false;
      });

      if (mounted) {
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return NavigationDrawer(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 1,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
              child: Text(
                'Add to your post',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            NavigationDrawerDestination(
              icon: Icon(Iconsax.camera_copy),
              label: Text('Camera'),
            ),
            NavigationDrawerDestination(
              icon: Icon(Iconsax.gallery_copy),
              label: Text('Gallery'),
            ),
            const SizedBox(height: 12),
          ],
          onDestinationSelected: (index) {
            Navigator.pop(context);
            if (index == 0) {
              _pickImage(ImageSource.camera);
            } else if (index == 1) {
              _pickImage(ImageSource.gallery);
            }
          },
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
              onChanged: (_) => setState(() {}),
            ),

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

                const Spacer(),

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
