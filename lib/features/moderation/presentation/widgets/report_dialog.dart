import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/services/moderation_service.dart';
import 'package:dabbler/l10n/app_localizations.dart';

/// Target types for the shared report dialog.
/// Maps to [ModTarget] under the hood.
enum ReportTargetType {
  user,
  post,
  comment,
  game,
  venue,
  profile,
  message,
  meetup;

  ModTarget toModTarget() {
    switch (this) {
      case ReportTargetType.user:
        return ModTarget.user;
      case ReportTargetType.post:
        return ModTarget.post;
      case ReportTargetType.comment:
        return ModTarget.comment;
      case ReportTargetType.game:
        return ModTarget.game;
      case ReportTargetType.venue:
        return ModTarget.venue;
      case ReportTargetType.profile:
        return ModTarget.profile;
      case ReportTargetType.message:
        return ModTarget.message;
      case ReportTargetType.meetup:
        return ModTarget.meetup;
    }
  }

  String get displayLabel {
    switch (this) {
      case ReportTargetType.user:
        return 'user';
      case ReportTargetType.post:
        return 'post';
      case ReportTargetType.comment:
        return 'comment';
      case ReportTargetType.game:
        return 'game';
      case ReportTargetType.venue:
        return 'venue';
      case ReportTargetType.profile:
        return 'profile';
      case ReportTargetType.message:
        return 'message';
      case ReportTargetType.meetup:
        return 'meet-up';
    }
  }
}

/// Opens the unified report dialog as a design-system dialog.
Future<void> showReportDialog(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  String? targetUserId,
}) => showDabblerDialog<void>(
  context: context,
  builder: (_) => ReportDialog(
    targetType: targetType,
    targetId: targetId,
    targetUserId: targetUserId,
  ),
);

/// Unified report dialog used across the entire app.
///
/// Call via [showReportDialog].
class ReportDialog extends ConsumerStatefulWidget {
  final ReportTargetType targetType;
  final String targetId;

  /// Optional user ID of the target (e.g. post author, game organiser).
  /// Only needed for [ModTarget.user] or if you want to track target ownership.
  final String? targetUserId;

  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetUserId,
  });

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<_ReasonOption> _reportReasons = [
    _ReasonOption('Spam', ReportReason.spam),
    _ReasonOption('Harassment', ReportReason.harassment),
    _ReasonOption('Inappropriate content', ReportReason.nudity),
    _ReasonOption('Hate speech', ReportReason.hate),
    _ReasonOption('Scam / False info', ReportReason.scam),
    _ReasonOption('Violence / Danger', ReportReason.danger),
    _ReasonOption('Impersonation', ReportReason.impersonation),
    _ReasonOption('Other', ReportReason.other),
  ];

  ReportReason? get _selectedReportReason {
    if (_selectedReason == null) return null;
    return _reportReasons.firstWhere((r) => r.label == _selectedReason).reason;
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.targetType.displayLabel;

    return DabblerDialog(
      title: 'Report $label',
      description: 'Why are you reporting this $label?',
      onClose: () => Navigator.pop(context),
      secondaryAction: DabblerDialogAction(
        label: AppLocalizations.of(context).profile_btn_cancel,
        onPressed: () => Navigator.pop(context),
      ),
      primaryAction: DabblerDialogAction(
        label: _isSubmitting ? 'Sending…' : 'Submit Report',
        onPressed: (_selectedReason != null && !_isSubmitting)
            ? _submitReport
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: DabblerSpacing.space2,
            runSpacing: DabblerSpacing.space2,
            children: _reportReasons.map((option) {
              final isSelected = _selectedReason == option.label;
              return DabblerChip(
                label: option.label,
                selected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedReason = isSelected ? null : option.label;
                    _errorMessage = null;
                  });
                },
              );
            }).toList(),
          ),
          if (_selectedReason != null) ...[
            const DabblerGap.v(DabblerSpacing.space4),
            DabblerTextField(
              variant: DabblerTextFieldVariant.multiline,
              controller: _detailsController,
              label: 'Additional details (optional)',
              rows: 3,
            ),
          ],
          if (_errorMessage != null) ...[
            const DabblerGap.v(DabblerSpacing.space2),
            DabblerBanner(
              tone: DabblerBannerTone.error,
              message: _errorMessage,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    final reason = _selectedReportReason;
    if (reason == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final moderationService = ref.read(moderationServiceProvider);

      // Cooldown check: max 5 reports per 10 min window
      try {
        final cooldown = await moderationService.checkAndBumpCooldown(
          'report:${widget.targetType.name}',
          windowSeconds: 600,
          limitCount: 5,
        );
        if (!cooldown.allowed) {
          setState(() {
            _isSubmitting = false;
            _errorMessage =
                'You\'re reporting too frequently. Please wait a moment.';
          });
          return;
        }
      } catch (_) {
        // If cooldown check fails, proceed anyway — don't block real reports
      }

      final details = _detailsController.text.trim().isEmpty
          ? null
          : _detailsController.text.trim();

      await moderationService.submitReport(
        target: widget.targetType.toModTarget(),
        targetId: widget.targetId,
        reason: reason,
        details: details,
      );

      if (mounted) {
        final toast = DabblerToastProvider.of(context);
        Navigator.pop(context);
        toast.show(
          const DabblerToastSpec(
            message: 'Report submitted. Thank you.',
            tone: DabblerToastTone.success,
          ),
        );
      }
    } on ModerationServiceException catch (e) {
      if (mounted) {
        // Check for duplicate report (unique constraint violation)
        final msg = e.message;
        if (msg.contains('duplicate') || msg.contains('unique')) {
          setState(() {
            _isSubmitting = false;
            _errorMessage = 'You have already reported this content.';
          });
        } else {
          setState(() {
            _isSubmitting = false;
            _errorMessage = 'Failed to submit report. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to submit report. Please try again.';
        });
      }
    }
  }
}

class _ReasonOption {
  final String label;
  final ReportReason reason;
  const _ReasonOption(this.label, this.reason);
}
