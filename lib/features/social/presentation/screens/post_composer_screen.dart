import 'dart:async';
import 'dart:convert';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/widgets/adaptive_scaffold.dart';

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
    DabblerToastProvider.of(context).show(
      DabblerToastSpec(message: message, tone: DabblerToastTone.error),
    );
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
      detents: const <double>[0.6],
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
      detents: const <double>[0.85],
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
      detents: const <double>[0.85],
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

  void _showExpiryPicker() {
    final now = DateTime.now();
    showComposerSheet<void>(
      context,
      title: 'Set expiry',
      detents: const <double>[0.7],
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
      detents: const <double>[0.85],
      builder: (ctx) => const _GamePickerSheet(),
    );
  }

  void _showLocationPicker() {
    showComposerSheet<void>(
      context,
      title: 'Location',
      detents: const <double>[0.85],
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
      detents: const <double>[0.5],
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
      detents: const <double>[0.4],
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
      detents: const <double>[0.45],
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
    showComposerSheet<void>(
      context,
      title: 'Search GIFs',
      detents: const <double>[0.9],
      builder: (ctx) => _GifPickerSheet(
        onSelected: (gifUrl) {
          ref.read(postComposerProvider.notifier).addMediaUrl(gifUrl);
          Navigator.pop(ctx);
        },
      ),
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
      detents: const <double>[0.5],
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
                          size: 20,
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
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space8,
            DabblerSpacing.space1,
            DabblerSpacing.space8,
            0,
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

    // On wide (iPad/desktop) screens, constrain the composer drawer to a
    // comfortable width and align it to the bottom rather than stretching
    // edge-to-edge.
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

  Widget _buildAuthorRow() {
    final colors = DabblerColors.of(context);
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
                  Text(
                    displayName,
                    style: composerType(
                      context,
                      DabblerType.headline,
                      colors.textPrimary,
                    ),
                  ),
                  if (canSwitch)
                    Text(
                      _prettifyLabel(
                        composerState.personaTypeSnapshot ?? activePersona,
                      ),
                      style: composerType(
                        context,
                        DabblerType.footnote,
                        colors.textSecondary,
                      ),
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
              size: 14,
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
              size: 14,
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
    final colors = DabblerColors.of(context);
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
              _VibeBadge(label: composerState.vibeName!, vibe: vibe),
            const Spacer(),
            // Non-colour cue (WCAG 1.4.1): weight bumps to bold near the
            // limit alongside the colour change.
            Text(
              '$bodyLen/$maxLen',
              semanticsLabel: '$bodyLen of $maxLen characters used',
              style: composerType(
                context,
                DabblerType.caption1,
                nearLimit ? colors.textPrimary : colors.textTertiary,
                weight: nearLimit ? FontWeight.w700 : null,
              ),
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
      icon: DabblerIcon(icon, size: 12, color: colors.onBrand),
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
        tone: active ? DabblerButtonTone.primary : DabblerButtonTone.icon,
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
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: DabblerSpacing.space2),
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
          return _MediaTile(
            url: url,
            width: i == 0 ? 200.0 : 100.0,
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
      padding: const EdgeInsetsDirectional.fromSTEB(
        DabblerSpacing.space8,
        0,
        DabblerSpacing.space8,
        DabblerSpacing.space3,
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

/// The chosen vibe, tinted with its [DabblerVibe] tokens (a neutral badge
/// when the vibe is not one the design system knows).
class _VibeBadge extends StatelessWidget {
  const _VibeBadge({required this.label, required this.vibe});

  final String label;
  final DabblerVibe? vibe;

  @override
  Widget build(BuildContext context) {
    final colors = DabblerColors.of(context);
    final tokens = vibe?.resolve(colors);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens?.selectedSurface ?? colors.surfaceSunken,
        borderRadius: BorderRadius.circular(DabblerRadius.pill),
        border: Border.all(color: tokens?.selectedBorder ?? colors.borderDefault),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space3,
          vertical: DabblerSpacing.space1,
        ),
        child: Text(
          label,
          style: composerType(
            context,
            DabblerType.caption1,
            tokens?.ink ?? colors.textPrimary,
            weight: FontWeight.w600,
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
            child: DabblerImage(
              url: url,
              width: width,
              height: 150,
              radius: DabblerRadius.lgAll,
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
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: DabblerButton.icon(
              icon: 'close-circle',
              semanticLabel: 'Remove media',
              tone: DabblerButtonTone.neutral,
              size: DabblerButtonSize.small,
              onPressed: onRemove,
            ),
          ),
        ],
      ),
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
              padding: const EdgeInsetsDirectional.fromSTEB(
                DabblerSpacing.space6,
                0,
                DabblerSpacing.space6,
                DabblerSpacing.space3,
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
                    child: GestureDetector(
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
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (tokens?.selectedSurface ??
                                    colors.surfaceGrey)
                              : (tokens?.surface ?? colors.surfaceSunken),
                          borderRadius: BorderRadius.circular(DabblerRadius.lg),
                          border: Border.all(
                            color: isSelected
                                ? (tokens?.selectedBorder ??
                                      colors.borderStrong)
                                : (tokens?.border ?? colors.borderDefault),
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DabblerSpacing.space2,
                            ),
                            child: Text(
                              vibe.labelEn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: composerType(
                                context,
                                DabblerType.footnote,
                                tokens?.ink ?? colors.textPrimary,
                                weight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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

// =============================================================================
// GIF PICKER SHEET (GIPHY)
// =============================================================================

class _GifPickerSheet extends StatefulWidget {
  const _GifPickerSheet({required this.onSelected});

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
    final colors = DabblerColors.of(context);

    final Widget results;
    if (_error != null) {
      results = ComposerCenteredState.message(_error!, icon: 'danger');
    } else if (_loading && _results.isEmpty) {
      results = const ComposerCenteredState.loading();
    } else if (_results.isEmpty) {
      results = const ComposerCenteredState.message('No GIFs found');
    } else {
      results = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter < 200) {
            _loadMore();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(DabblerSpacing.space2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: DabblerSpacing.space2,
            mainAxisSpacing: DabblerSpacing.space2,
          ),
          itemCount: _results.length + (_loading ? 1 : 0),
          itemBuilder: (ctx, index) {
            if (index >= _results.length) {
              return const Center(
                child: DabblerSpinner(size: DabblerSpinnerSize.sm),
              );
            }

            final gif = _results[index];
            final previewUrl = _getPreviewUrl(gif);
            if (previewUrl == null) return const SizedBox.shrink();

            return DabblerImage(
              url: previewUrl,
              radius: DabblerRadius.mdAll,
              semanticLabel: 'GIF',
              onTap: () {
                final gifUrl = _getGifUrl(gif);
                if (gifUrl != null) {
                  widget.onSelected(gifUrl);
                }
              },
            );
          },
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ComposerSearchField(
          controller: _searchController,
          placeholder: 'Search GIPHY...',
          onChanged: _onSearchChanged,
        ),
        ComposerScrollArea(fraction: 0.55, child: results),
        // GIPHY attribution (required by GIPHY ToS)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            DabblerSpacing.space4,
            DabblerSpacing.space1,
            DabblerSpacing.space4,
            DabblerSpacing.space2,
          ),
          child: Center(
            child: Text(
              'Powered by GIPHY',
              style: composerType(
                context,
                DabblerType.caption2,
                colors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
