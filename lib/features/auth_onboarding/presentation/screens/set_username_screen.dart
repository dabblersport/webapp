import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/domain/services/profile_creation_service.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/username_engine/providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'dart:async';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_step_frame.dart';

enum SetUsernameMode { onboarding, addPersona }

/// Where the username check stands, which decides the helper, the error and
/// the suffix of the username field.
enum _UsernameState {
  idle,
  tooShort,
  invalid,
  checking,
  taken,
  available,
  failed,
}

class SetUsernameScreen extends ConsumerStatefulWidget {
  final SetUsernameMode mode;

  const SetUsernameScreen({super.key, this.mode = SetUsernameMode.onboarding});

  @override
  ConsumerState<SetUsernameScreen> createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends ConsumerState<SetUsernameScreen> {
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  _UsernameState _usernameState = _UsernameState.idle;
  String? _usernameReason;
  Timer? _debounce;
  Timer? _suggestionDebounce;

  List<String> _suggestions = [];
  String? _selectedSuggestion;
  bool _loadingSuggestions = false;

  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]+$');

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(_onDisplayNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.mode == SetUsernameMode.addPersona) {
        final personaState = ref.read(personaServiceProvider);
        final primaryProfile = personaState.primaryProfile;
        if (primaryProfile != null &&
            primaryProfile.displayName != null &&
            primaryProfile.displayName!.isNotEmpty) {
          _displayNameController.text = primaryProfile.displayName!;
        }
      }
    });
  }

  @override
  void dispose() {
    _displayNameController.removeListener(_onDisplayNameChanged);
    _displayNameController.dispose();
    _usernameController.dispose();
    _debounce?.cancel();
    _suggestionDebounce?.cancel();
    super.dispose();
  }

  void _onDisplayNameChanged() {
    // The action depends on the display name.
    if (mounted) setState(() {});
    if (_suggestionDebounce?.isActive ?? false) _suggestionDebounce!.cancel();
    _suggestionDebounce = Timer(DabblerMotion.debounceSuggestion, () {
      final name = _displayNameController.text.trim();
      if (name.length >= 2) _generateSuggestions(name);
    });
  }

  String _normalize(String raw) {
    var s = raw.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_');
    s = s.replaceAll(RegExp(r'^_|_$'), '');
    if (s.length < 3) s = s.padRight(3, '0');
    if (s.length > 20) s = s.substring(0, 20);
    return s;
  }

  Future<String> _findAvailable(String base) async {
    final repo = ref.read(usernameRepositoryProvider);
    // Try base first
    final baseResult = await repo.checkAvailabilityRpc(base);
    final baseAvailable = baseResult.fold((_) => false, (v) => v.available);
    if (baseAvailable) return base;
    // Try _1 through _9
    for (var i = 1; i <= 9; i++) {
      final candidate = _normalize('${base}_$i');
      final result = await repo.checkAvailabilityRpc(candidate);
      final available = result.fold((_) => false, (v) => v.available);
      if (available) return candidate;
    }
    return base; // fallback — let availability check handle the error
  }

  Future<void> _generateSuggestions(String displayName) async {
    setState(() {
      _loadingSuggestions = true;
      _suggestions = [];
    });

    try {
      final onboardingData = widget.mode == SetUsernameMode.onboarding
          ? ref.read(onboardingDataProvider)
          : null;
      final addPersonaData = widget.mode == SetUsernameMode.addPersona
          ? ref.read(addPersonaDataProvider)
          : null;

      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      final emailPrefix = email.contains('@') ? email.split('@').first : '';
      final sportName = onboardingData?.preferredSportName ?? '';
      final age = onboardingData?.age;
      final intention =
          onboardingData?.intention ?? addPersonaData?.targetPersona.name ?? '';
      final year2 = (DateTime.now().year % 100).toString();

      final rawVariants = [
        emailPrefix.isNotEmpty ? emailPrefix : displayName,
        sportName.isNotEmpty
            ? '${displayName}_$sportName'
            : '${displayName}_sport',
        age != null ? '$displayName$age$year2' : '${displayName}_$year2',
        intention.isNotEmpty ? '${displayName}_$intention' : displayName,
      ];

      final normalizedVariants = rawVariants.map(_normalize).toList();

      // Check all in parallel
      final resolved = await Future.wait(
        normalizedVariants.map((v) => _findAvailable(v)),
      );

      // Deduplicate while preserving order
      final seen = <String>{};
      final unique = resolved.where((s) => seen.add(s)).toList();

      if (mounted) {
        setState(() {
          _suggestions = unique;
          _loadingSuggestions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _checkUsernameAvailability(String username) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _usernameReason = null;

    if (username.isEmpty) {
      setState(() => _usernameState = _UsernameState.idle);
      return;
    }
    if (username.length < 3) {
      setState(() => _usernameState = _UsernameState.tooShort);
      return;
    }
    if (!_usernamePattern.hasMatch(username)) {
      setState(() => _usernameState = _UsernameState.invalid);
      return;
    }

    setState(() => _usernameState = _UsernameState.checking);

    _debounce = Timer(DabblerMotion.debounceValidation, () async {
      try {
        final repo = ref.read(usernameRepositoryProvider);
        final result = await repo.checkAvailabilityRpc(username);

        if (mounted) {
          result.fold(
            (failure) => setState(() {
              _usernameState = _UsernameState.failed;
            }),
            (data) => setState(() {
              _usernameState = data.available
                  ? _UsernameState.available
                  : _UsernameState.taken;
              _usernameReason = data.available ? null : data.reason;
            }),
          );
        }
      } catch (_) {
        if (mounted) {
          setState(() => _usernameState = _UsernameState.failed);
        }
      }
    });
  }

  /// The display name is valid once it has two characters.
  bool get _displayNameValid => _displayNameController.text.trim().length >= 2;

  bool get _canSubmit =>
      !_isLoading &&
      _displayNameValid &&
      _usernameState == _UsernameState.available;

  Future<void> _handleSubmit() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    try {
      final displayName = _displayNameController.text.trim();
      final username = _usernameController.text.trim();

      if (username.isEmpty) throw Exception('Username cannot be empty.');
      if (displayName.isEmpty) throw Exception('Display name cannot be empty.');

      if (widget.mode == SetUsernameMode.addPersona) {
        await _handleAddPersonaSubmit(displayName, username);
      } else {
        await _handleOnboardingSubmit(displayName, username);
      }
    } catch (e) {
      if (mounted) {
        showOnboardingError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOnboardingSubmit(
    String displayName,
    String username,
  ) async {
    final onboardingData = ref.read(onboardingDataProvider);
    if (onboardingData == null) {
      showOnboardingError(
        context,
        'Missing onboarding data. Please start over.',
      );
      return;
    }

    // Gender is optional and intentionally not checked here.
    if (onboardingData.age == null ||
        onboardingData.intention == null ||
        onboardingData.preferredSport == null) {
      showOnboardingError(
        context,
        'Missing required information. Please complete all steps.',
      );
      return;
    }

    final authService = AuthService();
    final currentUser = authService.getCurrentUser();
    if (currentUser == null) {
      throw Exception(
        'Your session has expired. Please verify your phone number again.',
      );
    }

    ref
        .read(onboardingDataProvider.notifier)
        .setIdentity(displayName: displayName, username: username);

    if (mounted) {
      context.push(RoutePaths.onboardingWelcome);
    }
  }

  Future<void> _handleAddPersonaSubmit(
    String displayName,
    String username,
  ) async {
    final addPersonaData = ref.read(addPersonaDataProvider);
    if (addPersonaData == null) {
      showOnboardingError(context, 'Missing data. Please start over.');
      context.go('/settings');
      return;
    }

    ref
        .read(addPersonaDataProvider.notifier)
        .setIdentity(displayName: displayName, username: username);

    final completeData = ref.read(addPersonaDataProvider)!;
    final service = ProfileCreationService(Supabase.instance.client);
    try {
      await service.createProfile(
        data: completeData,
        deactivateProfileId: completeData.existingProfileId,
      );
    } on ProfileLimitException catch (e) {
      if (mounted) {
        showOnboardingError(context, e.message);
      }
      return;
    }

    ref.read(addPersonaDataProvider.notifier).clear();
    await ref.read(personaServiceProvider.notifier).fetchUserPersonas();

    if (mounted) {
      context.go(
        RoutePaths.welcome,
        extra: {
          'displayName': displayName,
          'personaType': completeData.targetPersona.name,
          'isFirstTime': false,
          'isConversion': completeData.isConversion,
        },
      );
    }
  }

  /// The suggestion chips: a spinner while they load, then one chip each in a
  /// horizontally scrolling rail.
  Widget _suggestionChips() {
    if (_loadingSuggestions) {
      return const Align(
        alignment: AlignmentDirectional.centerStart,
        child: DabblerSpinner(size: DabblerSpinnerSize.sm),
      );
    }
    return DabblerChipRail(
      gap: DabblerSpacing.space3,
      items: [
        for (final suggestion in _suggestions)
          DabblerChipRailItem(
            // A username is Latin: keep its `@` on the left under RTL.
            label: '\u200E@$suggestion',
            selected: _selectedSuggestion == suggestion,
            onTap: () {
              setState(() {
                _selectedSuggestion = suggestion;
                _usernameController.text = suggestion;
              });
              _checkUsernameAvailability(suggestion);
            },
          ),
      ],
    );
  }

  /// The helper line under the username field, per the design's states.
  String? _usernameHelper(AppLocalizations l10n) => switch (_usernameState) {
    _UsernameState.idle => l10n.onb_username_helper,
    _UsernameState.checking => l10n.onb_username_checking,
    _UsernameState.available => l10n.onb_username_available,
    _ => null,
  };

  /// The error line under the username field, per the design's states.
  String? _usernameError(AppLocalizations l10n) => switch (_usernameState) {
    _UsernameState.tooShort => l10n.onb_username_short,
    _UsernameState.invalid => l10n.onb_username_invalid,
    _UsernameState.taken =>
      (_usernameReason != null && _usernameReason!.isNotEmpty)
          ? _usernameReason
          : l10n.onb_username_taken,
    _UsernameState.failed => l10n.onb_username_check_error,
    _ => null,
  };

  Widget? _usernameSuffix(DabblerColors colors) => switch (_usernameState) {
    _UsernameState.checking => const Center(
      widthFactor: 1,
      child: DabblerSpinner(size: DabblerSpinnerSize.sm),
    ),
    _UsernameState.available => DabblerIcon(
      'tick-circle',
      weight: DabblerIconWeight.bold,
      color: colors.success.strong,
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final addPersonaData = widget.mode == SetUsernameMode.addPersona
        ? ref.watch(addPersonaDataProvider)
        : null;

    final l10n = AppLocalizations.of(context);
    final isPersona = widget.mode == SetUsernameMode.addPersona;
    final title = isPersona
        ? (addPersonaData?.isConversion == true
              ? l10n.set_username_title_conversion
              : l10n.set_username_title_new_profile)
        : l10n.onb_identity_title;

    final subtitle = isPersona
        ? l10n.set_username_subtitle_persona(
            addPersonaData?.targetPersona.displayName ?? '',
          )
        : l10n.onb_identity_subtitle;

    final buttonText = isPersona
        ? (addPersonaData?.isConversion == true
              ? l10n.set_username_btn_complete_conversion
              : l10n.set_username_btn_create_profile)
        : l10n.onb_create_account;

    final colors = DabblerColors.of(context);

    return DabblerFlowPage(
      onBack: () => context.pop(),
      backLabel: l10n.onb_back,
      stepCount: isPersona ? null : 5,
      stepIndex: isPersona ? null : 4,
      stepLabel: isPersona ? null : l10n.onb_step_label(5, 5),
      title: title,
      subtitle: subtitle,
      titleStyle: DabblerType.displayStep,
      subtitleStyle: DabblerType.copy,
      content: [
        DabblerTextField(
          borderOutside: true,
          controller: _displayNameController,
          label: l10n.onb_display_name_label,
          placeholder: l10n.set_username_display_name_hint,
          helperText: l10n.onb_display_name_helper,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.set_username_validate_display_required;
            }
            if (value.trim().length < 2) {
              return l10n.set_username_validate_display_min;
            }
            return null;
          },
        ),
        if (_loadingSuggestions || _suggestions.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DabblerText(
                l10n.onb_suggestions,
                style: DabblerType.footnote,
                weight: DabblerTextWeight.medium,
                tone: DabblerTextTone.secondary,
              ),
              const DabblerGap.v(DabblerSpacing.space3),
              _suggestionChips(),
            ],
          ),
        DabblerTextField(
          borderOutside: true,
          controller: _usernameController,
          label: l10n.onb_username_label,
          placeholder: l10n.onb_username_placeholder,
          helperText: _usernameHelper(l10n),
          errorText: _usernameError(l10n),
          suffixIcon: _usernameSuffix(colors),
          onChanged: (v) {
            setState(() => _selectedSuggestion = null);
            _checkUsernameAvailability(v.trim());
          },
        ),
      ],
      primaryLabel: buttonText,
      primaryLoading: _isLoading,
      onPrimary: _canSubmit ? _handleSubmit : null,
      secondary: isPersona
          ? DabblerButton(
              label: l10n.set_username_back,
              tone: DabblerButtonTone.text,
              fullWidth: true,
              onPressed: () => context.pop(),
            )
          : null,
    );
  }
}
