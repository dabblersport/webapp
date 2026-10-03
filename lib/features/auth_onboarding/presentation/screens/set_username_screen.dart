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

class SetUsernameScreen extends ConsumerStatefulWidget {
  final SetUsernameMode mode;

  const SetUsernameScreen({super.key, this.mode = SetUsernameMode.onboarding});

  @override
  ConsumerState<SetUsernameScreen> createState() => _SetUsernameScreenState();
}

class _SetUsernameScreenState extends ConsumerState<SetUsernameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;
  String? _usernameReason;
  Timer? _debounce;
  Timer? _suggestionDebounce;

  List<String> _suggestions = [];
  String? _selectedSuggestion;
  bool _loadingSuggestions = false;

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
    if (_suggestionDebounce?.isActive ?? false) _suggestionDebounce!.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 800), () {
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

    if (username.length < 3) {
      setState(() {
        _usernameError = null;
        _usernameReason = null;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final repo = ref.read(usernameRepositoryProvider);
        final result = await repo.checkAvailabilityRpc(username);

        if (mounted) {
          result.fold(
            (failure) => setState(() {
              _usernameError = 'Error checking username';
              _usernameReason = null;
              _isCheckingUsername = false;
            }),
            (data) => setState(() {
              _usernameError = data.available ? null : 'Username unavailable';
              _usernameReason = data.available ? null : data.reason;
              _isCheckingUsername = false;
            }),
          );
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _usernameError = 'Error checking username';
            _usernameReason = null;
            _isCheckingUsername = false;
          });
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_usernameError != null) {
      showOnboardingError(context, _usernameError!);
      return;
    }

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
      showOnboardingError(context, 'Missing onboarding data. Please start over.');
      return;
    }

    // Gender is optional and intentionally not checked here.
    if (onboardingData.age == null ||
        onboardingData.intention == null ||
        onboardingData.preferredSport == null) {
      showOnboardingError(context, 'Missing required information. Please complete all steps.');
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

  /// A DS text field inside a [FormField] so the screen's `_formKey`
  /// validation keeps working unchanged.
  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String? Function(String?) validator,
    Function(String)? onChanged,
    Widget? suffixIcon,
    Widget? prefixIcon,
    String? extraError,
  }) {
    return FormField<String>(
      validator: (_) => validator(controller.text),
      builder: (field) => DabblerTextField(
        controller: controller,
        label: label,
        placeholder: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        errorText: field.errorText ?? extraError,
        onChanged: (v) {
          field.didChange(v);
          onChanged?.call(v);
        },
      ),
    );
  }

  Widget _buildSuggestionChips() {
    if (_loadingSuggestions) {
      return const SizedBox(
        height: DabblerSizing.touchTargetMin,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: DabblerSpinner(size: DabblerSpinnerSize.sm),
        ),
      );
    }

    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: DabblerSizing.touchTargetMin,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: DabblerSpacing.space3),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          return Center(
            child: DabblerChip(
              label: '@$s',
              selected: _selectedSuggestion == s,
              onTap: () {
                setState(() {
                  _selectedSuggestion = s;
                  _usernameController.text = s;
                  _usernameError = null;
                  _usernameReason = null;
                });
                _checkUsernameAvailability(s);
              },
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addPersonaData = widget.mode == SetUsernameMode.addPersona
        ? ref.watch(addPersonaDataProvider)
        : null;

    final l10n = AppLocalizations.of(context);
    final title = widget.mode == SetUsernameMode.addPersona
        ? (addPersonaData?.isConversion == true
              ? l10n.set_username_title_conversion
              : l10n.set_username_title_new_profile)
        : l10n.set_username_title_onboarding;

    final subtitle = widget.mode == SetUsernameMode.addPersona
        ? l10n.set_username_subtitle_persona(
            addPersonaData?.targetPersona.displayName ?? '',
          )
        : l10n.set_username_subtitle_onboarding;

    final buttonText = widget.mode == SetUsernameMode.addPersona
        ? (addPersonaData?.isConversion == true
              ? l10n.set_username_btn_complete_conversion
              : l10n.set_username_btn_create_profile)
        : l10n.set_username_btn_complete;

    final colors = DabblerColors.of(context);
    final String? usernameErrorText = _usernameError == null
        ? null
        : (_usernameReason != null && _usernameReason!.isNotEmpty
              ? _usernameReason!
              : _usernameError!);

    return OnboardingStepFrame(
      onBack: () => context.pop(),
      step: widget.mode == SetUsernameMode.addPersona ? null : 5,
      stepLabel:
          widget.mode == SetUsernameMode.addPersona ? null : 'Step 5 of 5',
      title: title,
      subtitle: subtitle,
      ctaLabel: buttonText,
      ctaLoading: _isLoading,
      onCta: _isLoading ? null : _handleSubmit,
      secondary: widget.mode == SetUsernameMode.addPersona
          ? DabblerButton(
              label: 'Back',
              tone: DabblerButtonTone.text,
              fullWidth: true,
              onPressed: () => context.pop(),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: DabblerSpacing.space8,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputField(
                context,
                controller: _displayNameController,
                label: l10n.set_username_display_name_label,
                hintText: l10n.set_username_display_name_hint,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  if (value.trim().length < 2) {
                    return 'Display name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: DabblerSpacing.space6),
              if (_loadingSuggestions || _suggestions.isNotEmpty) ...[
                Text(
                  'Suggestions',
                  style: onboardingType(
                    context,
                    DabblerType.footnote,
                    colors.textSecondary,
                    weight: DabblerType.medium,
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space3),
                _buildSuggestionChips(),
                const SizedBox(height: DabblerSpacing.space6),
              ],
              _buildInputField(
                context,
                controller: _usernameController,
                label: l10n.set_username_username_label,
                hintText: l10n.set_username_username_hint,
                prefixIcon: Center(
                  widthFactor: 1,
                  child: Text(
                    '@',
                    style: onboardingType(
                      context,
                      DabblerType.body,
                      colors.textSecondary,
                    ),
                  ),
                ),
                extraError: usernameErrorText,
                onChanged: (v) {
                  setState(() => _selectedSuggestion = null);
                  _checkUsernameAvailability(v);
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Username is required';
                  }
                  if (value.trim().length < 3) {
                    return 'Username must be at least 3 characters';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Only letters, numbers, and underscores';
                  }
                  return null;
                },
                suffixIcon: _isCheckingUsername
                    ? const Center(
                        widthFactor: 1,
                        child: DabblerSpinner(size: DabblerSpinnerSize.sm),
                      )
                    : _usernameError == null &&
                          _usernameController.text.isNotEmpty
                    ? DabblerIcon(
                        'tick-circle',
                        weight: DabblerIconWeight.bold,
                        color: colors.success.strong,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}