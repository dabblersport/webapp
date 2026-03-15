import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:dabbler/core/config/environment.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/places/presentation/widgets/place_picker_sheet.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:dabbler/utils/adaptive_sheet.dart';

/// Full-featured post composer that exposes all `posts` table capabilities.
///
/// Allows selection of: visibility, kind, body, vibe, sport, location,
/// media, allow_reposts toggle, and optional expiry.
///
/// Before insert it auto-detects language, extracts hashtags, resolves
/// the author profile via RLS-safe lookup, and generates link_token
/// when visibility == link.
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

  /// Insert a `#` at the current cursor position in the body field
  /// and focus it, so the user can type a hashtag inline.
  void _insertHashtag() {
    final text = _bodyController.text;
    final sel = _bodyController.selection;
    final offset = sel.isValid ? sel.baseOffset : text.length;
    // Add a space before # if the previous character isn't whitespace/empty
    final needsSpace =
        offset > 0 && text[offset - 1] != ' ' && text[offset - 1] != '\n';
    final insert = '${needsSpace ? ' ' : ''}#';
    final newText = text.replaceRange(offset, offset, insert);
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: offset + insert.length),
    );
    _bodyFocusNode.requestFocus();
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

  void _showKindPicker() {
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
                'Post Type',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            for (final k in PostKind.values)
              ListTile(
                leading: Icon(
                  _kindIcon(k),
                  color: state.kind == k ? cs.primary : cs.onSurface,
                ),
                title: Text(
                  _kindLabel(k),
                  style: TextStyle(
                    fontWeight: state.kind == k
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: state.kind == k ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  _kindDescription(k),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                trailing: state.kind == k
                    ? Icon(Icons.check_circle, color: cs.primary)
                    : null,
                onTap: () {
                  ref.read(postComposerProvider.notifier).setKind(k);
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
            _ComposerSportsPickerSheet(scrollController: scrollController),
      ),
    );
  }

  /// Opens the Mapbox place-search sheet for free-text / geocoded location.
  void _showLocationPicker() async {
    final place = await PlacePickerSheet.show(context);
    if (place != null && mounted) {
      ref
          .read(postComposerProvider.notifier)
          .setRawLocation(
            name: place.name,
            lat: place.latitude,
            lng: place.longitude,
          );
    }
  }

  /// Opens the DB venue picker (searches public.venues).
  void _showVenuePicker() {
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
            _VenuePickerSheet(scrollController: scrollController),
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

  void _showOriginTypePicker() {
    final cs = Theme.of(context).colorScheme;
    final state = ref.read(postComposerProvider);
    // Only show user-selectable origin types
    const userOriginTypes = [
      OriginType.manual,
      OriginType.game,
      OriginType.venue,
      OriginType.achievement,
    ];

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
                'Origin Type',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
            for (final ot in userOriginTypes)
              ListTile(
                leading: Icon(
                  _originTypeIcon(ot),
                  color: state.originType == ot ? cs.primary : cs.onSurface,
                ),
                title: Text(
                  _originTypeLabel(ot),
                  style: TextStyle(
                    fontWeight: state.originType == ot
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: state.originType == ot ? cs.primary : cs.onSurface,
                  ),
                ),
                subtitle: Text(
                  _originTypeDescription(ot),
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
                trailing: state.originType == ot
                    ? Icon(Icons.check_circle, color: cs.primary)
                    : null,
                onTap: () {
                  ref.read(postComposerProvider.notifier).setOriginType(ot);
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final composerState = ref.watch(postComposerProvider);

    // Sync text controller with state on external changes.
    // Only update the state while typing.
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _buildAppBar(cs, tt, composerState),
      body: Column(
        children: [
          // Error banner
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row with persona badge
                  _buildAuthorRow(cs, tt),
                  const SizedBox(height: 12),

                  // Kind + Visibility row
                  _buildKindVisibilityRow(cs, composerState),
                  const SizedBox(height: 12),

                  // Body text field
                  _buildBodyField(cs, tt),
                  const SizedBox(height: 12),

                  // Attachment chips row
                  _buildAttachmentChips(cs, composerState),
                  const SizedBox(height: 8),

                  // Media list (if any)
                  if (composerState.hasMedia)
                    _buildMediaList(cs, tt, composerState),

                  const SizedBox(height: 16),

                  // Options section (reposts, expiry, pin, content class, origin)
                  _buildOptionsSection(cs, tt, composerState),
                ],
              ),
            ),
          ),

          // Bottom action bar
          _buildBottomBar(cs, tt, composerState),
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
    return AppBar(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.close, color: cs.onSurface),
        onPressed: () => context.pop(),
      ),
      title: Text(
        'Create Post',
        style: tt.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: composerState.canSubmit && !composerState.isSubmitting
                ? _submit
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              disabledBackgroundColor: cs.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: composerState.isSubmitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : Text(
                    'Post',
                    style: tt.labelLarge?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
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

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          backgroundColor: cs.primaryContainer,
          child: avatarUrl == null
              ? Icon(Icons.person, color: cs.onPrimaryContainer, size: 20)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (activePersona != null && activePersona.isNotEmpty)
                Text(
                  _prettifyLabel(
                    composerState.personaTypeSnapshot ?? activePersona,
                  ),
                  style: tt.labelSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // KIND + VISIBILITY ROW
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildKindVisibilityRow(
    ColorScheme cs,
    PostComposerState composerState,
  ) {
    return Row(
      children: [
        // Kind pill
        _ComposerPill(
          icon: _kindIcon(composerState.kind),
          label: _kindLabel(composerState.kind),
          onTap: _showKindPicker,
          color: cs.tertiaryContainer,
          textColor: cs.onTertiaryContainer,
        ),
        const SizedBox(width: 8),
        // Visibility pill
        _ComposerPill(
          icon: _visibilityIcon(composerState.visibility),
          label: _visibilityLabel(composerState.visibility),
          onTap: _showVisibilityPicker,
          color: cs.secondaryContainer,
          textColor: cs.onSecondaryContainer,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BODY TEXT FIELD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBodyField(ColorScheme cs, TextTheme tt) {
    return TextField(
      controller: _bodyController,
      focusNode: _bodyFocusNode,
      maxLines: null,
      minLines: 5,
      maxLength: 2000,
      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: "What's on your mind? Use #hashtags",
        hintStyle: tt.bodyLarge?.copyWith(
          color: cs.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        border: InputBorder.none,
        counterStyle: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      onChanged: (value) {
        ref.read(postComposerProvider.notifier).setBody(value);
      },
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Vibe chip
        if (state.hasVibe)
          _AttachmentChip(
            emoji: state.vibeEmoji ?? '✨',
            label: state.vibeName ?? 'Vibe',
            onRemove: () => ref.read(postComposerProvider.notifier).clearVibe(),
            color: cs.primaryContainer,
            textColor: cs.onPrimaryContainer,
          )
        else
          _AddChip(
            icon: Icons.mood,
            label: 'Vibe',
            onTap: _showVibesPicker,
            cs: cs,
          ),

        // Sport chip
        if (state.hasSport)
          _AttachmentChip(
            emoji: state.sportEmoji ?? '🏅',
            label: state.sportName ?? 'Sport',
            onRemove: () =>
                ref.read(postComposerProvider.notifier).clearSport(),
            color: cs.primaryContainer,
            textColor: cs.onPrimaryContainer,
          )
        else
          _AddChip(
            icon: Icons.sports,
            label: 'Sport',
            onTap: _showSportsPicker,
            cs: cs,
          ),

        // Location chip (Mapbox)
        if (state.hasLocation)
          _AttachmentChip(
            emoji: '📍',
            label: state.locationName ?? 'Location',
            onRemove: () =>
                ref.read(postComposerProvider.notifier).clearLocation(),
            color: cs.primaryContainer,
            textColor: cs.onPrimaryContainer,
          )
        else
          _AddChip(
            icon: Icons.location_on_outlined,
            label: 'Location',
            onTap: _showLocationPicker,
            cs: cs,
          ),

        // Venue chip (DB venues)
        if (state.hasVenue)
          _AttachmentChip(
            emoji: '🏟️',
            label: state.venueName ?? 'Venue',
            onRemove: () =>
                ref.read(postComposerProvider.notifier).clearVenue(),
            color: cs.primaryContainer,
            textColor: cs.onPrimaryContainer,
          )
        else
          _AddChip(
            icon: Icons.stadium_outlined,
            label: 'Venue',
            onTap: _showVenuePicker,
            cs: cs,
          ),

        // Game chip
        if (state.hasGame)
          _AttachmentChip(
            emoji: '🎮',
            label: state.gameName ?? 'Game',
            onRemove: () => ref.read(postComposerProvider.notifier).clearGame(),
            color: cs.tertiaryContainer,
            textColor: cs.onTertiaryContainer,
          )
        else
          _AddChip(
            icon: Icons.sports_esports_outlined,
            label: 'Game',
            onTap: _showGamePicker,
            cs: cs,
          ),

        // Media chip (only show Add when no media; content shown below)
        if (!state.hasMedia)
          _AddChip(
            icon: Icons.image_outlined,
            label: 'Media',
            onTap: _showMediaInput,
            cs: cs,
          ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text(
          'Options',
          style: tt.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        // Allow reposts toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Allow reposts',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          subtitle: Text(
            'Others can share this post',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          value: state.allowReposts,
          onChanged: (_) =>
              ref.read(postComposerProvider.notifier).toggleAllowReposts(),
          activeThumbColor: cs.primary,
        ),
        // Pin toggle
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Pin to profile',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          subtitle: Text(
            'Keep this post at the top of your profile',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          value: state.isPinned,
          onChanged: (_) =>
              ref.read(postComposerProvider.notifier).togglePinned(),
          activeThumbColor: cs.primary,
        ),
        // Expiry
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.timer_outlined, color: cs.onSurfaceVariant),
          title: Text(
            state.expiresAt != null
                ? 'Expires: ${_formatDate(state.expiresAt!)}'
                : 'Set expiry',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          subtitle: Text(
            'Post auto-hides after this date',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          trailing: state.expiresAt != null
              ? IconButton(
                  icon: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant),
                  onPressed: () => ref
                      .read(postComposerProvider.notifier)
                      .setExpiresAt(null),
                )
              : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: _showExpiryPicker,
        ),
        // Content class
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            state.contentClass == 'editorial' ? Icons.article : Icons.people,
            color: cs.onSurfaceVariant,
          ),
          title: Text(
            'Content: ${_prettifyLabel(state.contentClass)}',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          subtitle: Text(
            'Categorise this post for discovery',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: _showContentClassPicker,
        ),
        // Origin type
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            _originTypeIcon(state.originType),
            color: cs.onSurfaceVariant,
          ),
          title: Text(
            'Origin: ${_originTypeLabel(state.originType)}',
            style: tt.bodyMedium?.copyWith(color: cs.onSurface),
          ),
          subtitle: Text(
            _originTypeDescription(state.originType),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          onTap: _showOriginTypePicker,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BOTTOM BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(
    ColorScheme cs,
    TextTheme tt,
    PostComposerState state,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        0,
        8,
        16,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          // Scrollable icon strip so all actions are accessible on small screens
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  _BottomBarIcon(
                    icon: Icons.mood,
                    label: 'Vibe',
                    active: state.hasVibe,
                    cs: cs,
                    tt: tt,
                    onTap: _showVibesPicker,
                  ),
                  _BottomBarIcon(
                    icon: Icons.sports,
                    label: 'Sport',
                    active: state.hasSport,
                    cs: cs,
                    tt: tt,
                    onTap: _showSportsPicker,
                  ),
                  _BottomBarIcon(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    active: state.hasLocation,
                    cs: cs,
                    tt: tt,
                    onTap: _showLocationPicker,
                  ),
                  _BottomBarIcon(
                    icon: Icons.stadium_outlined,
                    label: 'Venue',
                    active: state.hasVenue,
                    cs: cs,
                    tt: tt,
                    onTap: _showVenuePicker,
                  ),
                  _BottomBarIcon(
                    icon: Icons.sports_esports_outlined,
                    label: 'Game',
                    active: state.hasGame,
                    cs: cs,
                    tt: tt,
                    onTap: _showGamePicker,
                  ),
                  _BottomBarIcon(
                    icon: Icons.image_outlined,
                    label: 'Media',
                    active: state.hasMedia,
                    cs: cs,
                    tt: tt,
                    onTap: _showMediaInput,
                  ),
                  _BottomBarIcon(
                    icon: Icons.gif_box_outlined,
                    label: 'GIF',
                    active: false,
                    cs: cs,
                    tt: tt,
                    onTap: _showGifPicker,
                  ),
                  _BottomBarIcon(
                    icon: Icons.tag,
                    label: 'Tag',
                    active: state.hasTags,
                    cs: cs,
                    tt: tt,
                    onTap: _insertHashtag,
                  ),
                  _BottomBarIcon(
                    icon: Icons.category_outlined,
                    label: 'Class',
                    active: state.contentClass != 'social',
                    cs: cs,
                    tt: tt,
                    onTap: _showContentClassPicker,
                  ),
                  _BottomBarIcon(
                    icon: Icons.link,
                    label: 'Origin',
                    active: state.originType != OriginType.manual,
                    cs: cs,
                    tt: tt,
                    onTap: _showOriginTypePicker,
                  ),
                ],
              ),
            ),
          ),
          // Character count pinned to the right
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${state.body.length}/2000',
              style: tt.labelSmall?.copyWith(
                color: state.body.length > 1800
                    ? cs.error
                    : cs.onSurfaceVariant,
              ),
            ),
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

  IconData _kindIcon(PostKind k) {
    switch (k) {
      case PostKind.moment:
        return Icons.flash_on;
      case PostKind.dab:
        return Icons.front_hand;
      case PostKind.kickin:
        return Icons.sports;
    }
  }

  String _kindLabel(PostKind k) {
    switch (k) {
      case PostKind.moment:
        return 'Moment';
      case PostKind.dab:
        return 'Dab';
      case PostKind.kickin:
        return 'Kick In';
    }
  }

  String _kindDescription(PostKind k) {
    switch (k) {
      case PostKind.moment:
        return 'Share a quick update or thought';
      case PostKind.dab:
        return 'Express yourself with style';
      case PostKind.kickin:
        return 'Start a sports conversation';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _originTypeIcon(OriginType ot) {
    switch (ot) {
      case OriginType.manual:
        return Icons.edit;
      case OriginType.game:
        return Icons.sports_esports;
      case OriginType.achievement:
        return Icons.emoji_events;
      case OriginType.venue:
        return Icons.location_on;
      case OriginType.admin:
        return Icons.admin_panel_settings;
      case OriginType.system:
        return Icons.settings;
      case OriginType.repost:
        return Icons.repeat;
    }
  }

  String _originTypeLabel(OriginType ot) {
    switch (ot) {
      case OriginType.manual:
        return 'Manual';
      case OriginType.game:
        return 'Game';
      case OriginType.achievement:
        return 'Achievement';
      case OriginType.venue:
        return 'Venue';
      case OriginType.admin:
        return 'Admin';
      case OriginType.system:
        return 'System';
      case OriginType.repost:
        return 'Repost';
    }
  }

  String _originTypeDescription(OriginType ot) {
    switch (ot) {
      case OriginType.manual:
        return 'Created directly by you';
      case OriginType.game:
        return 'Linked to a game session';
      case OriginType.achievement:
        return 'Triggered by an unlock or milestone';
      case OriginType.venue:
        return 'Originated from a venue check-in';
      case OriginType.admin:
        return 'Created by an administrator';
      case OriginType.system:
        return 'Auto-generated by the system';
      case OriginType.repost:
        return 'Shared from another post';
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

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
class _ComposerPill extends StatelessWidget {
  const _ComposerPill({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18, color: textColor),
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

/// Chip showing a selected attachment (vibe, sport, location) with remove.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.emoji,
    required this.label,
    required this.onRemove,
    required this.color,
    required this.textColor,
  });

  final String emoji;
  final String label;
  final VoidCallback onRemove;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 16, color: textColor),
          ),
        ],
      ),
    );
  }
}

/// "Add" chip for unselected attachments.
class _AddChip extends StatelessWidget {
  const _AddChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VIBES PICKER SHEET (for composer)
// ═════════════════════════════════════════════════════════════════════════════

String _prettifyLabel(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

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
// SPORTS PICKER SHEET (for composer)
// ═════════════════════════════════════════════════════════════════════════════

class _ComposerSportsPickerSheet extends ConsumerStatefulWidget {
  const _ComposerSportsPickerSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_ComposerSportsPickerSheet> createState() =>
      _ComposerSportsPickerSheetState();
}

class _ComposerSportsPickerSheetState
    extends ConsumerState<_ComposerSportsPickerSheet> {
  String? _activeCategoryFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsAsync = ref.watch(sportsProvider);
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
                  'Sports',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                if (composerState.sportId != null)
                  TextButton(
                    onPressed: () {
                      ref.read(postComposerProvider.notifier).clearSport();
                      Navigator.pop(context);
                    },
                    child: Text('Clear', style: TextStyle(color: cs.primary)),
                  ),
              ],
            ),
          ),

          // Category chips
          sportsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (sports) {
              final categories =
                  sports
                      .where(
                        (s) => s.category != null && s.category!.isNotEmpty,
                      )
                      .map((s) => s.category!)
                      .toSet()
                      .toList()
                    ..sort();
              if (categories.length <= 1) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _ComposerFilterChip(
                        label: 'All',
                        isSelected: _activeCategoryFilter == null,
                        onTap: () =>
                            setState(() => _activeCategoryFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final cat in categories) ...[
                        _ComposerFilterChip(
                          label: _prettifyLabel(cat),
                          isSelected: _activeCategoryFilter == cat,
                          onTap: () =>
                              setState(() => _activeCategoryFilter = cat),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

          // List
          Expanded(
            child: sportsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load sports',
                  style: TextStyle(color: cs.error),
                ),
              ),
              data: (sports) {
                var filtered = sports.toList();
                if (_activeCategoryFilter != null) {
                  filtered = filtered
                      .where((s) => s.category == _activeCategoryFilter)
                      .toList();
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No sports available',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }
                return ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final sport = filtered[i];
                    final isSelected = sport.id == composerState.sportId;
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected
                          ? cs.primaryContainer
                          : Colors.transparent,
                      leading: Text(
                        sport.emoji ?? '🏅',
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        sport.nameEn,
                        style: tt.bodyMedium?.copyWith(
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: sport.category != null
                          ? Text(
                              _prettifyLabel(sport.category!),
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            )
                          : null,
                      onTap: () {
                        ref
                            .read(postComposerProvider.notifier)
                            .setSport(
                              id: sport.id,
                              name: sport.nameEn,
                              emoji: sport.emoji,
                            );
                        Navigator.pop(context);
                      },
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

// ═════════════════════════════════════════════════════════════════════════════
// BOTTOM BAR ICON BUTTON (icon + label column, with active state dot)
// ═════════════════════════════════════════════════════════════════════════════

class _BottomBarIcon extends StatelessWidget {
  const _BottomBarIcon({
    required this.icon,
    required this.label,
    required this.active,
    required this.cs,
    required this.tt,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? cs.primary : cs.onSurfaceVariant;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 22, color: color),
                if (active)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.surfaceContainerLow,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                fontSize: 10,
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
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
