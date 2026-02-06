import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:dabbler/core/viewmodels/game_creation_viewmodel.dart';
import 'package:dabbler/data/models/core/game_creation_model.dart';
import 'package:dabbler/features/misc/presentation/screens/participation_payment_step.dart';
import 'package:dabbler/features/misc/presentation/screens/player_invitation_step.dart';
import 'package:dabbler/features/misc/presentation/screens/review_confirmation_step.dart';
import 'package:dabbler/features/misc/presentation/screens/sport_format_step.dart';
import 'package:dabbler/features/misc/presentation/screens/venue_slot_step.dart';
import 'package:dabbler/routes/route_arguments.dart';
import 'package:dabbler/themes/app_theme.dart';
import 'package:dabbler/widgets/app_button.dart';

class CreateGameScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const CreateGameScreen({super.key, this.initialData});

  @override
  State<CreateGameScreen> createState() => _CreateGameScreenState();
}

class _CreateGameScreenState extends State<CreateGameScreen> {
  late final GameCreationViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = GameCreationViewModel();
    _hydrateFromInitialData();
  }

  void _hydrateFromInitialData() {
    final draftId = widget.initialData != null
        ? widget.initialData!['draftId'] as String?
        : null;
    if (draftId != null && draftId.isNotEmpty) {
      _loadDraft(draftId);
    }

    final seed = _parseBookingSeed(widget.initialData?['fromBooking']);
    if (seed != null) {
      _viewModel.applyBookingSeed(seed);
    }
  }

  BookingSeedData? _parseBookingSeed(dynamic raw) {
    if (raw == null) return null;
    if (raw is BookingSeedData) return raw;
    if (raw is Map<String, dynamic>) {
      final bookingId = raw['bookingId'] as String?;
      final venueName = raw['venueName'] as String?;
      final dateString = raw['date'] as String?;
      final timeLabel = raw['timeLabel'] as String?;
      final sport = raw['sport'] as String?;

      final parsedDate = dateString != null
          ? DateTime.tryParse(dateString)
          : null;

      if (bookingId == null ||
          venueName == null ||
          parsedDate == null ||
          timeLabel == null ||
          sport == null) {
        return null;
      }

      return BookingSeedData(
        bookingId: bookingId,
        venueId: raw['venueId'] as String?,
        venueName: venueName,
        venueLocation: raw['venueLocation'] as String?,
        date: parsedDate,
        timeLabel: timeLabel,
        sport: sport,
      );
    }
    return null;
  }

  Future<void> _loadDraft(String draftId) async {
    try {
      await _viewModel.loadDraft(draftId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  LucideIcons.alertCircle,
                  color: context.colors.onPrimary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Failed to load draft: $e',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: context.dangerColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: context.colors.surface,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: _buildHeaderSection(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _buildProgressIndicator(context),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildStepContent()),
                _buildNavigationButtons(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    final canReset =
        _viewModel.state.currentStep != GameCreationStep.sportAndFormat;

    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: () => _handleCancelPressed(context),
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            backgroundColor: context.surfaceContainerHigh,
            foregroundColor: context.colors.onSurface,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create game',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _viewModel.state.stepTitle,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (canReset) ...[
          const SizedBox(width: 16),
          FilledButton.tonal(
            onPressed: _viewModel.reset,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Reset'),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressIndicator(BuildContext context) {
    final progress = _viewModel.state.progress;
    final stepIndex = _viewModel.state.stepIndex;
    final totalSteps = _viewModel.state.totalSteps;
    final canSaveAsDraft = _viewModel.state.canSaveAsDraft;
    final isLoading = _viewModel.state.isLoading;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: context.colors.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step ${stepIndex + 1} of $totalSteps',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _viewModel.state.stepTitle,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${(progress * 100).round()}%',
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (canSaveAsDraft) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: isLoading ? null : () => _handleSaveAsDraft(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: context.colors.primary.withValues(
                              alpha: 0.2,
                            ),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.save,
                              size: 14,
                              color: context.colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Save Draft',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: context.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: context.colors.outline.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colors.primary,
                        context.colors.primary.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(totalSteps, (index) {
                  final isCompleted = index < stepIndex;
                  final isCurrent = index == stepIndex;

                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? context.colors.primary
                          : context.colors.outline.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.colors.surface,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? Icon(
                            LucideIcons.check,
                            size: 6,
                            color: context.colors.onPrimary,
                          )
                        : null,
                  );
                }),
              ),
            ],
          ),
          if (_viewModel.state.isDraft &&
              _viewModel.state.lastSaved != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  LucideIcons.clock,
                  size: 12,
                  color: context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Last saved ${_getTimeAgo(_viewModel.state.lastSaved!)}',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_viewModel.state.currentStep) {
      case GameCreationStep.sportAndFormat:
        return SportFormatStep(viewModel: _viewModel);
      case GameCreationStep.venueAndSlot:
        return VenueSlotStep(viewModel: _viewModel);
      case GameCreationStep.participationAndPayment:
        return ParticipationPaymentStep(viewModel: _viewModel);
      case GameCreationStep.playerInvitation:
        return PlayerInvitationStep(viewModel: _viewModel);
      case GameCreationStep.reviewAndConfirm:
        return ReviewConfirmationStep(viewModel: _viewModel);
    }
  }

  Widget _buildNavigationButtons(BuildContext context) {
    final state = _viewModel.state;
    final canGoBack = state.previousStep != null;
    final canGoNext = state.canProceedToNextStep;
    final isLastStep = state.currentStep == GameCreationStep.reviewAndConfirm;
    final isLoading = state.isLoading;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        color: context.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (canGoBack)
              Expanded(
                child: AppButton(
                  label: 'Back',
                  onPressed: isLoading ? null : _viewModel.previousStep,
                  variant: ButtonVariant.secondary,
                  leadingIcon: LucideIcons.arrowLeft,
                ),
              ),
            if (canGoBack) const SizedBox(width: 12),
            Expanded(
              flex: canGoBack ? 1 : 2,
              child: AppButton(
                label: isLastStep ? 'Create Game' : 'Continue',
                onPressed: canGoNext && !isLoading ? _handleNextPressed : null,
                variant: ButtonVariant.primary,
                leadingIcon: isLastStep ? null : LucideIcons.arrowRight,
                isLoading: isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _handleSaveAsDraft() async {
    try {
      await _viewModel.saveAsDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  LucideIcons.check,
                  color: context.colors.onPrimary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Draft saved successfully',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: context.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  LucideIcons.alertCircle,
                  color: context.colors.onPrimary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'Failed to save draft: $e',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: context.dangerColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleNextPressed() async {
    final state = _viewModel.state;

    // Check if we can proceed - if not, show helpful message
    if (!state.canProceedToNextStep) {
      final missingFields = state.getMissingRequiredFields();
      if (missingFields.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  LucideIcons.alertCircle,
                  color: context.colors.onPrimary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please complete: ${missingFields.join(', ')}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: context.colors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (state.currentStep == GameCreationStep.reviewAndConfirm) {
      final success = await _viewModel.createGame();
      if (success && mounted) {
        _showSuccessDialog();
      } else if (mounted && _viewModel.state.error != null) {
        _showErrorDialog(_viewModel.state.error!);
      }
    } else {
      _viewModel.nextStep();
    }
  }

  void _handleCancelPressed(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                LucideIcons.xCircle,
                color: context.colors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cancel Game Creation',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel game creation? You will lose all unsaved progress.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        actions: [
          AppButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
            variant: ButtonVariant.secondary,
          ),
          AppButton(
            label: 'Confirm Cancel',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                LucideIcons.check,
                color: context.successColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Game Created!',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Your game has been created successfully. Players will be notified about the invitation.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        actions: [
          AppButton(
            label: 'Done',
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            variant: ButtonVariant.primary,
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                LucideIcons.alertCircle,
                color: context.colors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Error',
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          error,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        actions: [
          AppButton(
            label: 'Try Again',
            onPressed: () => Navigator.of(context).pop(),
            variant: ButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}
