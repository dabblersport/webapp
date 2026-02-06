import 'package:dabbler/data/models/check_in/check_in_status.dart';
import 'package:dabbler/features/rewards/providers/check_in_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State notifier for managing check-in operations
class CheckInController
    extends StateNotifier<AsyncValue<CheckInStatusDetail?>> {
  CheckInController(this.ref) : super(const AsyncValue.loading()) {
    _init();
  }

  final Ref ref;

  void _init() async {
    try {
      final status = await ref.read(checkInStatusDetailProvider.future);
      state = AsyncValue.data(status);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Performs a check-in for the current user
  /// Returns true if this was the first check-in of the day (show modal)
  Future<bool> performCheckIn({Map<String, dynamic>? deviceInfo}) async {
    state = const AsyncValue.loading();

    debugPrint('CheckInController: Performing check-in');

    final repository = ref.read(checkInRepositoryProvider);
    final result = await repository.performCheckIn(deviceInfo: deviceInfo);

    return result.fold(
      (failure) {
        debugPrint('CheckInController: Check-in failed: ${failure.message}');
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
      (response) {
        debugPrint('CheckInController: Check-in successful: $response');

        // Update the status detail
        final newStatus = CheckInStatusDetail(
          streakCount: response.streakCount,
          totalDaysCompleted: response.totalDaysCompleted,
          isCompleted: response.isCompleted,
          lastCheckIn: DateTime.now(),
          checkedInToday: true,
          daysRemaining: 14 - response.totalDaysCompleted,
        );

        state = AsyncValue.data(newStatus);

        // Invalidate the status provider to refresh
        ref.invalidate(checkInStatusDetailProvider);

        // Return whether this was the first check-in today (to show modal)
        return response.isFirstCheckInToday;
      },
    );
  }

  /// Checks if the user should see the check-in modal
  /// Returns true if they haven't checked in today and feature is enabled
  Future<bool> shouldShowCheckInModal() async {
    try {
      final status = await ref.read(checkInStatusDetailProvider.future);
      return !status.checkedInToday && !status.isCompleted;
    } catch (e) {
      // If there's an error (e.g., user never checked in), show modal
      return true;
    }
  }

  /// Gets the progress percentage (0-100)
  int getProgressPercentage() {
    final status = state.valueOrNull;
    if (status == null) return 0;

    return ((status.totalDaysCompleted / 14) * 100).round();
  }

  /// Gets a list of completed day indices (0-13)
  List<int> getCompletedDays() {
    final status = state.valueOrNull;
    if (status == null) return [];

    return List.generate(status.totalDaysCompleted, (index) => index);
  }

  /// Refreshes the check-in status
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final status = await ref.refresh(checkInStatusDetailProvider.future);
      state = AsyncValue.data(status);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for the check-in controller
final checkInControllerProvider =
    StateNotifierProvider<CheckInController, AsyncValue<CheckInStatusDetail?>>(
      (ref) => CheckInController(ref),
    );
