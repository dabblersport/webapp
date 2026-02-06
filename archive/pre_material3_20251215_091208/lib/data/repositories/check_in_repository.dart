import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/check_in/check_in_status.dart';
import 'package:dabbler/data/models/check_in/check_in_log.dart';

/// Repository interface for check-in operations
/// Follows clean architecture with Result return types for error handling
abstract class CheckInRepository {
  /// Performs a check-in for the current user
  /// Calls the Supabase perform_check_in() function
  /// Returns CheckInResponse on success or Failure on error
  Future<Result<CheckInResponse, Failure>> performCheckIn({
    Map<String, dynamic>? deviceInfo,
  });

  /// Gets the current check-in status for the user
  /// Calls the Supabase get_check_in_status() function
  /// Returns CheckInStatusDetail on success or Failure on error
  Future<Result<CheckInStatusDetail, Failure>> getCheckInStatus();

  /// Gets the full check-in record from user_check_ins table
  /// Returns CheckInStatus on success or Failure on error
  Future<Result<CheckInStatus?, Failure>> getCheckInRecord();

  /// Gets all check-in logs for the user
  /// Returns list of CheckInLog on success or Failure on error
  Future<Result<List<CheckInLog>, Failure>> getCheckInLogs({int? limit});

  /// Watches the check-in status for real-time updates
  /// Returns a stream of CheckInStatus updates
  Stream<Result<CheckInStatus?, Failure>> watchCheckInStatus();
}
