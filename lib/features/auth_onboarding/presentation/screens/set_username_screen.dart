import 'package:flutter/material.dart';
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
import 'package:dabbler/features/auth_onboarding/presentation/widgets/onboarding_widgets.dart';

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
          content: Text(
            'Missing required information. Please complete all steps.',
          ),
          backgroundColor: Colors.red,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing data. Please start over.'),
          backgroundColor: Colors.red,
        ),
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
    Function(String)? onChanged,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final br = BorderRadius.circular(16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
            prefixText: prefixText,
            prefixStyle: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerLowest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: br,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: br,
              borderSide: BorderSide(
                color: colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: br,
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: br,
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: br,
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChips() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_loadingSuggestions) {
      return SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, __) => Container(
            width: 100,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
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
                    ? colorScheme.primary.withValues(alpha: 0.10)
                    : colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                '@$s',
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingTopBar(onBack: () => context.pop()),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OnboardingScreenHead(
                        eyebrow: widget.mode == SetUsernameMode.addPersona
                            ? null
                            : 'Step 5 of 5',
                        title: title,
                        subtitle: subtitle,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Display Name Field
                            _buildInputField(
                              context,
                              controller: _displayNameController,
                              label: AppLocalizations.of(
                                context,
                              ).set_username_display_name_label,
                              hintText: AppLocalizations.of(
                                context,
                              ).set_username_display_name_hint,
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

                            const SizedBox(height: 20),

                            // Username suggestions
                            if (_loadingSuggestions ||
                                _suggestions.isNotEmpty) ...[
                              Text(
                                'Suggestions',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildSuggestionChips(),
                              const SizedBox(height: 16),
                            ],

                            // Username Field
                            _buildInputField(
                              context,
                              controller: _usernameController,
                              label: AppLocalizations.of(
                                context,
                              ).set_username_username_label,
                              hintText: AppLocalizations.of(
                                context,
                              ).set_username_username_hint,
                              prefixText: '@',
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
                                if (!RegExp(
                                  r'^[a-zA-Z0-9_]+$',
                                ).hasMatch(value)) {
                                  return 'Only letters, numbers, and underscores';
                                }
                                return null;
                              },
                              suffixIcon: _isCheckingUsername
                                  ? Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    )
                                  : _usernameError == null &&
                                        _usernameController.text.isNotEmpty
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF00C853),
                                    )
                                  : null,
                            ),

                            if (_usernameError != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                _usernameReason != null &&
                                        _usernameReason!.isNotEmpty
                                    ? _usernameReason!
                                    : _usernameError!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            OnboardingBottomBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OnboardingCTAButton(
                    label: buttonText,
                    onPressed: _isLoading ? null : _handleSubmit,
                    isLoading: _isLoading,
                  ),
                  if (widget.mode == SetUsernameMode.addPersona) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
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
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.displayName});
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final initials = displayName.trim().isEmpty
        ? '?'
        : displayName
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.primary, kObPink],
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: colorScheme.onPrimary,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.camera_alt_outlined,
              size: 16,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
