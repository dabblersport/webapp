import 'package:dabbler/core/config/feature_flags.dart';
import 'package:dabbler/core/services/app_lifecycle_manager.dart';
import 'package:dabbler/features/rewards/controllers/check_in_controller.dart';
import 'package:dabbler/features/rewards/presentation/widgets/early_bird_check_in_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wrapper widget that handles check-in modal logic on app resume
class CheckInWrapper extends ConsumerStatefulWidget {
  const CheckInWrapper({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CheckInWrapper> createState() => _CheckInWrapperState();
}

class _CheckInWrapperState extends ConsumerState<CheckInWrapper> {
  bool _hasShownModalThisSession = false;

  @override
  void initState() {
    super.initState();

    if (!FeatureFlags.enableRewards) return;

    // Register lifecycle callback
    AppLifecycleManager().onResume(_onAppResume);

    // Check after first frame is rendered and navigation is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add extra delay to ensure navigator is ready
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkAndShowModal();
        }
      });
    });
  }

  @override
  void dispose() {
    AppLifecycleManager().offResume(_onAppResume);
    super.dispose();
  }

  void _onAppResume() {
    // Reset session flag when app resumes (allows showing modal again)
    _hasShownModalThisSession = false;
    _checkAndShowModal();
  }

  Future<void> _checkAndShowModal() async {
    if (!mounted) return;
    if (_hasShownModalThisSession) return;

    // Wait a brief moment for navigation to settle
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // Verify we have a valid navigator context
    final navigator = Navigator.maybeOf(context);
    if (navigator == null || !(navigator.mounted)) {
      debugPrint('CheckInWrapper: Navigator not ready yet, skipping');
      return;
    }

    try {
      final controller = ref.read(checkInControllerProvider.notifier);
      final shouldShow = await controller.shouldShowCheckInModal();

      debugPrint('CheckInWrapper: shouldShow=$shouldShow');

      if (shouldShow && mounted) {
        _hasShownModalThisSession = true;

        // Get the current status
        final state = ref.read(checkInControllerProvider);
        final status = state.valueOrNull;

        debugPrint('CheckInWrapper: status=$status');

        // If no status yet (first time user), show with defaults
        final currentDay = status?.totalDaysCompleted ?? 0;
        final streakCount = status?.streakCount ?? 0;
        final daysRemaining = status?.daysRemaining ?? 14;
        final isCompleted = status?.isCompleted ?? false;

        // Show the modal
        EarlyBirdCheckInModal.show(
          context,
          currentDay: currentDay,
          streakCount: streakCount,
          daysRemaining: daysRemaining,
          isCompleted: isCompleted,
          onCheckIn: () async {
            // Perform check-in
            final wasFirstToday = await controller.performCheckIn();

            debugPrint('CheckInWrapper: wasFirstToday=$wasFirstToday');

            if (wasFirstToday && mounted) {
              // Close current modal
              Navigator.of(context).pop();

              // Show success message
              final newStatus = ref.read(checkInControllerProvider).valueOrNull;
              final completedDays = newStatus?.totalDaysCompleted ?? 1;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    completedDays >= 14
                        ? '🎉 Congratulations! You earned the Early Bird badge!'
                        : '✅ Checked in! Day $completedDays of 14',
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );

              // Schedule reminder for next day (if not completed)
              if (completedDays < 14) {
                try {
                  // Note: Uncomment this when flutter_local_notifications is fully configured
                  // await CheckInNotificationService().scheduleCheckInReminder();
                } catch (e) {
                  // Silently fail if notifications aren't set up
                }
              }

              // If completed, show completion modal
              if (completedDays >= 14) {
                await Future.delayed(const Duration(milliseconds: 500));
                if (mounted) {
                  final finalStatus = ref
                      .read(checkInControllerProvider)
                      .valueOrNull;
                  EarlyBirdCheckInModal.show(
                    context,
                    currentDay: 14,
                    streakCount: finalStatus?.streakCount ?? 14,
                    daysRemaining: 0,
                    isCompleted: true,
                    onCheckIn: () {},
                  );
                }
              }
            }
          },
        );
      }
    } catch (e, stack) {
      debugPrint('CheckInWrapper error: $e');
      debugPrint('Stack: $stack');
      // If there's an error, still try to show the modal for first-time users
      if (mounted && !_hasShownModalThisSession) {
        _hasShownModalThisSession = true;
        EarlyBirdCheckInModal.show(
          context,
          currentDay: 0,
          streakCount: 0,
          daysRemaining: 14,
          isCompleted: false,
          onCheckIn: () async {
            final controller = ref.read(checkInControllerProvider.notifier);
            final wasFirstToday = await controller.performCheckIn();

            if (wasFirstToday && mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Checked in! Day 1 of 14'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
