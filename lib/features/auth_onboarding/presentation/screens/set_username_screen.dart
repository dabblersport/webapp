import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/features/auth_onboarding/presentation/providers/onboarding_data_provider.dart';
import 'package:dabbler/features/profile/presentation/providers/add_persona_provider.dart';
import 'package:dabbler/features/profile/domain/services/profile_creation_service.dart';
import 'package:dabbler/features/profile/domain/services/persona_service.dart';
import 'package:dabbler/features/username_engine/providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/design_system/tokens/main_dark.dart'
    as main_dark_tokens;
import 'package:dabbler/design_system/tokens/main_light.dart'
    as main_light_tokens;
import 'package:dabbler/utils/ui_constants.dart';
import 'package:dabbler/widgets/adaptive_auth_shell.dart';
import 'dart:async';

enum SetUsernameMode {
  onboarding,
  addPersona,
}

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
      final intention = onboardingData?.intention ??
          addPersonaData?.targetPersona.name ??
          '';
      final year2 = (DateTime.now().year % 100).toString();

      final rawVariants = [
        emailPrefix.isNotEmpty ? emailPrefix : displayName,
        sportName.isNotEmpty ? '${displayName}_$sportName' : '${displayName}_sport',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_usernameError!), backgroundColor: Colors.red),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing onboarding data. Please start over.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (onboardingData.age == null ||
        onboardingData.gender == null ||
        onboardingData.intention == null ||
        onboardingData.preferredSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing required information. Please complete all steps.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authService = AuthService();
    final currentUser = authService.getCurrentUser();
    if (currentUser == null) {
      throw Exception('Your session has expired. Please verify your phone number again.');
    }

    ref.read(onboardingDataProvider.notifier).setIdentity(
      displayName: displayName,
      username: username,
    );

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing data. Please start over.'), backgroundColor: Colors.red),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
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

  Widget _buildInputField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hintText,
    required String? Function(String?) validator,
    required dynamic tokens,
    required ThemeData theme,
    Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: tokens.main.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          validator: validator,
          style: theme.textTheme.titleMedium?.copyWith(
            color: tokens.main.onSurface,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: theme.textTheme.titleMedium?.copyWith(
              color: tokens.main.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: tokens.main.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: tokens.main.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: tokens.main.error, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999),
              borderSide: BorderSide(color: tokens.main.error, width: 2),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChips(dynamic tokens, ThemeData theme) {
    if (_loadingSuggestions) {
      return SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => Container(
            width: 110,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.main.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _suggestions[i];
          final selected = _selectedSuggestion == s;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSuggestion = s;
                _usernameController.text = s;
                _usernameError = null;
                _usernameReason = null;
              });
              _checkUsernameAvailability(s);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? tokens.main.primaryContainer
                    : tokens.main.surfaceVariant,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? tokens.main.primary
                      : tokens.main.outline.withOpacity(0.3),
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                '@$s',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? tokens.main.onPrimaryContainer
                      : tokens.main.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = isDark ? main_dark_tokens.theme : main_light_tokens.theme;

    final addPersonaData = widget.mode == SetUsernameMode.addPersona
        ? ref.watch(addPersonaDataProvider)
        : null;

    final title = widget.mode == SetUsernameMode.addPersona
        ? (addPersonaData?.isConversion == true
              ? 'Complete Your Conversion'
              : 'Complete Your New Profile')
        : 'Identify yourself';

    final subtitle = widget.mode == SetUsernameMode.addPersona
        ? 'Choose a display name and username for your ${addPersonaData?.targetPersona.displayName ?? ''} profile'
        : 'Choose how others should call you and set a username';

    final buttonText = widget.mode == SetUsernameMode.addPersona
        ? (addPersonaData?.isConversion == true
              ? 'Complete Conversion'
              : 'Create Profile')
        : 'Complete';

    return AdaptiveAuthShell(
      backgroundColor: tokens.main.background,
      containerColor: tokens.main.secondaryContainer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.xxxl),

                        if (widget.mode == SetUsernameMode.addPersona &&
                            addPersonaData != null)
                          _buildFlowIndicator(theme, tokens, addPersonaData),

                        Text(
                          title,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: tokens.main.onSecondaryContainer,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        Text(
                          subtitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: tokens.main.onSecondaryContainer,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxxl),

                        // Display Name Field
                        _buildInputField(
                          context,
                          controller: _displayNameController,
                          label: 'Display Name',
                          hintText: 'Enter your display name',
                          tokens: tokens,
                          theme: theme,
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

                        const SizedBox(height: AppSpacing.lg),

                        // Username suggestions
                        if (_loadingSuggestions || _suggestions.isNotEmpty) ...[
                          Text(
                            'Suggestions',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: tokens.main.onSecondaryContainer
                                  .withOpacity(0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSuggestionChips(tokens, theme),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        // Username Field
                        _buildInputField(
                          context,
                          controller: _usernameController,
                          label: 'Username',
                          hintText: 'Choose a unique username',
                          tokens: tokens,
                          theme: theme,
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
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : _usernameError == null &&
                                    _usernameController.text.isNotEmpty
                              ? Icon(
                                  Iconsax.tick_circle_copy,
                                  color: tokens.main.primary,
                                )
                              : null,
                        ),

                        if (_usernameError != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.md),
                            child: Text(
                              _usernameReason != null && _usernameReason!.isNotEmpty
                                  ? _usernameReason!
                                  : _usernameError!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.main.error,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.xxxl),
                        const Spacer(),

                        FilledButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(
                              AppButtonSize.extraLargeHeight,
                            ),
                            padding: AppButtonSize.extraLargePadding,
                            shape: const StadiumBorder(),
                            backgroundColor: tokens.main.primary,
                            foregroundColor: tokens.main.onPrimary,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: AppSpacing.xxl,
                                  width: AppSpacing.xxl,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      tokens.main.onPrimary,
                                    ),
                                  ),
                                )
                              : Text(
                                  buttonText,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: tokens.main.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),

                        if (widget.mode == SetUsernameMode.addPersona) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Center(
                            child: TextButton(
                              onPressed: () => context.pop(),
                              child: Text(
                                'Back',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: tokens.main.primary,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlowIndicator(
    ThemeData theme,
    dynamic tokens,
    AddPersonaData data,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: data.isConversion
                  ? tokens.main.tertiaryContainer ??
                        tokens.main.primary.withOpacity(0.15)
                  : tokens.main.primary.withOpacity(0.15),
              borderRadius: AppRadius.small,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  data.isConversion
                      ? Icons.swap_horiz
                      : Icons.add_circle_outline,
                  size: 18,
                  color: tokens.main.primary,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  data.isConversion
                      ? 'Converting to ${data.targetPersona.displayName}'
                      : 'Adding ${data.targetPersona.displayName} profile',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.main.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
