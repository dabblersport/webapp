import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/design_system/tokens/avatar_color_palette.dart';
import 'package:dabbler/core/design_system/widgets/ds_avatar.dart';
import 'package:dabbler/core/services/auth_service.dart';

import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_location_chip.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';

/// Full-featured post composer that exposes all `posts` table capabilities.
///
/// Allows selection of: visibility, kind, body, vibe, sport, location,
/// media, allow_reposts toggle, and optional expiry.
///
/// Before insert it auto-detects language, extracts hashtags, resolves
/// the author profile via RLS-safe lookup, and generates link_token
/// when visibility == link.
String _prettifyLabel(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class PostComposerScreen extends ConsumerStatefulWidget {
  const PostComposerScreen({super.key});

  @override
  ConsumerState<PostComposerScreen> createState() => _PostComposerScreenState();
}

class _PostComposerScreenState extends ConsumerState<PostComposerScreen> {
  late final _HashtagTextEditingController _bodyController;
  final _bodyFocusNode = FocusNode();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    // Controller is created here; hashtagColor is set in didChangeDependencies
    // once the theme is available.
    _bodyController = _HashtagTextEditingController();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bodyController.hashtagColor = Theme.of(context).colorScheme.primary;
  }

  Future<void> _loadUserProfile() async {
    final activeType = ref.read(activeProfileTypeProvider);
    final profile = await _authService.getUserProfile(personaType: activeType);
    if (mounted) setState(() => _userProfile = profile);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SUBMIT
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    final notifier = ref.read(postComposerProvider.notifier);
    final result = await notifier.submit();
    result.fold(
      (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      },
      (post) {
        if (!mounted) return;
        context.pop(true);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PICKERS
  // ═══════════════════════════════════════════════════════════════════════

  void _showVisibilityPicker() {
    final cs = Theme.of(context).colorScheme;
    final state = ref.read(postComposerProvider);

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Who can see this?',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            for (final v in PostVisibility.values)
              ListTile(
                leading: Icon(
                  _visibilityIcon(v),
                  color: state.visibility == v ? cs.primary : cs.onSurface,
                ),
                title: Text(
                  _visibilityLabel(v),
                  style: TextStyle(
                    fontWeight: state.visibility == v
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: state.visibility == v ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  _visibilityDescription(v),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                trailing: state.visibility == v
                    ? Icon(Icons.check_circle, color: cs.primary)
                    : null,
                onTap: () {
                  ref.read(postComposerProvider.notifier).setVisibility(v);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showVibesPicker() {
    final cs = Theme.of(context).colorScheme;

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) =>
            _ComposerVibesPickerSheet(scrollController: scrollController),
      ),
    );
  }

  void _showSportsPicker() {
    final composerState = ref.read(postComposerProvider);
    final selectedSport = composerState.sportId != null
        ? Sport(
            id: composerState.sportId!,
            nameEn: composerState.sportName ?? '',
            emoji: composerState.sportEmoji,
          )
        : null;

    showAdaptiveSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (_) => SportSelectionSheet(
        sportsProvider: activeSportsByProfileCountryProvider,
        selectedSport: selectedSport,
        showClear: composerState.sportId != null,
        onClear: () => ref.read(postComposerProvider.notifier).clearSport(),
        onSelect: (sport) => ref.read(postComposerProvider.notifier).setSport(
          id: sport.id,
          name: sport.nameEn,
          emoji: sport.emoji,
        ),
      ),
    );
  }

  void _showExpiryPicker() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      ref.read(postComposerProvider.notifier).setExpiresAt(picked);
    }
  }

  void _showGamePicker() {
    final cs = Theme.of(context).colorScheme;

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) =>
            _GamePickerSheet(scrollController: scrollController),
      ),
    );
  }

  void _showPostTypePicker() {
    final cs = Theme.of(context).colorScheme;
    final state = ref.read(postComposerProvider);
    final selectableTypes = PostType.values
        .where((t) => t.isUserSelectable)
        .toList(growable: false);

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Post Type',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            for (final t in selectableTypes)
              ListTile(
                leading: Icon(
                  _postTypeIcon(t),
                  color: state.postType == t ? cs.primary : cs.onSurface,
                ),
                title: Text(
                  _postTypeLabel(t),
                  style: TextStyle(
                    fontWeight: state.postType == t
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: state.postType == t ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  _postTypeDescription(t),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                trailing: state.postType == t
                    ? Icon(Icons.check_circle, color: cs.primary)
                    : null,
                onTap: () {
                  ref.read(postComposerProvider.notifier).setPostType(t);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showContentClassPicker() {
    final cs = Theme.of(context).colorScheme;
    final state = ref.read(postComposerProvider);
    const classes = ['social', 'editorial'];

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Content Class',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            for (final cc in classes)
              ListTile(
                leading: Icon(
                  cc == 'social' ? Icons.people : Icons.article,
                  color: state.contentClass == cc ? cs.primary : cs.onSurface,
                ),
                title: Text(
                  _prettifyLabel(cc),
                  style: TextStyle(
                    fontWeight: state.contentClass == cc
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: state.contentClass == cc ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  cc == 'social'
                      ? 'Standard social post'
                      : 'Editorial or long-form content',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                trailing: state.contentClass == cc
                    ? Icon(Icons.check_circle, color: cs.primary)
                    : null,
                onTap: () {
                  ref.read(postComposerProvider.notifier).setContentClass(cc);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMediaInput() {
    final cs = Theme.of(context).colorScheme;

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  'Add Media',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),

              // Camera option
              ListTile(
                leading: Icon(Icons.camera_alt_rounded, color: cs.primary),
                title: Text(
                  'Take Photo',
                  style: TextStyle(color: cs.onSurface),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadMedia(ImageSource.camera);
                },
              ),
              const SizedBox(height: 4),

              // Gallery option
              ListTile(
                leading: Icon(Icons.photo_library_rounded, color: cs.primary),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: cs.onSurface),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadMedia(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 4),

              // GIF option
              ListTile(
                leading: Icon(Icons.gif_box_rounded, color: cs.primary),
                title: Text(
                  'Search GIFs',
                  style: TextStyle(color: cs.onSurface),
                ),
                subtitle: Text(
                  'Powered by GIPHY',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGifPicker();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadMedia(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return;

    await ref.read(postComposerProvider.notifier).uploadMedia(picked);
  }

  void _showGifPicker() {
    showAdaptiveSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => _GifPickerSheet(
          scrollController: scrollController,
          onSelected: (gifUrl) {
            ref.read(postComposerProvider.notifier).addMediaUrl(gifUrl);
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  Future<void> _showProfileSwitchPicker() async {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final profiles = await ref.read(availableProfilesProvider.future);

    if (!mounted || profiles.isEmpty) {
      return;
    }

    final activeType = ref.read(activeProfileTypeProvider);

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Post As',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            for (final profile in profiles)
              Builder(
                builder: (_) {
                  final effectiveType =
                      (profile.personaType ?? profile.profileType ?? '')
                          .toLowerCase();
                  final isActive =
                      effectiveType.isNotEmpty &&
                      effectiveType == activeType?.toLowerCase();

                  return ListTile(
                    leading: DSAvatar.small(
                      imageUrl: profile.avatarUrl,
                      displayName: profile.displayName,
                      context: AvatarContext.main,
                    ),
                    title: Text(
                      profile.displayName,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                    ),
                    subtitle: effectiveType.isNotEmpty
                        ? Text(
                            _prettifyLabel(effectiveType),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        : null,
                    trailing: isActive
                        ? Icon(Icons.check_circle, color: cs.primary)
                        : null,
                    onTap: () async {
                      if (isActive || effectiveType.isEmpty) {
                        Navigator.pop(ctx);
                        return;
                      }

                      final switched = await ref
                          .read(personaServiceProvider.notifier)
                          .switchActiveProfile(effectiveType);

                      if (!switched) {
                        if (context.mounted) {
                          final errorMsg =
                              ref.read(personaServiceProvider).errorMessage ??
                              'Failed to switch profile';
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(errorMsg)));
                        }
                        return;
                      }

                      ref.read(activeProfileTypeProvider.notifier).state =
                          effectiveType;
                      unawaited(persistActiveProfileType(effectiveType));
                      ref
                          .read(postComposerProvider.notifier)
                          .setPersonaTypeSnapshot(effectiveType);

                      final userId = _authService.getCurrentUser()?.id;
                      if (userId != null) {
                        await clearProfileCache(ref, userId);
                      }

                      await _loadUserProfile();

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                    },
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final composerState = ref.watch(postComposerProvider);

    const bg = Color(0xFFF4EEF9);
    const outline = Color(0xFFDDD6E4);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(cs, tt, composerState),
      body: Column(
        children: [
          if (composerState.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cs.errorContainer,
              child: Text(
                composerState.error!,
                style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Author + type/visibility ──────────────────────
                  _PostDividerSection(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAuthorRow(cs, tt),
                        const SizedBox(height: 12),
                        _buildKindVisibilityRow(cs, composerState),
                      ],
                    ),
                  ),

                  // ── Body text + tag previews ──────────────────────
                  _PostDividerSection(
                    child: _buildBodyField(cs, tt, composerState),
                  ),

                  // ── Attachment chips ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: outline, width: 1),
                      ),
                    ),
                    child: _buildAttachmentChips(cs, composerState),
                  ),

                  // ── Media list ────────────────────────────────────
                  if (composerState.hasMedia)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _buildMediaList(cs, tt, composerState),
                    ),

                  // ── Options ───────────────────────────────────────
                  _buildOptionsSection(cs, tt, composerState),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar(
    ColorScheme cs,
    TextTheme tt,
    PostComposerState composerState,
  ) {
    const bg = Color(0xFFF4EEF9);
    const bgDark = Color(0xFFEDE6EE);
    const outline = Color(0xFFDDD6E4);
    const onBg = Color(0xFF1D1A20);

    return AppBar(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1, color: outline),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bgDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: outline, width: 1.5),
                ),
                child: const Icon(Icons.close_rounded, size: 16, color: onBg),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Create Post',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onBg,
                ),
              ),
            ),
            _PostButton(
              canPost: composerState.canSubmit,
              isSubmitting: composerState.isSubmitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUTHOR ROW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAuthorRow(ColorScheme cs, TextTheme tt) {
    const bgDark = Color(0xFFEDE6EE);
    const outline = Color(0xFFDDD6E4);
    const onBg = Color(0xFF1D1A20);
    const muted = Color(0xFF8B849A);
    const primary = Color(0xFF7328CE);

    final displayName =
        _userProfile?['display_name'] as String? ??
        _userProfile?['username'] as String? ??
        'You';
    final avatarUrl = _userProfile?['avatar_url'] as String?;
    final composerState = ref.watch(postComposerProvider);
    final activePersona = ref.watch(activeProfileTypeProvider);

    return Row(
      children: [
        DSAvatar.small(
          imageUrl: avatarUrl,
          displayName: displayName,
          context: AvatarContext.main,
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: onBg,
                  letterSpacing: -0.2,
                ),
              ),
              if (activePersona != null && activePersona.isNotEmpty)
                Text(
                  _prettifyLabel(
                    composerState.personaTypeSnapshot ?? activePersona,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: activePersona != null && activePersona.isNotEmpty
              ? _showProfileSwitchPicker
              : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgDark,
              shape: BoxShape.circle,
              border: Border.all(color: outline, width: 1.5),
            ),
            child: Icon(Iconsax.convert_copy, size: 17, color: muted),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // KIND + VISIBILITY + ORIGIN ROW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildKindVisibilityRow(
    ColorScheme cs,
    PostComposerState composerState,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ComposerPill(
          icon: _postTypeIcon(composerState.postType),
          label: _postTypeLabel(composerState.postType),
          onTap: _showPostTypePicker,
          activeColor: const Color(0xFF7328CE),
        ),
        _ComposerPill(
          icon: _visibilityIcon(composerState.visibility),
          label: _visibilityLabel(composerState.visibility),
          onTap: _showVisibilityPicker,
          activeColor: const Color(0xFF8B849A),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BODY TEXT FIELD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBodyField(
    ColorScheme cs,
    TextTheme tt,
    PostComposerState composerState,
  ) {
    const onBg = Color(0xFF1D1A20);
    const muted = Color(0xFF8B849A);
    const primary = Color(0xFF7328CE);
    const pink = Color(0xFFFF3376);
    const maxLen = 2000;

    final bodyLen = composerState.body?.length ?? 0; // ignore: invalid_null_aware_operator

    // Build tag preview badges
    final tags = <Widget>[];
    if (composerState.hasVibe && composerState.vibeName != null) {
      tags.add(_TagBadge(
        label: '✦ ${composerState.vibeName!}',
        bg: const Color(0x207328CE),
        fg: primary,
        border: const Color(0x507328CE),
      ));
    }
    if (composerState.hasSport && composerState.sportName != null) {
      Color sportColor = primary;
      if (composerState.sportName != null) {
        const sportColors = {
          'Football': Color(0xFF00C853),
          'Basketball': Color(0xFFFF6D00),
          'Tennis': Color(0xFFF4C430),
          'Running': Color(0xFF00B0FF),
          'Cricket': Color(0xFF8BC34A),
          'Swimming': Color(0xFF00BCD4),
          'Boxing': Color(0xFFFF1744),
          'Cycling': Color(0xFFE040FB),
        };
        sportColor = sportColors[composerState.sportName] ?? primary;
      }
      tags.add(_TagBadge(
        label: '⚡ ${composerState.sportName!}',
        bg: sportColor.withValues(alpha: 0.12),
        fg: sportColor,
        border: sportColor.withValues(alpha: 0.31),
      ));
    }
    if (composerState.locationName != null) {
      tags.add(_TagBadge(
        label: '📍 ${composerState.locationName!}',
        bg: const Color(0x208B849A),
        fg: muted,
        border: const Color(0x508B849A),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _bodyController,
          focusNode: _bodyFocusNode,
          maxLines: null,
          minLines: 5,
          style: const TextStyle(
            fontSize: 15,
            height: 1.65,
            color: onBg,
          ),
          decoration: InputDecoration(
            hintText: "What's on your mind? Use #hashtags",
            hintStyle: TextStyle(
              fontSize: 15,
              height: 1.65,
              color: muted.withValues(alpha: 0.6),
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            ref.read(postComposerProvider.notifier).setBody(value);
          },
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 6, children: tags),
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$bodyLen/$maxLen',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: bodyLen > maxLen * 0.9 ? pink : muted,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MEDIA LIST
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMediaList(
    ColorScheme cs,
    TextTheme tt,
    PostComposerState state,
  ) {
    final mediaItems = state.media;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        // ── Single media → large preview ──
        if (mediaItems.length == 1)
          _MediaPreviewTile(
            url: mediaItems[0].toString(),
            onRemove: () =>
                ref.read(postComposerProvider.notifier).removeMediaAt(0),
            cs: cs,
            height: 220,
            width: double.infinity,
          )
        // ── Two items → side-by-side ──
        else if (mediaItems.length == 2)
          Row(
            children: [
              for (int i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MediaPreviewTile(
                    url: mediaItems[i].toString(),
                    onRemove: () => ref
                        .read(postComposerProvider.notifier)
                        .removeMediaAt(i),
                    cs: cs,
                    height: 180,
                  ),
                ),
              ],
            ],
          )
        // ── Three+ items → compact grid ──
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: mediaItems.length,
            itemBuilder: (_, i) => _MediaPreviewTile(
              url: mediaItems[i].toString(),
              onRemove: () =>
                  ref.read(postComposerProvider.notifier).removeMediaAt(i),
              cs: cs,
            ),
          ),

        const SizedBox(height: 8),

        // ── Add more button ──
        GestureDetector(
          onTap: _showMediaInput,
          child: Row(
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Add more',
                style: tt.labelMedium?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ATTACHMENT CHIPS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAttachmentChips(ColorScheme cs, PostComposerState state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Vibe
          _AttachChip(
            icon: Icons.mood_rounded,
            label: state.hasVibe ? (state.vibeName ?? 'Vibe') : 'Vibe',
            active: state.hasVibe,
            onTap: _showVibesPicker,
          ),
          const SizedBox(width: 8),

          // Sport
          _AttachChip(
            icon: Icons.sports_rounded,
            label: state.hasSport ? (state.sportName ?? 'Sport') : 'Sport',
            active: state.hasSport,
            onTap: _showSportsPicker,
          ),
          const SizedBox(width: 8),

          // Location
          const ComposerLocationChip(),
          const SizedBox(width: 8),

          // Game
          _AttachChip(
            icon: Icons.sports_esports_rounded,
            label: state.hasGame ? (state.gameName ?? 'Game') : 'Game',
            active: state.hasGame,
            onTap: _showGamePicker,
          ),
          const SizedBox(width: 8),

          // Media
          if (!state.hasMedia) ...[
            _AttachChip(
              icon: Icons.image_outlined,
              label: 'Media',
              active: false,
              onTap: _showMediaInput,
            ),
            const SizedBox(width: 8),
            _AttachChip(
              icon: Icons.gif_box_rounded,
              label: 'GIF',
              active: false,
              onTap: _showGifPicker,
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OPTIONS SECTION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildOptionsSection(
    ColorScheme cs,
    TextTheme tt,
    PostComposerState state,
  ) {
    const onBg = Color(0xFF1D1A20);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Options',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: onBg,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 12),

          _OptionToggle(
            icon: Iconsax.convert_copy,
            label: 'Allow reposts',
            subtitle: 'Others can share this post',
            value: state.allowReposts,
            colored: true,
            onChanged: (_) =>
                ref.read(postComposerProvider.notifier).toggleAllowReposts(),
          ),
          const SizedBox(height: 10),

          _OptionToggle(
            icon: Iconsax.archive_tick_copy,
            label: 'Pin to profile',
            subtitle: 'Keep this post at the top of your profile',
            value: state.isPinned,
            colored: false,
            onChanged: (_) =>
                ref.read(postComposerProvider.notifier).togglePinned(),
          ),
          const SizedBox(height: 10),

          _OptionLink(
            icon: Iconsax.clock,
            label: state.expiresAt != null
                ? 'Expires: ${_formatDate(state.expiresAt!)}'
                : 'Set expiry',
            subtitle: 'Post auto-hides after this date',
            value: state.expiresAt != null ? 'Set' : null,
            onTap: _showExpiryPicker,
          ),
          const SizedBox(height: 10),

          _OptionLink(
            icon: state.contentClass == 'editorial'
                ? Iconsax.document_text
                : Iconsax.people,
            label: 'Content: ${_prettifyLabel(state.contentClass)}',
            subtitle: 'Categorise this post for discovery',
            value: _prettifyLabel(state.contentClass),
            onTap: _showContentClassPicker,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  IconData _visibilityIcon(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return Icons.public;
      case PostVisibility.followers:
        return Icons.people;
      case PostVisibility.circle:
        return Icons.circle_outlined;
      case PostVisibility.squad:
        return Icons.groups;
      case PostVisibility.private:
        return Icons.lock;
      case PostVisibility.link:
        return Icons.link;
    }
  }

  String _visibilityLabel(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return 'Public';
      case PostVisibility.followers:
        return 'Followers';
      case PostVisibility.circle:
        return 'Circle';
      case PostVisibility.squad:
        return 'Squad';
      case PostVisibility.private:
        return 'Private';
      case PostVisibility.link:
        return 'Link Only';
    }
  }

  String _visibilityDescription(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return 'Anyone can see this post';
      case PostVisibility.followers:
        return 'Only your followers can see this';
      case PostVisibility.circle:
        return 'Shared with a specific circle';
      case PostVisibility.squad:
        return 'Shared with your squad';
      case PostVisibility.private:
        return 'Only you can see this';
      case PostVisibility.link:
        return 'Only people with the link can see this';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _postTypeIcon(PostType t) {
    switch (t) {
      case PostType.moment:
        return Icons.flash_on_rounded;
      case PostType.dab:
        return Icons.thumb_up_rounded;
      case PostType.kickIn:
        return Icons.people_alt_rounded;
      default:
        return Icons.article_outlined;
    }
  }

  String _postTypeLabel(PostType t) {
    switch (t) {
      case PostType.moment:
        return 'Moment';
      case PostType.dab:
        return 'Dab';
      case PostType.kickIn:
        return 'Kick-in';
      default:
        return t.name;
    }
  }

  String _postTypeDescription(PostType t) {
    switch (t) {
      case PostType.moment:
        return 'A quick snapshot of right now';
      case PostType.dab:
        return 'Share what you\'re vibing with';
      case PostType.kickIn:
        return 'Invite others to join in';
      default:
        return '';
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── Post-specific design helpers ──────────────────────────────────────────────

class _PostButton extends StatelessWidget {
  const _PostButton({
    required this.canPost,
    required this.isSubmitting,
    required this.onTap,
  });

  final bool canPost;
  final bool isSubmitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7328CE);
    const bgDark = Color(0xFFEDE6EE);
    const muted = Color(0xFF8B849A);

    return GestureDetector(
      onTap: canPost ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: canPost ? primary : bgDark,
          borderRadius: BorderRadius.circular(999),
          boxShadow: canPost
              ? [BoxShadow(color: primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))]
              : null,
        ),
        child: isSubmitting
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(
                'Post',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: canPost ? Colors.white : muted,
                ),
              ),
      ),
    );
  }
}

class _PostDividerSection extends StatelessWidget {
  const _PostDividerSection({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const outline = Color(0xFFDDD6E4);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: outline, width: 1)),
      ),
      child: child,
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({
    required this.label,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Sheet drag handle.
class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Compact pill button for kind/visibility selectors (ChipDrop style).
class _ComposerPill extends StatelessWidget {
  const _ComposerPill({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.activeColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.only(left: 10, right: 12),
        decoration: BoxDecoration(
          color: Color.fromRGBO(
            (activeColor.r * 255).round(),
            (activeColor.g * 255).round(),
            (activeColor.b * 255).round(),
            0.08,
          ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.33),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: activeColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: activeColor),
          ],
        ),
      ),
    );
  }
}

/// Attachment chip (unified add + selected state).
class _AttachChip extends StatelessWidget {
  const _AttachChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7328CE);
    const bgDark = Color(0xFFEDE6EE);
    const outline = Color(0xFFDDD6E4);
    const muted = Color(0xFF8B849A);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 34,
        padding: const EdgeInsets.only(left: 10, right: 14),
        decoration: BoxDecoration(
          color: active ? const Color(0x207328CE) : bgDark,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? const Color(0x507328CE) : outline,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? primary : muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: active ? primary : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Options row with icon box and custom toggle.
class _OptionToggle extends StatelessWidget {
  const _OptionToggle({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.colored,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool colored;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF7328CE);
    const surface = Color(0xFFFEF7FF);
    const bgDark = Color(0xFFEDE6EE);
    const outline = Color(0xFFDDD6E4);
    const muted = Color(0xFF8B849A);
    const onBg = Color(0xFF1D1A20);
    const outlineVar = Color(0xFFCBC4CF);

    final isActive = value && colored;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isActive ? const Color(0x087328CE) : surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? const Color(0x407328CE) : outline,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive ? const Color(0x157328CE) : bgDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 17, color: isActive ? primary : muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? primary : onBg,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 26,
              decoration: BoxDecoration(
                color: value ? primary : outlineVar,
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1))],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Options row with icon box and chevron (tap to navigate).
class _OptionLink extends StatelessWidget {
  const _OptionLink({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final String? value;

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFFEF7FF);
    const bgDark = Color(0xFFEDE6EE);
    const outline = Color(0xFFDDD6E4);
    const muted = Color(0xFF8B849A);
    const onBg = Color(0xFF1D1A20);
    const primary = Color(0xFF7328CE);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: outline, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 17, color: muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: onBg,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}

/// Visual thumbnail tile for a media URL (image / GIF).
/// Shows the image with a rounded remove button overlay.
class _MediaPreviewTile extends StatelessWidget {
  const _MediaPreviewTile({
    required this.url,
    required this.onRemove,
    required this.cs,
    this.height,
    this.width,
  });

  final String url;
  final VoidCallback onRemove;
  final ColorScheme cs;
  final double? height;
  final double? width;

  bool get _isGif => url.toLowerCase().contains('.gif');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Stack(
        children: [
          // Thumbnail
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: cs.surfaceContainerHighest,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 32,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isGif ? 'GIF' : 'Image',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // GIF badge
          if (_isGif)
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.inverseSurface.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'GIF',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

          // Remove button
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cs.error.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 14, color: cs.onError),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════════
// VIBES PICKER SHEET (for composer)
// ═════════════════════════════════════════════════════════════════════════════

class _ComposerVibesPickerSheet extends ConsumerStatefulWidget {
  const _ComposerVibesPickerSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_ComposerVibesPickerSheet> createState() =>
      _ComposerVibesPickerSheetState();
}

class _ComposerVibesPickerSheetState
    extends ConsumerState<_ComposerVibesPickerSheet> {
  String? _activeTypeFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vibesAsync = ref.watch(vibesProvider);
    final composerState = ref.watch(postComposerProvider);

    return SafeArea(
      child: Column(
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Text(
                  'Vibes',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (composerState.vibeId != null)
                  TextButton(
                    onPressed: () {
                      ref.read(postComposerProvider.notifier).clearVibe();
                      Navigator.pop(context);
                    },
                    child: Text('Clear', style: TextStyle(color: cs.primary)),
                  ),
              ],
            ),
          ),

          // Filter chips
          vibesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (vibes) {
              final types =
                  vibes
                      .where((v) => v.type != null && v.type!.isNotEmpty)
                      .map((v) => v.type!)
                      .toSet()
                      .toList()
                    ..sort();
              if (types.length <= 1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ComposerFilterChip(
                        label: 'All',
                        isSelected: _activeTypeFilter == null,
                        onTap: () => setState(() => _activeTypeFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final type in types) ...[
                        _ComposerFilterChip(
                          label: _prettifyLabel(type),
                          isSelected: _activeTypeFilter == type,
                          onTap: () => setState(() => _activeTypeFilter = type),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // Grid
          Expanded(
            child: vibesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load vibes',
                  style: TextStyle(color: cs.error),
                ),
              ),
              data: (vibes) {
                var filtered = vibes.toList();
                if (_activeTypeFilter != null) {
                  filtered = filtered
                      .where((v) => v.type == _activeTypeFilter)
                      .toList();
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No vibes available',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }
                return GridView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final vibe = filtered[i];
                    final isSelected = vibe.id == composerState.vibeId;
                    return GestureDetector(
                      onTap: () {
                        ref
                            .read(postComposerProvider.notifier)
                            .setVibe(
                              id: vibe.id,
                              label: vibe.labelEn,
                              emoji: vibe.emoji,
                            );
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primaryContainer
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: cs.primary, width: 2)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              vibe.emoji ?? '✨',
                              style: const TextStyle(fontSize: 28),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vibe.labelEn,
                              style: tt.labelSmall?.copyWith(
                                color: isSelected
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LOCATION PICKER SHEET


// ═════════════════════════════════════════════════════════════════════════════
// LOCATION PICKER SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _LocationPickerSheet extends ConsumerStatefulWidget {
  const _LocationPickerSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  // Manual location entry
  final _manualNameController = TextEditingController();
  bool _showManualEntry = false;

  @override
  void dispose() {
    _searchController.dispose();
    _manualNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Text(
                  'Location',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(postComposerProvider.notifier).clearLocation();
                    Navigator.pop(context);
                  },
                  child: Text('Clear', style: TextStyle(color: cs.primary)),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search venues...',
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _query = value);
              },
            ),
          ),

          // Manual entry option
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    Icons.edit_location_alt,
                    color: cs.onSurfaceVariant,
                  ),
                  title: Text(
                    'Type a location',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                  trailing: Icon(
                    _showManualEntry ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                  ),
                  onTap: () =>
                      setState(() => _showManualEntry = !_showManualEntry),
                ),
                if (_showManualEntry) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _manualNameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Central Park, NYC',
                      filled: true,
                      fillColor: cs.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.check, color: cs.primary),
                        onPressed: () {
                          final name = _manualNameController.text.trim();
                          if (name.isNotEmpty) {
                            ref
                                .read(postComposerProvider.notifier)
                                .setRawLocation(name: name);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
              ],
            ),
          ),

          // Venue search results
          Expanded(
            child: _query.trim().length >= 2
                ? Consumer(
                    builder: (ctx, ref, _) {
                      final venuesAsync = ref.watch(
                        venueSearchProvider(_query),
                      );
                      return venuesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text(
                            'Search failed',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                        data: (venues) {
                          if (venues.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 48,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No venues found',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: widget.scrollController,
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            itemCount: venues.length,
                            itemBuilder: (ctx, i) {
                              final venue = venues[i];
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(Icons.sports, color: cs.primary),
                                title: Text(
                                  venue['name'] as String? ?? 'Venue',
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                                subtitle: venue['city'] != null
                                    ? Text(
                                        venue['city'] as String,
                                        style: tt.labelSmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(postComposerProvider.notifier)
                                      .setVenue(
                                        id: venue['id'] as String,
                                        name:
                                            venue['name'] as String? ?? 'Venue',
                                        lat: venue['geo_lat'] as double?,
                                        lng: venue['geo_lng'] as double?,
                                      );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search,
                          size: 48,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search for a venue or type a location',
                          style: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VENUE PICKER SHEET  (searches public.venues by name_en)
// ═════════════════════════════════════════════════════════════════════════════

class _VenuePickerSheet extends ConsumerStatefulWidget {
  const _VenuePickerSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_VenuePickerSheet> createState() => _VenuePickerSheetState();
}

class _VenuePickerSheetState extends ConsumerState<_VenuePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Text(
                  'Select Venue',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(postComposerProvider.notifier).clearVenue();
                    Navigator.pop(context);
                  },
                  child: Text('Clear', style: TextStyle(color: cs.primary)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search venues...',
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: _query.trim().length >= 2
                ? Consumer(
                    builder: (ctx, ref, _) {
                      final async = ref.watch(venueSearchProvider(_query));
                      return async.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text(
                            'Search failed',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                        data: (venues) {
                          if (venues.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stadium_outlined,
                                    size: 48,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No venues found',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: widget.scrollController,
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            itemCount: venues.length,
                            itemBuilder: (ctx, i) {
                              final venue = venues[i];
                              final name =
                                  venue['name_en'] as String? ?? 'Venue';
                              final city = venue['city'] as String? ?? '';
                              final lat = (venue['geo_lat'] as num?)
                                  ?.toDouble();
                              final lng = (venue['geo_lng'] as num?)
                                  ?.toDouble();
                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(
                                  Icons.stadium_outlined,
                                  color: cs.primary,
                                ),
                                title: Text(
                                  name,
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                                subtitle: city.isNotEmpty
                                    ? Text(
                                        city,
                                        style: tt.labelSmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(postComposerProvider.notifier)
                                      .setVenue(
                                        id: venue['id'] as String,
                                        name: name,
                                        lat: lat,
                                        lng: lng,
                                      );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.stadium_outlined,
                          size: 48,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Type at least 2 characters to search venues',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GAME PICKER SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _GamePickerSheet extends ConsumerStatefulWidget {
  const _GamePickerSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_GamePickerSheet> createState() => _GamePickerSheetState();
}

class _GamePickerSheetState extends ConsumerState<_GamePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Text(
                  'Link a Game',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(postComposerProvider.notifier).clearGame();
                    Navigator.pop(context);
                  },
                  child: Text('Clear', style: TextStyle(color: cs.primary)),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search games by title...',
                prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() => _query = value);
              },
            ),
          ),

          // Game search results
          Expanded(
            child: _query.trim().length >= 2
                ? Consumer(
                    builder: (ctx, ref, _) {
                      final gamesAsync = ref.watch(gameSearchProvider(_query));
                      return gamesAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text(
                            'Search failed',
                            style: TextStyle(color: cs.error),
                          ),
                        ),
                        data: (games) {
                          if (games.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sports_esports,
                                    size: 48,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No games found',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return ListView.builder(
                            controller: widget.scrollController,
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            itemCount: games.length,
                            itemBuilder: (ctx, i) {
                              final game = games[i];
                              final title =
                                  game['title'] as String? ?? 'Untitled Game';
                              final sport = game['sport'] as String? ?? '';
                              final gameType =
                                  game['game_type'] as String? ?? '';
                              final startAt = game['start_at'] as String?;
                              final subtitle = [
                                if (sport.isNotEmpty) sport,
                                if (gameType.isNotEmpty) gameType,
                                if (startAt != null)
                                  DateTime.tryParse(startAt) != null
                                      ? '${DateTime.parse(startAt).day}/${DateTime.parse(startAt).month}/${DateTime.parse(startAt).year}'
                                      : '',
                              ].where((s) => s.isNotEmpty).join(' · ');

                              return ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(
                                  Icons.sports_esports,
                                  color: cs.primary,
                                ),
                                title: Text(
                                  title,
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurface,
                                  ),
                                ),
                                subtitle: subtitle.isNotEmpty
                                    ? Text(
                                        subtitle,
                                        style: tt.labelSmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      )
                                    : null,
                                onTap: () {
                                  ref
                                      .read(postComposerProvider.notifier)
                                      .setGame(
                                        id: game['id'] as String,
                                        name: title,
                                      );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports_esports,
                          size: 48,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Search for a game to link to your post',
                          style: TextStyle(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED FILTER CHIP (composer version)
// ═════════════════════════════════════════════════════════════════════════════

class _ComposerFilterChip extends StatelessWidget {
  const _ComposerFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// HASHTAG-AWARE TEXT EDITING CONTROLLER
// =============================================================================

/// A [TextEditingController] that highlights `#hashtag` tokens with a
/// distinct colour while keeping the underlying plain text unchanged.
class _HashtagTextEditingController extends TextEditingController {
  _HashtagTextEditingController();

  static final _hashtagRegex = RegExp(r'#\w+', unicode: true);

  /// The colour applied to hashtag tokens. Updated from the widget tree
  /// once the theme is available.
  Color hashtagColor = Colors.blue;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final txt = text;
    if (txt.isEmpty) return TextSpan(text: txt, style: style);

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _hashtagRegex.allMatches(txt)) {
      // Text before the hashtag.
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: txt.substring(lastEnd, match.start), style: style),
        );
      }
      // The hashtag itself.
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style?.copyWith(
            color: hashtagColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = match.end;
    }

    // Remaining text after the last hashtag.
    if (lastEnd < txt.length) {
      spans.add(TextSpan(text: txt.substring(lastEnd), style: style));
    }

    return TextSpan(children: spans, style: style);
  }
}

// =============================================================================
// GIF PICKER SHEET (GIPHY)
// =============================================================================

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet({
    required this.scrollController,
    required this.onSelected,
  });

  final ScrollController scrollController;
  final ValueChanged<String> onSelected;

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  static const _baseUrl = 'https://api.giphy.com/v1/gifs';

  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  int _offset = 0;
  bool _hasMore = true;
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _apiKey = Environment.giphyApiKey;
    if (_apiKey.isEmpty) {
      _error = 'GIPHY API key not configured';
      return;
    }
    _loadTrending();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final uri = Uri.parse('$_baseUrl/trending').replace(
        queryParameters: {
          'api_key': _apiKey,
          'limit': '30',
          'offset': '0',
          'rating': 'pg-13',
          'bundle': 'messaging_non_clips',
        },
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed to load GIFs';
        });
        return;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List).cast<Map<String, dynamic>>();
      final pagination = body['pagination'] as Map<String, dynamic>?;
      setState(() {
        _results = data;
        _offset = 30;
        _hasMore = (pagination?['total_count'] as int? ?? 0) > _offset;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load GIFs';
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      _loadTrending();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {
          'api_key': _apiKey,
          'q': query,
          'limit': '30',
          'offset': '0',
          'rating': 'pg-13',
          'bundle': 'messaging_non_clips',
        },
      );
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Search failed';
        });
        return;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['data'] as List).cast<Map<String, dynamic>>();
      final pagination = body['pagination'] as Map<String, dynamic>?;
      setState(() {
        _results = data;
        _offset = 30;
        _hasMore = (pagination?['total_count'] as int? ?? 0) > _offset;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Search failed';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final query = _searchController.text.trim();
    setState(() => _loading = true);
    try {
      final endpoint = query.isEmpty ? 'trending' : 'search';
      final params = <String, String>{
        'api_key': _apiKey,
        'limit': '30',
        'offset': '$_offset',
        'rating': 'pg-13',
        'bundle': 'messaging_non_clips',
      };
      if (query.isNotEmpty) params['q'] = query;
      final uri = Uri.parse(
        '$_baseUrl/$endpoint',
      ).replace(queryParameters: params);
      final response = await http.get(uri);
      if (!mounted) return;
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = (body['data'] as List).cast<Map<String, dynamic>>();
        final pagination = body['pagination'] as Map<String, dynamic>?;
        setState(() {
          _results.addAll(data);
          _offset += 30;
          _hasMore = (pagination?['total_count'] as int? ?? 0) > _offset;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(value);
    });
  }

  /// Extract the full-size GIF URL to store in the post media list.
  String? _getGifUrl(Map<String, dynamic> gif) {
    final images = gif['images'] as Map<String, dynamic>?;
    if (images == null) return null;
    // Prefer original, fall back to downsized
    final original = images['original'] as Map<String, dynamic>?;
    final downsized = images['downsized'] as Map<String, dynamic>?;
    return (original?['url'] as String?) ?? (downsized?['url'] as String?);
  }

  /// Extract a small preview URL for the grid (fast loading).
  String? _getPreviewUrl(Map<String, dynamic> gif) {
    final images = gif['images'] as Map<String, dynamic>?;
    if (images == null) return null;
    final fixedWidth = images['fixed_width'] as Map<String, dynamic>?;
    final preview = images['preview_gif'] as Map<String, dynamic>?;
    final downsizedSmall = images['fixed_width_small'] as Map<String, dynamic>?;
    return (fixedWidth?['url'] as String?) ??
        (preview?['url'] as String?) ??
        (downsizedSmall?['url'] as String?);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            'Search GIFs',
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search GIPHY...',
              prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: cs.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        _loadTrending();
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 8),

        // Error state
        if (_error != null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: cs.error),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: tt.bodyMedium?.copyWith(color: cs.error),
                  ),
                ],
              ),
            ),
          )
        // Loading + empty state
        else if (_loading && _results.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_results.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No GIFs found',
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          )
        // Grid
        else
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 200) {
                  _loadMore();
                }
                return false;
              },
              child: GridView.builder(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _results.length + (_loading ? 1 : 0),
                itemBuilder: (ctx, index) {
                  if (index >= _results.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }

                  final gif = _results[index];
                  final previewUrl = _getPreviewUrl(gif);
                  if (previewUrl == null) return const SizedBox.shrink();

                  return GestureDetector(
                    onTap: () {
                      final gifUrl = _getGifUrl(gif);
                      if (gifUrl != null) {
                        widget.onSelected(gifUrl);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        color: cs.surfaceContainerHighest,
                        child: Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                          progress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

        // GIPHY attribution (required by GIPHY ToS)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gif_box, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Powered by GIPHY',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
