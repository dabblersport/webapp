import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/services/moderation_service.dart';

/// Target types for the shared report dialog.
/// Maps to [ModTarget] under the hood.
enum ReportTargetType {
  user,
  post,
  comment,
  game,
  venue,
  profile,
  message;

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
    }
  }
}

/// Unified report dialog used across the entire app.
///
/// Call via:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => ReportDialog(
///     targetType: ReportTargetType.user,
///     targetId: userId,
///   ),
/// );
/// ```
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
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Text('Report ${widget.targetType.displayLabel}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this ${widget.targetType.displayLabel}?',
            ),
            const SizedBox(height: 16),

            // Reason chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reportReasons.map((option) {
                final isSelected = _selectedReason == option.label;
                return ChoiceChip(
                  label: Text(option.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedReason = selected ? option.label : null;
                      _errorMessage = null;
                    });
                  },
                );
              }).toList(),
            ),

            // Optional details field
            if (_selectedReason != null) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _detailsController,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 500,
              ),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (_selectedReason != null && !_isSubmitting)
              ? _submitReport
              : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Report'),
        ),
      ],
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
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
