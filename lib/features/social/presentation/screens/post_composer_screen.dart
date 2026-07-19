import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/design_system/tokens/avatar_color_palette.dart';
import 'package:dabbler/core/design_system/tokens/avatar_tokens.dart';
import 'package:dabbler/core/design_system/widgets/ds_avatar.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';

import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';

// Composer drawer chrome + glass palette is shared via composer_drawer_kit.dart.

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
                  style: (state.visibility == v
                          ? Theme.of(ctx).textTheme.titleMedium
                          : Theme.of(ctx).textTheme.bodyMedium)
                      ?.copyWith(
                    color: state.visibility == v ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  _visibilityDescription(v),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
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
          name: sport.localizedName(context),
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

  void _showLocationPicker() {
    final cs = Theme.of(context).colorScheme;

    showAdaptiveSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) =>
            _LocationPickerSheet(scrollController: scrollController),
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
                  style: (state.postType == t
                          ? Theme.of(ctx).textTheme.titleMedium
                          : Theme.of(ctx).textTheme.bodyMedium)
                      ?.copyWith(
                    color: state.postType == t ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  _postTypeDescription(t),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
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

  // Retained while the Category row is hidden — see _buildOptionsSection.
  // ignore: unused_element
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
                  style: (state.contentClass == cc
                          ? Theme.of(ctx).textTheme.titleMedium
                          : Theme.of(ctx).textTheme.bodyMedium)
                      ?.copyWith(
                    color: state.contentClass == cc ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  cc == 'social'
                      ? 'Standard social post'
                      : 'Editorial or long-form content',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
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
                style: tt.titleMedium?.copyWith(color: cs.onSurface),
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

    final shell = ComposerDrawerShell(
      title: 'Create Post',
      ctaLabel: 'Post',
      canSubmit: composerState.canSubmit,
      isSubmitting: composerState.isSubmitting,
      onCtaTap: _submit,
      errorMessage: composerState.error,
      children: [
        // Author row — pad [4, 20, 0, 20] per Pencil
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: _buildAuthorRow(cs, tt),
        ),
        // Post type / visibility row — pad [8, 20]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: _buildKindVisibilityRow(cs, composerState),
        ),
        // Input area card — pad [4, 20]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: _buildTextBoxCard(cs, tt, composerState),
        ),
        // Media — pad [6, 20]
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: composerState.hasMedia
              ? _buildMediaTilesRow(cs, composerState)
              : _buildMediaActions(cs),
        ),
        _buildOptionsSection(cs, tt, composerState),
      ],
    );

    // On wide (iPad/desktop) screens, constrain the composer drawer to a
    // comfortable width and align it to the bottom rather than stretching
    // edge-to-edge. A side nav would fight the composer UX here.
    if (MediaQuery.of(context).size.width >= AdaptiveBreakpoints.compact) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: shell,
        ),
      );
    }
    return shell;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUTHOR ROW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAuthorRow(ColorScheme cs, TextTheme tt) {
    final displayName =
        _userProfile?['display_name'] as String? ??
        _userProfile?['username'] as String? ??
        'You';
    final avatarUrl = _userProfile?['avatar_url'] as String?;
    final composerState = ref.watch(postComposerProvider);
    final activePersona = ref.watch(activeProfileTypeProvider);
    final canSwitch = activePersona != null && activePersona.isNotEmpty;

    return Semantics(
      label: canSwitch
          ? 'Posting as $displayName. Tap to switch profile.'
          : 'Posting as $displayName',
      button: canSwitch,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: canSwitch ? _showProfileSwitchPicker : null,
        child: Row(
          children: [
            DSAvatar(
              size: AvatarSize.medium,
              customDimension: 44,
              imageUrl: avatarUrl,
              displayName: displayName,
              context: AvatarContext.main,
              backgroundColor: cs.primaryContainer,
              foregroundColor: cs.onPrimaryContainer,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: tt.titleSmall?.copyWith(
                    color: ComposerPalette.of(context).textBright,
                  ),
                ),
                if (canSwitch) ...[
                  const SizedBox(height: 2),
                  Text(
                    _prettifyLabel(
                      composerState.personaTypeSnapshot ?? activePersona,
                    ),
                    style: tt.bodySmall?.copyWith(
                      color: ComposerPalette.of(context).textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
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
          semanticLabel:
              'Post type: ${_postTypeLabel(composerState.postType)}. '
              'Tap to change.',
          onTap: _showPostTypePicker,
          filled: true,
        ),
        _ComposerPill(
          icon: _visibilityIcon(composerState.visibility),
          label: _visibilityLabel(composerState.visibility),
          semanticLabel:
              'Visibility: ${_visibilityLabel(composerState.visibility)}. '
              'Tap to change.',
          onTap: _showVisibilityPicker,
          filled: false,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEXT BOX CARD (body + tags + enrich toolbar)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTextBoxCard(
    ColorScheme cs,
    TextTheme tt,
    PostComposerState composerState,
  ) {
    const maxLen = 2000;
    final bodyLen = composerState.body.length;
    final hasLocation = composerState.locationName != null;

    final tagPills = <Widget>[
      if (composerState.hasSport && composerState.sportName != null)
        _BodyTagPill(
          icon: Icons.emoji_events_rounded,
          label: composerState.sportName!.toUpperCase(),
          variant: _BodyTagVariant.primary,
        ),
      if (hasLocation)
        _BodyTagPill(
          icon: Icons.location_on_rounded,
          label: composerState.locationName!,
          variant: _BodyTagVariant.primary,
        ),
      if (composerState.hasGame && composerState.gameName != null)
        _BodyTagPill(
          icon: Icons.sports_esports_rounded,
          label: composerState.gameName!,
          variant: _BodyTagVariant.tertiary,
        ),
    ];

    final anyFilled =
        composerState.hasVibe ||
        composerState.hasSport ||
        hasLocation ||
        composerState.hasGame ||
        bodyLen > 0;

    final palette = ComposerPalette.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: palette.bgGlass,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.borderStrong, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tagPills.isNotEmpty) ...[
                Wrap(spacing: 8, runSpacing: 6, children: tagPills),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                maxLines: null,
                minLines: 4,
                style: tt.bodyMedium?.copyWith(
                  height: 1.5,
                  color: palette.textBright,
                ),
                decoration: InputDecoration(
                  hintText: "What's on your mind? Use #hashtags",
                  hintStyle: tt.bodyMedium?.copyWith(
                    height: 1.5,
                    color: palette.textFaint,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  fillColor: Colors.transparent,
                ),
                onChanged: (value) {
                  ref.read(postComposerProvider.notifier).setBody(value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (composerState.hasVibe && composerState.vibeName != null)
                    _VibeBadge(
                      emoji: composerState.vibeEmoji,
                      label: composerState.vibeName!,
                    ),
                  const Spacer(),
                  // Non-colour cue (WCAG 1.4.1): weight bumps to bold near
                  // the limit alongside the colour change so colour-blind
                  // users still get the warning.
                  Text(
                    '$bodyLen/$maxLen',
                    semanticsLabel: '$bodyLen of $maxLen characters used',
                    // labelMedium near limit (heavier per DS) doubles as the
                    // WCAG 1.4.1 non-colour cue alongside the pink colour swap.
                    style: (bodyLen > maxLen * 0.9
                            ? tt.labelMedium
                            : tt.bodySmall)
                        ?.copyWith(
                      color: bodyLen > maxLen * 0.9
                          ? kComposerPink
                          : (anyFilled ? palette.textSubtle : palette.textFaint),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: palette.borderGlass, width: 1),
                  ),
                ),
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _EnrichToolButton(
                        icon: Icons.mood_outlined,
                        filledIcon: Icons.mood_rounded,
                        active: composerState.hasVibe,
                        inactiveColor: palette.textMuted,
                        semanticLabel: composerState.hasVibe
                            ? 'Vibe: ${composerState.vibeName ?? "set"}. '
                                  'Tap to change.'
                            : 'Add vibe',
                        onTap: _showVibesPicker,
                      ),
                    ),
                    Expanded(
                      child: _EnrichToolButton(
                        icon: Icons.emoji_events_outlined,
                        filledIcon: Icons.emoji_events_rounded,
                        active: composerState.hasSport,
                        inactiveColor: palette.textMuted,
                        semanticLabel: composerState.hasSport
                            ? 'Sport: ${composerState.sportName ?? "set"}. '
                                  'Tap to change.'
                            : 'Add sport',
                        onTap: _showSportsPicker,
                      ),
                    ),
                    Expanded(
                      child: _EnrichToolButton(
                        icon: Icons.location_on_outlined,
                        filledIcon: Icons.location_on_rounded,
                        active: hasLocation,
                        inactiveColor: palette.textMuted,
                        semanticLabel: hasLocation
                            ? 'Location: ${composerState.locationName}. '
                                  'Tap to change.'
                            : 'Add location',
                        onTap: _showLocationPicker,
                      ),
                    ),
                    Expanded(
                      child: _EnrichToolButton(
                        icon: Icons.sports_esports_outlined,
                        filledIcon: Icons.sports_esports_rounded,
                        active: composerState.hasGame,
                        inactiveColor: palette.textMuted,
                        semanticLabel: composerState.hasGame
                            ? 'Game: ${composerState.gameName ?? "set"}. '
                                  'Tap to change.'
                            : 'Link a game',
                        onTap: _showGamePicker,
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

  // ═══════════════════════════════════════════════════════════════════════
  // MEDIA SECTION
  // ═══════════════════════════════════════════════════════════════════════

  /// Empty state — Media + Add GIF as two side-by-side glass pills sharing
  /// the row (per-product call: a horizontal pair instead of Pencil's
  /// stacked layout).
  Widget _buildMediaActions(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _MediaActionButton(
            icon: Iconsax.gallery_add,
            label: 'Media',
            contentGap: 10,
            onTap: _showMediaInput,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MediaActionButton(
            icon: Iconsax.image,
            label: 'Add GIF',
            contentGap: 10,
            onTap: _showGifPicker,
          ),
        ),
      ],
    );
  }

  /// Filled state — horizontal 150-tall row: main 200 wide + extras 100 wide +
  /// trailing 48-wide "Add More" tile. Each image tile has its own X-remove.
  Widget _buildMediaTilesRow(ColorScheme cs, PostComposerState state) {
    final items = state.media;
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: items.length + 1,
        itemBuilder: (_, i) {
          if (i == items.length) {
            return _AddMoreTile(onTap: _showMediaInput);
          }
          final url = items[i].toString();
          final width = i == 0 ? 200.0 : 100.0;
          return _MediaTile(
            url: url,
            width: width,
            onRemove: () => ref
                .read(postComposerProvider.notifier)
                .removeMediaAt(i),
          );
        },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ComposerSettingsRow(
            icon: Icons.repeat_rounded,
            title: 'Allow reposts',
            subtitle: 'Others can share this post',
            trailing: ComposerToggle(
              value: state.allowReposts,
              onChanged: (_) => ref
                  .read(postComposerProvider.notifier)
                  .toggleAllowReposts(),
            ),
            showDivider: true,
          ),
          ComposerSettingsRow(
            icon: Icons.push_pin_outlined,
            title: 'Pin to profile',
            subtitle: 'Keep at the top of your profile',
            trailing: ComposerToggle(
              value: state.isPinned,
              onChanged: (_) =>
                  ref.read(postComposerProvider.notifier).togglePinned(),
            ),
            showDivider: true,
          ),
          // Category hidden for now — re-enable when discovery categories ship.
          // ComposerSettingsRow(
          //   icon: Icons.grid_view_outlined,
          //   title: 'Category',
          //   subtitle: 'Categorise for discovery',
          //   trailing: ComposerSelectPill(
          //     value: _prettifyLabel(state.contentClass),
          //     caret: ComposerSelectCaret.down,
          //     onTap: _showContentClassPicker,
          //   ),
          //   showDivider: true,
          // ),
          ComposerSettingsRow(
            icon: Icons.schedule_outlined,
            title: 'Set expiry',
            subtitle: 'Auto-hides after date',
            trailing: ComposerSelectPill(
              value: state.expiresAt != null
                  ? _formatDate(state.expiresAt!)
                  : 'None',
              caret: ComposerSelectCaret.right,
              onTap: _showExpiryPicker,
            ),
            showDivider: false,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  IconData _visibilityIcon(PostVisibility v) {
    // Visibility chip uses the outlined-glass style — pair it with outline
    // icons. `link` and `circle_outlined` only ship as a single weight.
    switch (v) {
      case PostVisibility.public:
        return Icons.public_outlined;
      case PostVisibility.followers:
        return Icons.people_outline;
      case PostVisibility.circle:
        return Icons.circle_outlined;
      case PostVisibility.squad:
        return Icons.groups_outlined;
      case PostVisibility.private:
        return Icons.lock_outline;
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
// (Drawer handle + Post CTA button now live in composer_drawer_kit.dart.)


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

/// Compact pill button for kind/visibility selectors.
///
/// Two variants matching the Pencil design:
/// - `filled: true`  → solid primary glass (post-type), white content.
/// - `filled: false` → translucent surface glass with hairline border
///   (visibility), muted content.
///
/// Both wrap in a BackdropFilter so the chip refracts whatever sits behind
/// it, matching the Pencil `background_blur: 12` effect.
class _ComposerPill extends StatelessWidget {
  const _ComposerPill({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = ComposerPalette.of(context);

    // Pencil exact alphas:
    // filled  → primary @53%, no border, white content (same in both themes)
    // outline → bgGlass + borderGlass stroke, textMuted content
    final bg = filled
        ? cs.primary.withValues(alpha: 0.53)
        : palette.bgGlass;
    final fg = filled ? Colors.white : palette.textMuted;
    final caretColor = filled
        ? Colors.white.withValues(alpha: 0.67)
        : palette.textMuted.withValues(alpha: 0.60);
    final border = filled
        ? null
        : Border.all(color: palette.borderGlass, width: 1);

    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
                border: border,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: caretColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual variant for body tag pills.
enum _BodyTagVariant { primary, tertiary }

/// Tag pill rendered above the body TextField (sport / location / game).
///
/// Pencil exact:
/// - `primary`  → fill #7328CE99 (cs.primary @60%), no border, white content.
/// - `tertiary` → fill #FF86DD18 (pink @9%), stroke #FF86DD33 (pink @20%),
///   pink content.
/// Both: radius 10, pad [4, 10], gap 6, blur 8, 14px icon, label 10/600.
class _BodyTagPill extends StatelessWidget {
  const _BodyTagPill({
    required this.icon,
    required this.label,
    required this.variant,
  });

  final IconData icon;
  final String label;
  final _BodyTagVariant variant;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPrimary = variant == _BodyTagVariant.primary;
    final bg = isPrimary
        ? cs.primary.withValues(alpha: 0.60)
        : kComposerPink.withValues(alpha: 0.09);
    final fg = isPrimary ? Colors.white : kComposerPink;
    final border = isPrimary
        ? null
        : Border.all(color: kComposerPink.withValues(alpha: 0.20), width: 1);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pink vibe badge shown next to the char counter inside the card.
/// Pencil "Sport Badge" — fill #FF86DD22 + stroke #FF86DD44 1px, blur 8,
/// radius 10, pad [2, 8], gap 6, emoji 12 white + label 10/600 pink.
class _VibeBadge extends StatelessWidget {
  const _VibeBadge({required this.emoji, required this.label});

  final String? emoji;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: kComposerPink.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: kComposerPink.withValues(alpha: 0.27),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null && emoji!.isNotEmpty) ...[
                Text(
                  emoji!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: kComposerPink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon-only button for the enrich toolbar at the bottom of the Text Box card.
/// Outline by default; swaps to the filled variant when `active`.
class _EnrichToolButton extends StatelessWidget {
  const _EnrichToolButton({
    required this.icon,
    required this.filledIcon,
    required this.active,
    required this.inactiveColor,
    required this.semanticLabel,
    required this.onTap,
  });

  /// Outline glyph rendered when `active` is false.
  final IconData icon;

  /// Filled glyph rendered when `active` is true.
  final IconData filledIcon;
  final bool active;
  final Color inactiveColor;

  /// Spoken label for screen readers ("Add vibe", "Vibe: Passionate", etc.).
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = active ? cs.primary : inactiveColor;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: active,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 40,
          child: Center(
            child: Icon(active ? filledIcon : icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

/// Full-width glass pill button used in the empty-state media section.
///
/// Pencil exact: bg #FFFFFF08 (white @3%) + stroke #FFFFFF12 (white @7%) 1px,
/// radius 14, blur 16, pad [12, 16]. Content centred: leading icon (20px
/// #CAC4CF) OR 40×24 GIF badge (radius 6, cs.primary @40%, "GIF" 11/w800
/// letter 0.8 #E6E0E9), gap, label 14/500 #CAC4CF.
class _MediaActionButton extends StatelessWidget {
  const _MediaActionButton({
    this.icon,
    required this.label,
    required this.onTap,
    required this.contentGap,
  });

  final IconData? icon;
  final String label;
  final VoidCallback onTap;
  final double contentGap;

  @override
  Widget build(BuildContext context) {
    final palette = ComposerPalette.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.bgWeak,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.borderWeak, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                
                  Icon(icon, size: 20, color: palette.textMuted),
                SizedBox(width: contentGap),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single image/GIF tile in the filled-state media row.
class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.url,
    required this.width,
    required this.onRemove,
  });

  final String url;
  final double width;
  final VoidCallback onRemove;

  bool get _isGif => url.toLowerCase().contains('.gif');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 150,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: ComposerPalette.of(context).tilePlaceholder,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 24,
                      color: ComposerPalette.of(context).textSubtle,
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
          if (_isGif)
            Positioned(
              left: 6,
              bottom: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'GIF',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Remove btn — 24×24 visible chip wrapped in a 44×44 hit area so
          // the tap target meets WCAG 2.5.8 / iOS HIG.
          Positioned(
            top: 0,
            right: 0,
            child: Semantics(
              label: 'Remove media',
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.40),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

/// 48×150 trailing "Add More" tile — opens the media picker.
/// Pencil: bg #FFFFFF08 (white @3%) + stroke #FFFFFF15 (white @8%) 1px,
/// radius 12, blur 12, plus icon 24px #79747E centred.
class _AddMoreTile extends StatelessWidget {
  const _AddMoreTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = ComposerPalette.of(context);
    return Semantics(
      label: 'Add more media',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 48,
              height: 150,
              decoration: BoxDecoration(
                color: palette.bgWeak,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.borderMid, width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: palette.textSubtle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _SettingsRow / _SettingsToggle / _SelectCaret / _SettingsSelectPill now live
// in composer_drawer_kit.dart as ComposerSettingsRow / ComposerToggle /
// ComposerSelectCaret / ComposerSelectPill.

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
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
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
                              style: tt.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vibe.labelEn,
                              style: (isSelected
                                      ? tt.titleSmall
                                      : tt.labelSmall)
                                  ?.copyWith(
                                color: isSelected
                                    ? cs.onPrimaryContainer
                                    : cs.onSurface,
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
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
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
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
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
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
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
          style: style?.copyWith(color: hashtagColor),
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
            style: tt.titleMedium?.copyWith(color: cs.onSurface),
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
