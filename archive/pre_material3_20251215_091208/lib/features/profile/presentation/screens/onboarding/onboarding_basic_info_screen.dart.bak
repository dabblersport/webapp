import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'onboarding_welcome_screen.dart';
import 'package:dabbler/themes/design_system.dart';
import 'package:dabbler/routes/app_routes.dart';

class OnboardingBasicInfoScreen extends ConsumerStatefulWidget {
  const OnboardingBasicInfoScreen({super.key});

  @override
  ConsumerState<OnboardingBasicInfoScreen> createState() =>
      _OnboardingBasicInfoScreenState();
}

class _OnboardingBasicInfoScreenState
    extends ConsumerState<OnboardingBasicInfoScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
    _loadExistingData();
  }

  void _loadExistingData() {
    final controller = ref.read(onboardingControllerProvider);
    final existingData = controller.progress?.stepData['step_1'];

    if (existingData != null) {
      _nameController.text = existingData['display_name'] ?? '';
      _bioController.text = existingData['bio'] ?? '';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(onboardingControllerProvider);
    final variant = controller.currentVariant ?? 'control';

    return Scaffold(
      backgroundColor: DesignSystem.colors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildContent(context, variant),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String variant) {
    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          backgroundColor: DesignSystem.colors.background,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.go(AppRoutes.onboardingWelcome),
            icon: Icon(
              LucideIcons.arrowLeft,
              color: DesignSystem.colors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _skipStep(),
              child: Text(
                'Skip',
                style: TextStyle(color: DesignSystem.colors.textSecondary),
              ),
            ),
          ],
        ),

        // Content
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(variant),

                  const SizedBox(height: 32),

                  // Profile photo section
                  _buildProfilePhotoSection(variant),

                  const SizedBox(height: 32),

                  // Name field
                  _buildNameField(),

                  const SizedBox(height: 24),

                  // Bio field (optional)
                  _buildBioField(variant),

                  const Spacer(),

                  // Personalized tip
                  _buildPersonalizedTip(variant),

                  const SizedBox(height: 24),

                  // Continue button
                  _buildContinueButton(variant),

                  const SizedBox(height: 16),

                  // Progress indicator
                  _buildProgressIndicator(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          variant == 'gamified'
              ? '🎯 Create Your Player Profile'
              : 'Tell Us About Yourself',
          style: DesignSystem.typography.headlineMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          variant == 'gamified'
              ? 'Add your photo and name to earn your first 25 points!'
              : 'Help other players recognize and connect with you',
          style: DesignSystem.typography.bodyLarge.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhotoSection(String variant) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedImage != null
                      ? DesignSystem.colors.primary
                      : DesignSystem.colors.border,
                  width: 3,
                ),
                color: _selectedImage != null
                    ? null
                    : DesignSystem.colors.surface,
              ),
              child: _selectedImage != null
                  ? ClipOval(
                      child: Image.file(
                        _selectedImage!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(
                      LucideIcons.camera,
                      size: 40,
                      color: DesignSystem.colors.textSecondary,
                    ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _selectedImage != null ? 'Tap to change photo' : 'Tap to add photo',
            style: DesignSystem.typography.bodyMedium.copyWith(
              color: DesignSystem.colors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (variant == 'gamified' && _selectedImage != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: DesignSystem.colors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '+15 points earned!',
                style: DesignSystem.typography.bodySmall.copyWith(
                  color: DesignSystem.colors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display Name*',
          style: DesignSystem.typography.titleMedium.copyWith(
            color: DesignSystem.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'How should other players know you?',
            prefixIcon: Icon(LucideIcons.user),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DesignSystem.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DesignSystem.colors.primary),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your display name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
          onChanged: (value) {
            if (mounted) setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildBioField(String variant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Bio',
              style: DesignSystem.typography.titleMedium.copyWith(
                color: DesignSystem.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(width: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: DesignSystem.colors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Optional',
                style: DesignSystem.typography.bodySmall.copyWith(
                  color: DesignSystem.colors.secondary,
                ),
              ),
            ),

            if (variant == 'gamified')
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DesignSystem.colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+5 points',
                  style: DesignSystem.typography.bodySmall.copyWith(
                    color: DesignSystem.colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        TextFormField(
          controller: _bioController,
          maxLines: 3,
          maxLength: 150,
          decoration: InputDecoration(
            hintText:
                'Tell others about your sports interests or playing style...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DesignSystem.colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: DesignSystem.colors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalizedTip(String variant) {
    final controller = ref.read(onboardingControllerProvider);
    final tip = controller.getPersonalizedTip();

    if (tip.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignSystem.colors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DesignSystem.colors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.lightbulb,
            color: DesignSystem.colors.primary,
            size: 20,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              tip,
              style: DesignSystem.typography.bodyMedium.copyWith(
                color: DesignSystem.colors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton(String variant) {
    final canContinue = _nameController.text.trim().isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canContinue ? () => _continue() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: DesignSystem.colors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canContinue ? 4 : 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    variant == 'gamified'
                        ? 'Claim Points & Continue'
                        : 'Continue',
                    style: DesignSystem.typography.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(LucideIcons.arrowRight, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Text(
          'Step 1 of 4',
          style: DesignSystem.typography.bodySmall.copyWith(
            color: DesignSystem.colors.textSecondary,
          ),
        ),

        const SizedBox(height: 8),

        LinearProgressIndicator(
          value: 0.25,
          backgroundColor: DesignSystem.colors.border,
          valueColor: AlwaysStoppedAnimation<Color>(
            DesignSystem.colors.primary,
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DesignSystem.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Select Photo',
                style: DesignSystem.typography.headlineSmall.copyWith(
                  color: DesignSystem.colors.textPrimary,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _buildImageOption(
                      icon: LucideIcons.camera,
                      label: 'Camera',
                      onTap: () async {
                        Navigator.pop(context);
                        final image = await picker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (image != null) {
                          setState(() {
                            _selectedImage = File(image.path);
                          });
                        }
                      },
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: _buildImageOption(
                      icon: LucideIcons.image,
                      label: 'Gallery',
                      onTap: () async {
                        Navigator.pop(context);
                        final image = await picker.pickImage(
                          source: ImageSource.gallery,
                        );
                        if (image != null) {
                          setState(() {
                            _selectedImage = File(image.path);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: DesignSystem.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: DesignSystem.colors.primary),

            const SizedBox(height: 8),

            Text(
              label,
              style: DesignSystem.typography.titleSmall.copyWith(
                color: DesignSystem.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final controller = ref.read(onboardingControllerProvider);
      final gamification = ref.read(onboardingGamificationProvider);
      final variant = controller.currentVariant ?? 'control';

      // Prepare step data
      final stepData = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'photo': _selectedImage?.path,
        'completed_at': DateTime.now().toIso8601String(),
      };

      // Complete the step
      await controller.completeStep(1, stepData);

      // Award points for gamified variant
      if (variant == 'gamified') {
        final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (userId != null) {
          int points = 10; // Base points for name
          if (_selectedImage != null) points += 15; // Photo bonus
          if (_bioController.text.trim().isNotEmpty) points += 5; // Bio bonus

          await gamification.awardPoints(
            userId,
            points,
            'onboarding_step_1',
            'Completed basic profile information',
          );
        }
      }

      // Show achievement if gamified
      if (variant == 'gamified') {
        _showAchievement();
      } else {
        _navigateNext();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: DesignSystem.colors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _skipStep() {
    final controller = ref.read(onboardingControllerProvider);
    controller.skipStep(1, reason: 'user_skipped');
    context.go(AppRoutes.onboardingSports);
  }

  void _showAchievement() {
    final gamification = ref.read(onboardingGamificationProvider);
    final achievement = gamification.getStepAchievement(1, 'gamified');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: DesignSystem.colors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.trophy,
                size: 40,
                color: DesignSystem.colors.success,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              achievement.title,
              style: DesignSystem.typography.headlineSmall.copyWith(
                color: DesignSystem.colors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            Text(
              achievement.description,
              style: DesignSystem.typography.bodyMedium.copyWith(
                color: DesignSystem.colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignSystem.colors.primary,
              ),
              child: const Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateNext() {
    context.go(AppRoutes.onboardingSports);
  }
}
