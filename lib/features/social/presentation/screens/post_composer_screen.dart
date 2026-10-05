import 'dart:async';

import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/widgets/composer_drawer_kit.dart';
import 'package:dabbler/core/widgets/sport_selection_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_game_link_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_place_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/composer_vibes_sheet.dart';
import 'package:dabbler/features/social/presentation/widgets/gif_picker_sheet.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/social/sport.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/data/models/social/vibe.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/l10n/app_localizations.dart';

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
    // Circle visibility has no picker wired in this composer yet
    // (KAN-47) — selecting it always fails at submit time.
    showComposerChoiceSheet<PostVisibility>(
      context,
      title: AppLocalizations.of(context).composer_who_can_see,
      selected: state.visibility,
      onConfirm: ref.read(postComposerProvider.notifier).setVisibility,
      choices: [
        for (final v in PostVisibility.values)
          if (v != PostVisibility.circle)
            ComposerChoice(
              value: v,
              icon: _visibilityIcon(v),
              title: _visibilityLabel(v),
              subtitle: _visibilityDescription(v),
            ),
      ],
    );
  }

  Future<void> _showVibesPicker() async {
    await ref.read(vibesProvider.future).catchError((_) => <Vibe>[]);
    if (!mounted) return;
    final state = ref.read(postComposerProvider);
    final notifier = ref.read(postComposerProvider.notifier);
    showComposerVibesSheet(
      context,
      ref,
      selectedVibeId: state.vibeId,
      onClear: notifier.clearVibe,
      onConfirm: (vibe) =>
          notifier.setVibe(id: vibe.id, label: vibe.labelEn, emoji: vibe.emoji),
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

    showComposerSportSheet(
      context,
      title: AppLocalizations.of(context).composer_which_sport,
      sportsProvider: activeSportsByProfileCountryProvider,
      selected: selectedSport,
      showClear: true,
      onClear: () => ref.read(postComposerProvider.notifier).clearSport(),
      onConfirm: (sport) => ref
          .read(postComposerProvider.notifier)
          .setSport(
            id: sport.id,
            name: sport.localizedName(context),
            emoji: sport.emoji,
          ),
    );
  }

  void _showExpiryPicker() {
    final now = DateTime.now();
    showComposerSheet<void>(
      context,
      title: AppLocalizations.of(context).composer_expiry,
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

  void _showGamePicker() => showComposerGameLinkSheet(context, ref);

  void _showLocationPicker() => showComposerPlaceSheet(context, ref);

  void _showPostTypePicker() {
    final state = ref.read(postComposerProvider);
    showComposerChoiceSheet<PostType>(
      context,
      title: AppLocalizations.of(context).composer_kind_of_post,
      selected: state.postType,
      onConfirm: ref.read(postComposerProvider.notifier).setPostType,
      choices: [
        for (final t in PostType.values.where((t) => t.isUserSelectable))
          ComposerChoice(
            value: t,
            icon: _postTypeIcon(t),
            title: _postTypeLabel(t),
            subtitle: _postTypeDescription(t),
          ),
      ],
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
    final l = AppLocalizations.of(context);
    showComposerSheet<void>(
      context,
      title: l.composer_add_media_title,
      confirm: ComposerSheetConfirm(
        label: l.composer_done,
        onTap: () => Navigator.of(context).maybePop(),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ComposerPickerRow(
            icon: 'camera',
            accent: true,
            chevron: true,
            title: l.composer_take_photo,
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadMedia(ImageSource.camera);
            },
          ),
          ComposerPickerRow(
            icon: 'gallery',
            accent: true,
            chevron: true,
            title: l.composer_choose_gallery,
            onTap: () {
              Navigator.pop(ctx);
              _pickAndUploadMedia(ImageSource.gallery);
            },
          ),
          ComposerPickerRow(
            icon: 'search-normal',
            accent: true,
            chevron: true,
            title: l.composer_search_gifs,
            subtitle: l.composer_powered_giphy,
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
      title: AppLocalizations.of(context).composer_post_as,
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
                              AppLocalizations.of(
                                context,
                              ).composer_switch_failed,
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
      title: AppLocalizations.of(context).composer_create_post,
      ctaLabel: AppLocalizations.of(context).composer_post_cta,
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
              : const SizedBox.shrink(),
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
        AppLocalizations.of(context).composer_you;
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
                  DabblerText(displayName, style: DabblerType.subheadline),
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
        DabblerSelectPill(
          label: _postTypeLabel(composerState.postType),
          icon: _postTypeIcon(composerState.postType),
          tone: colors.info,
          semanticLabel:
              '${_postTypeLabel(composerState.postType)}. '
              '${AppLocalizations.of(context).composer_tap_to_change}',
          onTap: _showPostTypePicker,
        ),
        DabblerSelectPill(
          label: _visibilityLabel(composerState.visibility),
          icon: _visibilityIcon(composerState.visibility),
          tone: colors.success,
          semanticLabel:
              '${_visibilityLabel(composerState.visibility)}. '
              '${AppLocalizations.of(context).composer_tap_to_change}',
          onTap: _showVisibilityPicker,
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
        _tagBadge(composerState.sportName!.toUpperCase()),
      if (hasLocation) _tagBadge(composerState.locationName!),
      if (composerState.hasGame && composerState.gameName != null)
        _tagBadge(composerState.gameName!),
    ];
    final vibe = composerState.hasVibe && composerState.vibeName != null
        ? DabblerVibe.fromKey(composerState.vibeName!.toLowerCase())
        : null;

    return DabblerComposerBox(
      controller: _bodyController,
      focusNode: _bodyFocusNode,
      placeholder: AppLocalizations.of(context).composer_body_hint,
      onChanged: (value) =>
          ref.read(postComposerProvider.notifier).setBody(value),
      counter: '$bodyLen/$maxLen',
      counterSemanticLabel: '$bodyLen of $maxLen characters used',
      counterEmphasised: nearLimit,
      tags: tagPills.isEmpty && !composerState.hasVibe
          ? null
          : Wrap(
              spacing: DabblerSpacing.space2,
              runSpacing: DabblerSpacing.space2,
              children: [
                if (composerState.hasVibe && composerState.vibeName != null)
                  DabblerChip(
                    label: composerState.vibeName!,
                    vibe: vibe,
                    selected: true,
                  ),
                ...tagPills,
              ],
            ),
      tools: [
        DabblerComposerTool(
          icon: 'gallery',
          label: AppLocalizations.of(context).composer_add_media,
          active: composerState.hasMedia,
          onTap: _showMediaInput,
        ),
        DabblerComposerTool(
          icon: 'emoji-happy',
          label: composerState.hasVibe
              ? 'Vibe: ${composerState.vibeName ?? "set"}. Tap to change.'
              : AppLocalizations.of(context).composer_add_vibe,
          active: composerState.hasVibe,
          onTap: _showVibesPicker,
        ),
        DabblerComposerTool(
          icon: 'cup',
          label: composerState.hasSport
              ? 'Sport: ${composerState.sportName ?? "set"}. Tap to change.'
              : AppLocalizations.of(context).composer_add_sport,
          active: composerState.hasSport,
          onTap: _showSportsPicker,
        ),
        DabblerComposerTool(
          icon: 'location',
          label: hasLocation
              ? 'Location: ${composerState.locationName}. Tap to change.'
              : AppLocalizations.of(context).composer_add_location,
          active: hasLocation,
          onTap: _showLocationPicker,
        ),
        DabblerComposerTool(
          icon: 'game',
          label: composerState.hasGame
              ? 'Game: ${composerState.gameName ?? "set"}. Tap to change.'
              : AppLocalizations.of(context).composer_link_game,
          active: composerState.hasGame,
          onTap: _showGamePicker,
        ),
      ],
    );
  }

  Widget _tagBadge(String label) =>
      DabblerBadge(label: label, tone: DabblerBadgeTone.warning);

  // ═══════════════════════════════════════════════════════════════════════
  // MEDIA SECTION
  // ═══════════════════════════════════════════════════════════════════════

  /// Filled state — horizontal 150-tall row: main 200 wide + extras 100 wide +
  /// trailing "Add More" button. Each image tile has its own remove button.
  Widget _buildMediaTilesRow(PostComposerState state) {
    final items = state.media;
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          DabblerAttachmentAddTile(
            semanticLabel: l.composer_add_more_media,
            icon: 'add',
            dashed: false,
            tileWidth: DabblerSizing.mediaRailAddWidth,
            tileHeight: DabblerSizing.mediaRailHeight,
            onTap: _showMediaInput,
          ),
          for (final (i, item) in items.indexed) ...[
            const SizedBox(width: DabblerSpacing.space3),
            _MediaTile(
              url: item.toString(),
              onRemove: () =>
                  ref.read(postComposerProvider.notifier).removeMediaAt(i),
            ),
          ],
        ],
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
            icon: 'share',
            title: AppLocalizations.of(context).composer_allow_reposts,
            subtitle: AppLocalizations.of(context).composer_allow_reposts_sub,
            trailing: ComposerToggle(
              value: state.allowReposts,
              onChanged: (_) =>
                  ref.read(postComposerProvider.notifier).toggleAllowReposts(),
            ),
          ),
          ComposerSettingsRow(
            icon: 'star',
            title: AppLocalizations.of(context).composer_pin,
            subtitle: AppLocalizations.of(context).composer_pin_sub,
            trailing: ComposerToggle(
              value: state.isPinned,
              onChanged: (_) =>
                  ref.read(postComposerProvider.notifier).togglePinned(),
            ),
          ),
          // Category hidden for now — re-enable when discovery categories ship.
          ComposerSettingsRow(
            icon: 'clock',
            title: AppLocalizations.of(context).composer_expiry,
            subtitle: AppLocalizations.of(context).composer_expiry_sub,
            showDivider: false,
            onTap: _showExpiryPicker,
            trailing: ComposerSelectPill(
              value: state.expiresAt != null
                  ? _formatDate(state.expiresAt!)
                  : AppLocalizations.of(context).composer_none,
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
        return AppLocalizations.of(context).composer_vis_public;
      case PostVisibility.followers:
        return AppLocalizations.of(context).composer_vis_followers;
      case PostVisibility.circle:
        return AppLocalizations.of(context).composer_vis_circle;
      case PostVisibility.squad:
        return AppLocalizations.of(context).composer_vis_squad;
      case PostVisibility.private:
        return AppLocalizations.of(context).composer_vis_private;
      case PostVisibility.link:
        return AppLocalizations.of(context).composer_vis_link;
    }
  }

  String _visibilityDescription(PostVisibility v) {
    switch (v) {
      case PostVisibility.public:
        return AppLocalizations.of(context).composer_vis_public_sub;
      case PostVisibility.followers:
        return AppLocalizations.of(context).composer_vis_followers_sub;
      case PostVisibility.circle:
        return AppLocalizations.of(context).composer_vis_circle_sub;
      case PostVisibility.squad:
        return AppLocalizations.of(context).composer_vis_squad_sub;
      case PostVisibility.private:
        return AppLocalizations.of(context).composer_vis_private_sub;
      case PostVisibility.link:
        return AppLocalizations.of(context).composer_vis_link_sub;
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
        return AppLocalizations.of(context).composer_type_moment;
      case PostType.dab:
        return AppLocalizations.of(context).composer_type_dab;
      case PostType.kickIn:
        return AppLocalizations.of(context).composer_type_kickin;
      default:
        return t.name;
    }
  }

  String _postTypeDescription(PostType t) {
    switch (t) {
      case PostType.moment:
        return AppLocalizations.of(context).composer_type_moment_sub;
      case PostType.dab:
        return 'Share what you\'re vibing with';
      case PostType.kickIn:
        return AppLocalizations.of(context).composer_type_kickin_sub;
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
  const _MediaTile({required this.url, required this.onRemove});

  final String url;
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
      size: const Size(
        DabblerSizing.mediaRailTileWidth,
        DabblerSizing.mediaRailHeight,
      ),
      borderRadius: DabblerRadius.lgAll,
      semanticLabel: _isGif ? 'GIF' : 'Image',
      removeLabel: AppLocalizations.of(context).composer_remove_media,
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
    return DabblerCalendar(
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
