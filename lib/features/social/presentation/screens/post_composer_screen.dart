import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/gif_picker_sheet.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

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
    _bodyController = _HashtagTextEditingController();
    _loadUserProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bodyController.hashtagColor = DabblerColors.of(context).brandPrimary;
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

  void _errorToast(String message) {
    DabblerToastProvider.of(
      context,
    ).show(DabblerToastSpec(message: message, tone: DabblerToastTone.error));
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
        _errorToast(err.message);
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
    final state = ref.read(postComposerProvider);

    showComposerSheet<void>(
      context,
      title: 'Who can see this?',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circle visibility has no picker wired in this composer yet
          // (KAN-47) — selecting it always fails at submit time.
          for (final v in PostVisibility.values)
            if (v != PostVisibility.circle)
              ComposerPickerRow(
                icon: _visibilityIcon(v),
                title: _visibilityLabel(v),
                subtitle: _visibilityDescription(v),
                selected: state.visibility == v,
                onTap: () {
                  ref.read(postComposerProvider.notifier).setVisibility(v);
                  Navigator.pop(ctx);
                },
              ),
        ],
      ),
    );
  }

  void _showVibesPicker() {
    showComposerSheet<void>(
      context,
      title: 'Vibes',
      builder: (ctx) => const _ComposerVibesPickerSheet(),
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

    showComposerSheet<void>(
      context,
      title: 'Sports',
      builder: (_) => SportSelectionSheet(
        sportsProvider: activeSportsByProfileCountryProvider,
        selectedSport: selectedSport,
        showClear: composerState.sportId != null,
        onClear: () => ref.read(postComposerProvider.notifier).clearSport(),
        onSelect: (sport) => ref
            .read(postComposerProvider.notifier)
            .setSport(
              id: sport.id,
              name: sport.localizedName(context),
              emoji: sport.emoji,
            ),
      ),
    );
  }

  void _showExpiryPicker() {
    final now = DateTime.now();
    showComposerSheet<void>(
      context,
      title: 'Set expiry',
      builder: (ctx) => _ExpiryPickerSheet(
        first: now,
        last: now.add(const Duration(days: 365)),
        initial: now.add(const Duration(days: 1)),
        onPicked: (picked) {
          if (mounted) {
            ref.read(postComposerProvider.notifier).setExpiresAt(picked);
          }
        },
      ),
    );
  }

  void _showGamePicker() {
    showComposerSheet<void>(
      context,
      title: 'Link a Game',
      builder: (ctx) => const _GamePickerSheet(),
    );
  }

  void _showLocationPicker() {
    showComposerSheet<void>(
      context,
      title: 'Location',
      builder: (ctx) => const _LocationPickerSheet(),
    );
  }

  void _showPostTypePicker() {
    final state = ref.read(postComposerProvider);
    final selectableTypes = PostType.values
        .where((t) => t.isUserSelectable)
        .toList(growable: false);

    showComposerSheet<void>(
      context,
      title: 'Post Type',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in selectableTypes)
            ComposerPickerRow(
              icon: _postTypeIcon(t),
              title: _postTypeLabel(t),
              subtitle: _postTypeDescription(t),
              selected: state.postType == t,
              onTap: () {
                ref.read(postComposerProvider.notifier).setPostType(t);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  // Retained while the Category row is hidden — see _buildOptionsSection.
  // ignore: unused_element
  void _showContentClassPicker() {
    final state = ref.read(postComposerProvider);
    const classes = ['social', 'editorial'];

    showComposerSheet<void>(
      context,
      title: 'Content Class',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final cc in classes)
            ComposerPickerRow(
              icon: cc == 'social' ? 'people' : 'document-text',
              title: _prettifyLabel(cc),
              subtitle: cc == 'social'
                  ? 'Standard social post'
                  : 'Editorial or long-form content',
              selected: state.contentClass == cc,
              onTap: () {
                ref.read(postComposerProvider.notifier).setContentClass(cc);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  void _showMediaInput() {
    showComposerSheet<void>(
      context,
      title: 'Add Media',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ComposerPickerRow(
            icon: 'camera',
            title: 'Take Photo',
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadMedia(ImageSource.camera);
            },
          ),
          ComposerPickerRow(
            icon: 'gallery',
            title: 'Choose from Gallery',
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadMedia(ImageSource.gallery);
            },
          ),
          ComposerPickerRow(
            icon: 'image',
            title: 'Search GIFs',
            subtitle: 'Powered by GIPHY',
            onTap: () {
              Navigator.pop(ctx);
              _showGifPicker();
            },
          ),
        ],
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
    showGifPickerSheet(
      context,
      onSelected: (gifUrl) =>
          ref.read(postComposerProvider.notifier).addMediaUrl(gifUrl),
    );
  }

  Future<void> _showProfileSwitchPicker() async {
    final profiles = await ref.read(availableProfilesProvider.future);

    if (!mounted || profiles.isEmpty) {
      return;
    }

    final activeType = ref.read(activeProfileTypeProvider);

    showComposerSheet<void>(
      context,
      title: 'Post As',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final profile in profiles)
            Builder(
              builder: (_) {
                final effectiveType =
                    (profile.personaType ?? profile.profileType ?? '')
                        .toLowerCase();
                final isActive =
                    effectiveType.isNotEmpty &&
                    effectiveType == activeType?.toLowerCase();
                final colors = DabblerColors.of(ctx);

                return DabblerInputRow(
                  leading: DabblerAvatar(
                    seed: profile.displayName,
                    imageUrl: profile.avatarUrl,
                    size: DabblerAvatarSize.sm,
                  ),
                  title: profile.displayName,
                  subtitle: effectiveType.isNotEmpty
                      ? _prettifyLabel(effectiveType)
                      : null,
                  trailing: isActive
                      ? DabblerIcon(
                          'tick-circle',
                          weight: DabblerIconWeight.bold,
                          size: DabblerSizing.iconRow,
                          color: colors.brandPrimary,
                        )
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
                      if (mounted) {
                        _errorToast(
                          ref.read(personaServiceProvider).errorMessage ??
                              'Failed to switch profile',
                        );
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
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final composerState = ref.watch(postComposerProvider);

    final shell = ComposerDrawerShell(
      title: 'Create Post',
      ctaLabel: 'Post',
      canSubmit: composerState.canSubmit,
      isSubmitting: composerState.isSubmitting,
      onCtaTap: _submit,
      errorMessage: composerState.error,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: DabblerSpacing.space8,
            top: DabblerSpacing.space1,
            end: DabblerSpacing.space8,
          ),
          child: _buildAuthorRow(),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space8,
            vertical: DabblerSpacing.space3,
          ),
          child: _buildKindVisibilityRow(composerState),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space8,
            vertical: DabblerSpacing.space1,
          ),
          child: _buildTextBoxCard(composerState),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: DabblerSpacing.space8,
            vertical: DabblerSpacing.space2,
          ),
          child: composerState.hasMedia
              ? _buildMediaTilesRow(composerState)
              : _buildMediaActions(),
        ),
        _buildOptionsSection(composerState),
      ],
    );

    return shell;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AUTHOR ROW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAuthorRow() {
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
      child: DabblerFeedTappable(
        onTap: canSwitch ? _showProfileSwitchPicker : null,
        child: Row(
          children: [
            DabblerAvatar(
              seed: displayName,
              imageUrl: avatarUrl,
              size: DabblerAvatarSize.md,
            ),
            const SizedBox(width: DabblerSpacing.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DabblerText(displayName, style: DabblerType.headline),
                  if (canSwitch)
                    DabblerText(
                      _prettifyLabel(
                        composerState.personaTypeSnapshot ?? activePersona,
                      ),
                      style: DabblerType.footnote,
                      tone: DabblerTextTone.secondary,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // KIND + VISIBILITY ROW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildKindVisibilityRow(PostComposerState composerState) {
    final colors = DabblerColors.of(context);
    return Wrap(
      spacing: DabblerSpacing.space3,
      runSpacing: DabblerSpacing.space3,
      children: [
        Semantics(
          label:
              'Post type: ${_postTypeLabel(composerState.postType)}. '
              'Tap to change.',
          excludeSemantics: true,
          child: DabblerChip(
            label: _postTypeLabel(composerState.postType),
            selected: true,
            leadingIcon: DabblerIcon(
              _postTypeIcon(composerState.postType),
              size: DabblerSizing.iconInline,
              color: colors.onBrand,
            ),
            onTap: _showPostTypePicker,
          ),
        ),
        Semantics(
          label:
              'Visibility: ${_visibilityLabel(composerState.visibility)}. '
              'Tap to change.',
          excludeSemantics: true,
          child: DabblerChip(
            label: _visibilityLabel(composerState.visibility),
            leadingIcon: DabblerIcon(
              _visibilityIcon(composerState.visibility),
              size: DabblerSizing.iconInline,
              color: colors.textSecondary,
            ),
            onTap: _showVisibilityPicker,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEXT BOX (body + tags + enrich toolbar)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTextBoxCard(PostComposerState composerState) {
    const maxLen = 2000;
    final bodyLen = composerState.body.length;
    final hasLocation = composerState.locationName != null;
    final nearLimit = bodyLen > maxLen * 0.9;

    final tagPills = <Widget>[
      if (composerState.hasSport && composerState.sportName != null)
        _tagBadge('cup', composerState.sportName!.toUpperCase()),
      if (hasLocation) _tagBadge('location', composerState.locationName!),
      if (composerState.hasGame && composerState.gameName != null)
        _tagBadge('game', composerState.gameName!),
    ];

    final vibe = composerState.hasVibe && composerState.vibeName != null
        ? DabblerVibe.fromKey(composerState.vibeName!.toLowerCase())
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tagPills.isNotEmpty) ...[
          Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: tagPills,
          ),
          const SizedBox(height: DabblerSpacing.space3),
        ],
        DabblerTextField(
          variant: DabblerTextFieldVariant.multiline,
          controller: _bodyController,
          focusNode: _bodyFocusNode,
          rows: 4,
          placeholder: "What's on your mind? Use #hashtags",
          onChanged: (value) {
            ref.read(postComposerProvider.notifier).setBody(value);
          },
        ),
        const SizedBox(height: DabblerSpacing.space2),
        Row(
          children: [
            if (composerState.hasVibe && composerState.vibeName != null)
              DabblerChip(
                label: composerState.vibeName!,
                vibe: vibe,
                selected: true,
              ),
            const Spacer(),
            // Non-colour cue (WCAG 1.4.1): weight bumps to bold near the
            // limit alongside the colour change.
            DabblerText(
              '$bodyLen/$maxLen',
              semanticsLabel: '$bodyLen of $maxLen characters used',
              style: DabblerType.caption1,
              tone: nearLimit
                  ? DabblerTextTone.primary
                  : DabblerTextTone.tertiary,
              weight: nearLimit ? DabblerTextWeight.bold : null,
            ),
          ],
        ),
        const SizedBox(height: DabblerSpacing.space2),
        const DabblerDivider(),
        Row(
          children: [
            Expanded(
              child: _enrichButton(
                icon: 'happyemoji',
                active: composerState.hasVibe,
                label: composerState.hasVibe
                    ? 'Vibe: ${composerState.vibeName ?? "set"}. '
                          'Tap to change.'
                    : 'Add vibe',
                onTap: _showVibesPicker,
              ),
            ),
            Expanded(
              child: _enrichButton(
                icon: 'cup',
                active: composerState.hasSport,
                label: composerState.hasSport
                    ? 'Sport: ${composerState.sportName ?? "set"}. '
                          'Tap to change.'
                    : 'Add sport',
                onTap: _showSportsPicker,
              ),
            ),
            Expanded(
              child: _enrichButton(
                icon: 'location',
                active: hasLocation,
                label: hasLocation
                    ? 'Location: ${composerState.locationName}. '
                          'Tap to change.'
                    : 'Add location',
                onTap: _showLocationPicker,
              ),
            ),
            Expanded(
              child: _enrichButton(
                icon: 'game',
                active: composerState.hasGame,
                label: composerState.hasGame
                    ? 'Game: ${composerState.gameName ?? "set"}. '
                          'Tap to change.'
                    : 'Link a game',
                onTap: _showGamePicker,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tagBadge(String icon, String label) {
    final colors = DabblerColors.of(context);
    return DabblerBadge(
      label: label,
      tone: DabblerBadgeTone.primary,
      icon: DabblerIcon(
        icon,
        size: DabblerSizing.iconXs,
        color: colors.onBrand,
      ),
    );
  }

  Widget _enrichButton({
    required String icon,
    required bool active,
    required String label,
    required VoidCallback onTap,
  }) {
    return Center(
      child: DabblerButton.icon(
        icon: icon,
        semanticLabel: label,
        tone: active ? DabblerButtonTone.primary : DabblerButtonTone.neutral,
        onPressed: onTap,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MEDIA SECTION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildMediaActions() {
    return Row(
      children: [
        Expanded(
          child: DabblerButton(
            label: 'Media',
            icon: 'gallery-add',
            tone: DabblerButtonTone.outlined,
            fullWidth: true,
            onPressed: _showMediaInput,
          ),
        ),
        const SizedBox(width: DabblerSpacing.space3),
        Expanded(
          child: DabblerButton(
            label: 'Add GIF',
            icon: 'image',
            tone: DabblerButtonTone.outlined,
            fullWidth: true,
            onPressed: _showGifPicker,
          ),
        ),
      ],
    );
  }

  /// Filled state — horizontal 150-tall row: main 200 wide + extras 100 wide +
  /// trailing "Add More" button. Each image tile has its own remove button.
  Widget _buildMediaTilesRow(PostComposerState state) {
    final items = state.media;
    return SizedBox(
      height: DabblerSizing.mediaRowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) =>
            const SizedBox(width: DabblerSpacing.space2),
        itemCount: items.length + 1,
        itemBuilder: (_, i) {
          if (i == items.length) {
            return Center(
              child: DabblerButton.icon(
                icon: 'add',
                semanticLabel: 'Add more media',
                tone: DabblerButtonTone.neutral,
                onPressed: _showMediaInput,
              ),
            );
          }
          final url = items[i].toString();
          final isLead = i == 0;
          return _MediaTile(
            url: url,
            width: isLead
                ? DabblerSizing.railCardWidth
                : DabblerSizing.illustrationLg,
            onRemove: () =>
                ref.read(postComposerProvider.notifier).removeMediaAt(i),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // OPTIONS SECTION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildOptionsSection(PostComposerState state) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: DabblerSpacing.space8,
        end: DabblerSpacing.space8,
        bottom: DabblerSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ComposerSettingsRow(
            icon: 'repeat',
            title: 'Allow reposts',
            subtitle: 'Others can share this post',
            trailing: ComposerToggle(
              value: state.allowReposts,
              onChanged: (_) =>
                  ref.read(postComposerProvider.notifier).toggleAllowReposts(),
            ),
          ),
          ComposerSettingsRow(
            // The design system carries no push-pin glyph; bookmark is the
            // nearest (listed as a DS gap).
            icon: 'bookmark',
            title: 'Pin to profile',
            subtitle: 'Keep at the top of your profile',
            trailing: ComposerToggle(
              value: state.isPinned,
              onChanged: (_) =>
                  ref.read(postComposerProvider.notifier).togglePinned(),
            ),
          ),
          // Category hidden for now — re-enable when discovery categories ship.
          ComposerSettingsRow(
            icon: 'clock',
            title: 'Set expiry',
            subtitle: 'Auto-hides after date',
            showDivider: false,
            onTap: _showExpiryPicker,
            trailing: ComposerSelectPill(
              value: state.expiresAt != null
                  ? _formatDate(state.expiresAt!)
                  : 'None',
              caret: ComposerSelectCaret.right,
              onTap: _showExpiryPicker,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  String _visibilityIcon(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return 'global';
      case PostVisibility.followers:
        return 'people';
      case PostVisibility.circle:
        return 'record-circle';
      case PostVisibility.squad:
        return 'profile-2user';
      case PostVisibility.private:
        return 'lock';
      case PostVisibility.link:
        return 'link';
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

  String _postTypeIcon(PostType t) {
    switch (t) {
      case PostType.moment:
        return 'flash';
      case PostType.dab:
        return 'like-1';
      case PostType.kickIn:
        return 'people';
      default:
        return 'document-text';
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
    return DabblerAttachmentChip(
      thumbnail: DabblerImage(
        url: url,
        overlay: _isGif
            ? const Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Padding(
                  padding: EdgeInsets.all(DabblerSpacing.space2),
                  child: DabblerBadge(label: 'GIF'),
                ),
              )
            : null,
      ),
      size: Size(width, 150),
      semanticLabel: _isGif ? 'GIF' : 'Image',
      removeLabel: 'Remove media',
      onRemove: onRemove,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EXPIRY PICKER SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _ExpiryPickerSheet extends StatefulWidget {
  const _ExpiryPickerSheet({
    required this.first,
    required this.last,
    required this.initial,
    required this.onPicked,
  });

  final DateTime first;
  final DateTime last;
  final DateTime initial;
  final ValueChanged<DateTime> onPicked;

  @override
  State<_ExpiryPickerSheet> createState() => _ExpiryPickerSheetState();
}

class _ExpiryPickerSheetState extends State<_ExpiryPickerSheet> {
  late DateTime _month = DateTime(widget.initial.year, widget.initial.month);
  late DateTime _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DabblerSpacing.space6),
      child: DabblerCalendar(
        month: _month,
        selected: <DateTime>{_selected},
        minimum: widget.first,
        maximum: widget.last,
        onSelect: (d) => setState(() => _selected = d),
        onMonthChanged: (m) => setState(() => _month = m),
        onConfirm: () {
          widget.onPicked(_selected);
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VIBES PICKER SHEET (for composer)
// ═════════════════════════════════════════════════════════════════════════════

class _ComposerVibesPickerSheet extends ConsumerStatefulWidget {
  const _ComposerVibesPickerSheet();

  @override
  ConsumerState<_ComposerVibesPickerSheet> createState() =>
      _ComposerVibesPickerSheetState();
}

class _ComposerVibesPickerSheetState
    extends ConsumerState<_ComposerVibesPickerSheet> {
  String? _activeTypeFilter;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final vibesAsync = ref.watch(vibesProvider);
    final composerState = ref.watch(postComposerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (composerState.vibeId != null)
          ComposerClearRow(
            onClear: () {
              ref.read(postComposerProvider.notifier).clearVibe();
              Navigator.pop(context);
            },
          ),
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
              padding: const EdgeInsetsDirectional.only(
                start: DabblerSpacing.space6,
                end: DabblerSpacing.space6,
                bottom: DabblerSpacing.space3,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DabblerChip(
                      label: 'All',
                      selected: _activeTypeFilter == null,
                      onTap: () => setState(() => _activeTypeFilter = null),
                    ),
                    for (final type in types) ...[
                      const SizedBox(width: DabblerSpacing.space2),
                      DabblerChip(
                        label: _prettifyLabel(type),
                        selected: _activeTypeFilter == type,
                        onTap: () => setState(() => _activeTypeFilter = type),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        ComposerScrollArea(
          fraction: 0.55,
          child: vibesAsync.when(
            loading: () => const ComposerCenteredState.loading(),
            error: (e, _) =>
                const ComposerCenteredState.message('Failed to load vibes'),
            data: (vibes) {
              var filtered = vibes.toList();
              if (_activeTypeFilter != null) {
                filtered = filtered
                    .where((v) => v.type == _activeTypeFilter)
                    .toList();
              }
              if (filtered.isEmpty) {
                return const ComposerCenteredState.message(
                  'No vibes available',
                );
              }
              return GridView.builder(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  DabblerSpacing.space6,
                  DabblerSpacing.space1,
                  DabblerSpacing.space6,
                  DabblerSpacing.space6,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: DabblerSpacing.space3,
                  crossAxisSpacing: DabblerSpacing.space3,
                  childAspectRatio: 2.2,
                ),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final vibe = filtered[i];
                  final isSelected = vibe.id == composerState.vibeId;
                  final tokens = DabblerVibe.fromKey(vibe.key)?.resolve(colors);
                  return Semantics(
                    button: true,
                    selected: isSelected,
                    label: vibe.labelEn,
                    excludeSemantics: true,
                    child: DabblerFeedTappable(
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
                      child: DabblerSurface(
                        radius: DabblerRadius.lg,
                        fill: isSelected
                            ? (tokens?.selectedSurface ?? colors.surfaceGrey)
                            : (tokens?.surface ?? colors.surfaceSunken),
                        borderColor: isSelected
                            ? (tokens?.selectedBorder ?? colors.borderStrong)
                            : (tokens?.border ?? colors.borderDefault),
                        borderWidth: DabblerSizing.borderDefault,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DabblerSpacing.space2,
                            ),
                            // The vibe's ink is a palette colour, not a text
                            // tone: make it ambient and let the text inherit.
                            child: DefaultTextStyle.merge(
                              style:
                                  DabblerText.resolveStyle(
                                    context,
                                    style: DabblerType.footnote,
                                  ).copyWith(
                                    color: tokens?.ink ?? colors.textPrimary,
                                  ),
                              child: DabblerText(
                                vibe.labelEn,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: DabblerType.footnote,
                                tone: DabblerTextTone.inherit,
                                weight: isSelected
                                    ? DabblerTextWeight.bold
                                    : DabblerTextWeight.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LOCATION PICKER SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _LocationPickerSheet extends ConsumerStatefulWidget {
  const _LocationPickerSheet();

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

  void _commitManual() {
    final name = _manualNameController.text.trim();
    if (name.isNotEmpty) {
      ref.read(postComposerProvider.notifier).setRawLocation(name: name);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerClearRow(
          onClear: () {
            ref.read(postComposerProvider.notifier).clearLocation();
            Navigator.pop(context);
          },
        ),
        ComposerSearchField(
          controller: _searchController,
          placeholder: 'Search venues...',
          onChanged: (value) => setState(() => _query = value),
        ),
        ComposerPickerRow(
          icon: 'location-add',
          title: 'Type a location',
          trailingText: _showManualEntry ? 'Hide' : null,
          onTap: () => setState(() => _showManualEntry = !_showManualEntry),
        ),
        if (_showManualEntry)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: DabblerSpacing.space6,
              vertical: DabblerSpacing.space2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: DabblerTextField(
                    controller: _manualNameController,
                    placeholder: 'e.g. Central Park, NYC',
                    onSubmitted: (_) => _commitManual(),
                  ),
                ),
                const SizedBox(width: DabblerSpacing.space2),
                DabblerButton.icon(
                  icon: 'tick-circle',
                  semanticLabel: 'Use this location',
                  onPressed: _commitManual,
                ),
              ],
            ),
          ),
        const DabblerDivider(),
        ComposerScrollArea(
          fraction: 0.4,
          child: _query.trim().length >= 2
              ? Consumer(
                  builder: (ctx, ref, _) {
                    final venuesAsync = ref.watch(venueSearchProvider(_query));
                    return venuesAsync.when(
                      loading: () => const ComposerCenteredState.loading(),
                      error: (e, _) =>
                          const ComposerCenteredState.message('Search failed'),
                      data: (venues) {
                        if (venues.isEmpty) {
                          return const ComposerCenteredState.message(
                            'No venues found',
                            icon: 'location',
                          );
                        }
                        return ListView.builder(
                          itemCount: venues.length,
                          itemBuilder: (ctx, i) {
                            final venue = venues[i];
                            return ComposerPickerRow(
                              icon: 'location',
                              title: venue['name'] as String? ?? 'Venue',
                              subtitle: venue['city'] as String?,
                              onTap: () {
                                ref
                                    .read(postComposerProvider.notifier)
                                    .setVenue(
                                      id: venue['id'] as String,
                                      name: venue['name'] as String? ?? 'Venue',
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
              : const ComposerCenteredState.message(
                  'Search for a venue or type a location',
                  icon: 'search-normal',
                ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GAME PICKER SHEET
// ═════════════════════════════════════════════════════════════════════════════

class _GamePickerSheet extends ConsumerStatefulWidget {
  const _GamePickerSheet();

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerClearRow(
          onClear: () {
            ref.read(postComposerProvider.notifier).clearGame();
            Navigator.pop(context);
          },
        ),
        ComposerSearchField(
          controller: _searchController,
          placeholder: 'Search games by title...',
          onChanged: (value) => setState(() => _query = value),
        ),
        ComposerScrollArea(
          fraction: 0.5,
          child: _query.trim().length >= 2
              ? Consumer(
                  builder: (ctx, ref, _) {
                    final gamesAsync = ref.watch(gameSearchProvider(_query));
                    return gamesAsync.when(
                      loading: () => const ComposerCenteredState.loading(),
                      error: (e, _) =>
                          const ComposerCenteredState.message('Search failed'),
                      data: (games) {
                        if (games.isEmpty) {
                          return const ComposerCenteredState.message(
                            'No games found',
                            icon: 'game',
                          );
                        }
                        return ListView.builder(
                          itemCount: games.length,
                          itemBuilder: (ctx, i) {
                            final game = games[i];
                            final title =
                                game['title'] as String? ?? 'Untitled Game';
                            final sport = game['sport'] as String? ?? '';
                            final gameType = game['game_type'] as String? ?? '';
                            final startAt = game['start_at'] as String?;
                            final parsed = startAt == null
                                ? null
                                : DateTime.tryParse(startAt);
                            final subtitle = [
                              if (sport.isNotEmpty) sport,
                              if (gameType.isNotEmpty) gameType,
                              if (parsed != null)
                                '${parsed.day}/${parsed.month}/${parsed.year}',
                            ].where((s) => s.isNotEmpty).join(' · ');

                            return ComposerPickerRow(
                              icon: 'game',
                              title: title,
                              subtitle: subtitle.isNotEmpty ? subtitle : null,
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
              : const ComposerCenteredState.message(
                  'Search for a game to link to your post',
                  icon: 'game',
                ),
        ),
      ],
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
  Color? hashtagColor;

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
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(text: txt.substring(lastEnd, match.start), style: style),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: style?.copyWith(color: hashtagColor),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < txt.length) {
      spans.add(TextSpan(text: txt.substring(lastEnd), style: style));
    }

    return TextSpan(children: spans, style: style);
  }
}
