import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/design_system/design_system.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/core/utils/avatar_url_resolver.dart';
import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/data/models/user_circle.dart';
import 'package:dabbler/features/profile/presentation/providers/profile_providers.dart';
import 'package:dabbler/features/social/presentation/widgets/circles/circle_picker_sheet.dart';
import 'package:dabbler/features/social/providers/post_providers.dart';

/// Post creation screen — clean architecture.
///
/// User can type body text, pick a vibe, and/or pick a sport.
/// Validation: at least one of body, vibe, or sport must be present.
/// System defaults: kind=moment, post_type=moment, origin_type=manual.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _bodyController = TextEditingController();
  final AuthService _authService = AuthService();

  PostVisibility _visibility = PostVisibility.public;
  PostType _postType = PostType.moment;
  String? _errorMessage;
  Map<String, dynamic>? _userProfile;

  /// The named circle selected for circle-visibility posts.
  UserCircle? _selectedCircle;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final activeType = ref.read(activeProfileTypeProvider);
    final profile = await _authService.getUserProfile(personaType: activeType);
    if (mounted) setState(() => _userProfile = profile);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BOTTOM SHEET PICKERS (full-screen with filter chips)
  // ═══════════════════════════════════════════════════════════════════════

  void _showVibesPicker() {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) =>
            _VibesPickerSheet(scrollController: scrollController),
      ),
    );
  }

  void _showSportsPicker() {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 1.0,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) =>
            _SportsPickerSheet(scrollController: scrollController),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // VISIBILITY PICKER
  // ═══════════════════════════════════════════════════════════════════════

  void _showVisibilityPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: PostVisibility.values.map((v) {
            final isSelected = v == _visibility;
            return ListTile(
              leading: Icon(
                _visibilityIcon(v),
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Text(
                _visibilityLabel(v),
                style: TextStyle(
                  color: isSelected ? cs.primary : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (v == PostVisibility.circle) {
                  // Show circle picker — sets visibility only after selection.
                  _showCirclePicker();
                } else {
                  setState(() {
                    _visibility = v;
                    // Clear circle if switching away.
                    _selectedCircle = null;
                  });
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _showCirclePicker() async {
    final selected = await showCirclePickerSheet(context);
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _visibility = PostVisibility.circle;
        _selectedCircle = selected;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SUBMIT
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _submit() async {
    setState(() => _errorMessage = null);

    final body = _bodyController.text.trim();
    final vibeId = ref.read(selectedVibeProvider);
    final sportId = ref.read(selectedSportProvider);

    final result = await ref
        .read(postControllerProvider.notifier)
        .createPost(
          body: body.isNotEmpty ? body : null,
          vibeId: vibeId,
          sportId: sportId,
          visibility: _visibility.name,
          postType: _postType,
          circleId: _selectedCircle?.id,
        );

    if (!mounted) return;

    result.fold((failure) => setState(() => _errorMessage = failure.message), (
      _,
    ) {
      if (mounted) context.pop(true);
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final controllerState = ref.watch(postControllerProvider);
    final isSubmitting = controllerState is AsyncLoading;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(cs, tt),
            Expanded(child: _buildContentCard(cs, tt)),
            _buildBottomBar(cs, tt, isSubmitting),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAppBar(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back, color: cs.onSurface),
          ),
          const SizedBox(width: 4),
          Text(
            'Write post',
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          _appBarIcon(Icons.person_outline),
          _appBarIcon(Icons.auto_awesome),
          _appBarIcon(Icons.schedule),
          _appBarIcon(Icons.tune),
        ],
      ),
    );
  }

  Widget _appBarIcon(IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, color: cs.onSurfaceVariant),
      iconSize: 22,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONTENT CARD
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildContentCard(ColorScheme cs, TextTheme tt) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildHeaderRow(cs, tt),

          if (_errorMessage != null) _buildErrorBanner(cs, tt),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xl,
              ),
              child: TextField(
                controller: _bodyController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                decoration: InputDecoration(
                  hintText: 'Say something...',
                  hintStyle: tt.bodyLarge?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.only(top: 8),
                ),
              ),
            ),
          ),

          // Padding(
          //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          //   child: Align(
          //     alignment: Alignment.centerRight,
          //     child: Text(
          //       'Drafts',
          //       style: tt.bodySmall?.copyWith(
          //         color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          // Author avatar
          DSAvatar.small(
            imageUrl: resolveAvatarUrl(_userProfile?['avatar_url'] as String?),
            displayName: _userProfile?['display_name'] as String?,
            context: AvatarContext.main,
          ),
          const SizedBox(width: 8),

          // Visibility selector
          _PillButton(
            label:
                _visibility == PostVisibility.circle && _selectedCircle != null
                ? _selectedCircle!.name
                : _visibilityLabel(_visibility),
            onTap: _showVisibilityPicker,
            leadingIcon: _visibilityIcon(_visibility),
            trailingIcon: Icons.keyboard_arrow_down,
            useVariantColors: true,
          ),
          const Spacer(),

          _PillButton(
            label: _postTypeLabel(_postType),
            onTap: _showPostTypePicker,
            leadingIcon: _postTypeIcon(_postType),
            trailingIcon: Icons.keyboard_arrow_down,
            useVariantColors: true,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(ColorScheme cs, TextTheme tt) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BOTTOM BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBottomBar(ColorScheme cs, TextTheme tt, bool isSubmitting) {
    final selectedVibeId = ref.watch(selectedVibeProvider);
    final selectedSportId = ref.watch(selectedSportProvider);

    // Resolve display labels from loaded data.
    final vibesAsync = ref.watch(vibesProvider);
    final sportsAsync = ref.watch(sportsProvider);

    String vibeLabel = 'Vibes';
    if (selectedVibeId != null) {
      vibesAsync.whenData((vibes) {
        final match = vibes.where((v) => v.id == selectedVibeId);
        if (match.isNotEmpty) {
          final v = match.first;
          vibeLabel = '${v.emoji ?? '✨'} ${v.labelEn}'.trim();
        }
      });
    }

    String sportLabel = 'Sports';
    if (selectedSportId != null) {
      sportsAsync.whenData((sports) {
        final match = sports.where((s) => s.id == selectedSportId);
        if (match.isNotEmpty) {
          final s = match.first;
          sportLabel = '${s.emoji ?? '🏅'} ${s.nameEn}'.trim();
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          // + (add media — placeholder)
          _CircleIconButton(icon: Icons.add, onTap: () {}),
          const SizedBox(width: 8),

          // Vibes
          Expanded(
            child: _PillButton(
              label: vibeLabel,
              isActive: selectedVibeId != null,
              onTap: _showVibesPicker,
            ),
          ),
          const SizedBox(width: 8),

          // Sports
          Expanded(
            child: _PillButton(
              label: sportLabel,
              isActive: selectedSportId != null,
              onTap: _showSportsPicker,
            ),
          ),
          const SizedBox(width: 8),

          // Submit →
          _CircleIconButton(
            icon: Icons.arrow_forward,
            onTap: isSubmitting ? null : _submit,
            isLoading: isSubmitting,
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

  String _visibilityLabel(PostVisibility v) =>
      v.name[0].toUpperCase() + v.name.substring(1);

  // ═══════════════════════════════════════════════════════════════════════
  // POST TYPE PICKER
  // ═══════════════════════════════════════════════════════════════════════

  void _showPostTypePicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: PostType.values.map((t) {
            final isSelected = t == _postType;
            return ListTile(
              leading: Icon(
                _postTypeIcon(t),
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Text(
                _postTypeLabel(t),
                style: TextStyle(
                  color: isSelected ? cs.primary : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              subtitle: Text(
                _postTypeDescription(t),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              onTap: () {
                setState(() => _postType = t);
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _postTypeIcon(PostType t) {
    switch (t) {
      case PostType.moment:
        return Icons.flash_on;
      case PostType.dab:
        return Icons.front_hand;
      case PostType.kickIn:
        return Icons.sports;
    }
  }

  String _postTypeLabel(PostType t) {
    switch (t) {
      case PostType.moment:
        return 'Moment';
      case PostType.dab:
        return 'Dab';
      case PostType.kickIn:
        return 'Kick In';
    }
  }

  String _postTypeDescription(PostType t) {
    switch (t) {
      case PostType.moment:
        return 'Share a quick update';
      case PostType.dab:
        return 'Express yourself';
      case PostType.kickIn:
        return 'Start a sports conversation';
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE BOTTOM-BAR WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                icon,
                color: Theme.of(context).colorScheme.onSurface,
                size: 22,
              ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.leadingIcon,
    this.trailingIcon,
    this.useVariantColors = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool useVariantColors;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contentColor = isActive
        ? cs.onPrimaryContainer
        : (useVariantColors ? cs.onSurfaceVariant : cs.onSurface);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? cs.primaryContainer : cs.tertiaryContainer,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive
                ? cs.primary.withValues(alpha: 0.5)
                : cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 18, color: contentColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: contentColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 2),
                Icon(trailingIcon, size: 18, color: contentColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VIBES PICKER — full-screen bottom sheet with type filter chips
// ═════════════════════════════════════════════════════════════════════════════

String _prettifyLabel(String raw) {
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class _VibesPickerSheet extends ConsumerStatefulWidget {
  const _VibesPickerSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_VibesPickerSheet> createState() => _VibesPickerSheetState();
}

class _VibesPickerSheetState extends ConsumerState<_VibesPickerSheet> {
  String? _activeTypeFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final vibesAsync = ref.watch(vibesProvider);
    final selectedId = ref.watch(selectedVibeProvider);

    return SafeArea(
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title row
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
                if (selectedId != null)
                  TextButton(
                    onPressed: () {
                      ref.read(selectedVibeProvider.notifier).state = null;
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
                      .where(
                        (v) =>
                            v.type != null &&
                            v.type!.isNotEmpty &&
                            (v.contexts.isEmpty ||
                                v.contexts.contains('moment')),
                      )
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
                      _FilterChip(
                        label: 'All',
                        isSelected: _activeTypeFilter == null,
                        onTap: () => setState(() => _activeTypeFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final type in types) ...[
                        _FilterChip(
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
                var compatible = vibes
                    .where(
                      (v) =>
                          v.contexts.isEmpty || v.contexts.contains('moment'),
                    )
                    .toList();

                if (_activeTypeFilter != null) {
                  compatible = compatible
                      .where((v) => v.type == _activeTypeFilter)
                      .toList();
                }

                if (compatible.isEmpty) {
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
                  itemCount: compatible.length,
                  itemBuilder: (ctx, i) {
                    final vibe = compatible[i];
                    final isSelected = vibe.id == selectedId;

                    return GestureDetector(
                      onTap: () {
                        ref.read(selectedVibeProvider.notifier).state = vibe.id;
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
// SPORTS PICKER — full-screen bottom sheet with category filter chips
// ═════════════════════════════════════════════════════════════════════════════

class _SportsPickerSheet extends ConsumerStatefulWidget {
  const _SportsPickerSheet({required this.scrollController});
  final ScrollController scrollController;

  @override
  ConsumerState<_SportsPickerSheet> createState() => _SportsPickerSheetState();
}

class _SportsPickerSheetState extends ConsumerState<_SportsPickerSheet> {
  String? _activeCategoryFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final sportsAsync = ref.watch(sportsProvider);
    final selectedId = ref.watch(selectedSportProvider);

    return SafeArea(
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title row
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
                if (selectedId != null)
                  TextButton(
                    onPressed: () {
                      ref.read(selectedSportProvider.notifier).state = null;
                      Navigator.pop(context);
                    },
                    child: Text('Clear', style: TextStyle(color: cs.primary)),
                  ),
              ],
            ),
          ),

          // Category filter chips
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
                      _FilterChip(
                        label: 'All',
                        isSelected: _activeCategoryFilter == null,
                        onTap: () =>
                            setState(() => _activeCategoryFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final cat in categories) ...[
                        _FilterChip(
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
                    final isSelected = sport.id == selectedId;

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
                        ref.read(selectedSportProvider.notifier).state =
                            sport.id;
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
// SHARED FILTER CHIP
// ═════════════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
