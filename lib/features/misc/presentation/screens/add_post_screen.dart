import 'package:flutter/material.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/features/social/services/social_service.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/utils/enums/social_enums.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/auth_providers.dart';
import 'package:dabbler/features/social/providers/social_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/create_post/sport_tag_selector.dart';
import 'package:dabbler/features/social/presentation/widgets/create_post/mention_suggestions.dart';
import 'package:dabbler/data/models/authentication/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class AddPostScreen extends ConsumerStatefulWidget {
  const AddPostScreen({super.key});

  @override
  ConsumerState<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends ConsumerState<AddPostScreen> {
  final _textController = TextEditingController();
  bool _isPosting = false;
  String? _selectedVibeId;
  int _blocklistHits = 0;
  Timer? _debounceTimer;

  // Sport tags
  List<String> _selectedSports = [];

  // @Mention support
  List<UserModel> _mentionSuggestions = [];
  bool _showMentionSuggestions = false;
  Timer? _mentionDebounceTimer;
  final List<Map<String, String>> _mentionedUsers = []; // {id, displayName}

  @override
  void dispose() {
    _textController.dispose();
    _debounceTimer?.cancel();
    _mentionDebounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    // Debounce blocklist check
    _debounceTimer?.cancel();
    if (text.trim().isNotEmpty) {
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        _checkBlocklist(text);
      });
    } else {
      setState(() => _blocklistHits = 0);
    }

    // Check for @mention trigger
    _checkForMentionTrigger(text);
  }

  /// Detects @mention trigger at cursor position and queries profiles.
  void _checkForMentionTrigger(String text) {
    _mentionDebounceTimer?.cancel();

    final cursorPos = _textController.selection.baseOffset;
    if (cursorPos <= 0) {
      _hideMentionSuggestions();
      return;
    }

    // Find the @ symbol before the cursor
    final textBeforeCursor = text.substring(0, cursorPos);
    final atIndex = textBeforeCursor.lastIndexOf('@');
    if (atIndex == -1) {
      _hideMentionSuggestions();
      return;
    }

    // Ensure @ is at start of word (preceded by space or at start of text)
    if (atIndex > 0 &&
        textBeforeCursor[atIndex - 1] != ' ' &&
        textBeforeCursor[atIndex - 1] != '\n') {
      _hideMentionSuggestions();
      return;
    }

    final query = textBeforeCursor.substring(atIndex + 1);
    // No spaces in the mention query
    if (query.contains(' ') || query.contains('\n')) {
      _hideMentionSuggestions();
      return;
    }

    if (query.isEmpty) {
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
    } catch (e) {
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
      offset: atIndex + displayName.length + 2, // +2 for @ and space
    );

    // Track mentioned user for persistence
    if (!_mentionedUsers.any((m) => m['id'] == user.id)) {
      _mentionedUsers.add({'id': user.id, 'displayName': displayName});
    }

    _hideMentionSuggestions();
    setState(() {});
  }

  Future<void> _checkBlocklist(String text) async {
    try {
      final moderationService = ref.read(moderationServiceProvider);
      final hits = await moderationService.contentHitsBlocklist(text);
      if (mounted) {
        setState(() => _blocklistHits = hits);
      }
    } catch (e) {
      // Silently fail - don't block user input
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.colors.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create Post',
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        actions: [
          // Post button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: (_canPost() && !_isPosting) ? _handlePost : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                disabledBackgroundColor: context.colors.surfaceContainerHighest,
                disabledForegroundColor: context.colors.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 0,
              ),
              child: _isPosting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.onPrimary,
                        ),
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Avatar and Name
                  Row(
                    children: [
                      // User Avatar
                      Consumer(
                        builder: (context, ref, _) {
                          final authService = ref.watch(authServiceProvider);
                          final currentUser = authService.getCurrentUser();
                          final userAvatarUrl =
                              currentUser?.userMetadata?['avatar_url']
                                  as String?;
                          final userName =
                              currentUser?.userMetadata?['display_name']
                                  as String? ??
                              'User';
                          final resolvedAvatarUrl = resolveAvatarUrl(
                            userAvatarUrl,
                          );
                          final initial = userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U';

                          return CircleAvatar(
                            radius: 20,
                            backgroundColor: context.colors.primary.withValues(
                              alpha: 0.2,
                            ),
                            backgroundImage:
                                resolvedAvatarUrl != null &&
                                    resolvedAvatarUrl.isNotEmpty
                                ? NetworkImage(resolvedAvatarUrl)
                                : null,
                            child:
                                resolvedAvatarUrl == null ||
                                    resolvedAvatarUrl.isEmpty
                                ? Text(
                                    initial,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.primary,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      // User Name
                      Consumer(
                        builder: (context, ref, _) {
                          final authService = ref.watch(authServiceProvider);
                          final currentUser = authService.getCurrentUser();
                          final userName =
                              currentUser?.userMetadata?['display_name']
                                  as String? ??
                              'User';

                          return Text(
                            userName,
                            style: TextStyle(
                              color: context.colors.onSurface,
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Blocklist warning
                  if (_blocklistHits > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_rounded,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your post contains inappropriate content ($_blocklistHits violation${_blocklistHits > 1 ? 's' : ''}). Please revise.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Text Input
                  TextField(
                    controller: _textController,
                    maxLines: null,
                    minLines: 4,
                    onChanged: (text) {
                      _onTextChanged(text);
                      setState(() {});
                    },
                    style: const TextStyle(
                      color: Color(0xFFEBD7FA),
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: -0.312,
                    ),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(
                        color: const Color(0xFFEBD7FA).withValues(alpha: 0.70),
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: -0.312,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF301C4D),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: const Color(
                            0xFFEBD7FA,
                          ).withValues(alpha: 0.24),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: const Color(
                            0xFFEBD7FA,
                          ).withValues(alpha: 0.24),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide(
                          color: const Color(0xFFEBD7FA).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Vibes selector (primary)
                  Consumer(
                    builder: (context, ref, _) {
                      final vibesAsync = ref.watch(vibesProvider);
                      return vibesAsync.when(
                        data: (vibes) {
                          if (vibes.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vibe',
                                style: context.textTheme.labelLarge?.copyWith(
                                  color: context.colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: vibes.map((v) {
                                  final id = v['id']?.toString() ?? '';
                                  final label =
                                      v['label']?.toString() ??
                                      v['key']?.toString() ??
                                      'Vibe';
                                  final emoji = v['emoji']?.toString() ?? '';
                                  final selected = _selectedVibeId == id;
                                  return ChoiceChip(
                                    label: Text(
                                      '${emoji.isNotEmpty ? '$emoji ' : ''}$label',
                                    ),
                                    selected: selected,
                                    onSelected: (sel) {
                                      setState(() {
                                        _selectedVibeId = sel ? id : null;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sport/Activity tags
                  SportTagSelector(
                    selectedSports: _selectedSports,
                    onSportsChanged: (sports) {
                      setState(() => _selectedSports = sports);
                    },
                  ),

                  // @Mention suggestions overlay
                  if (_showMentionSuggestions)
                    MentionSuggestions(
                      suggestions: _mentionSuggestions,
                      onMentionSelected: _onMentionSelected,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canPost() {
    return _textController.text.trim().isNotEmpty;
  }

  Future<void> _handlePost() async {
    if (!_canPost() || _isPosting) return;

    setState(() => _isPosting = true);

    try {
      // Check cooldown before allowing post creation
      final moderationService = ref.read(moderationServiceProvider);
      final cooldownResult = await moderationService.checkAndBumpCooldown(
        'post.create',
        windowSeconds: 3600, // 1 hour window
        limitCount: 10, // 10 posts per hour
      );

      if (!cooldownResult.allowed) {
        if (mounted) {
          setState(() => _isPosting = false);
          final resetTime = DateFormat('HH:mm').format(cooldownResult.resetAt);
          _showError(
            'You\'ve reached the posting limit. You can post again at $resetTime. '
            'Remaining: ${cooldownResult.remaining} posts.',
          );
        }
        return;
      }

      final socialService = SocialService();

      // Extract mention profile IDs
      final mentionProfileIds = _mentionedUsers.map((m) => m['id']!).toList();

      // Create the post with tags and mentions
      final post = await socialService.createPost(
        content: _textController.text.trim(),
        mediaUrls: [], // No media in MVP
        locationName: null, // No location in MVP
        visibility: PostVisibility.public,
        tags: _selectedSports,
        mentionProfileIds: mentionProfileIds,
      );

      // Set primary vibe if selected
      if (_selectedVibeId != null) {
        await socialService.setPrimaryVibe(
          postId: post.id,
          vibeId: _selectedVibeId!,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text('Post shared successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigate back to social feed
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPosting = false);
        _showError('Failed to share post: ${e.toString()}');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
