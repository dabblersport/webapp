import 'package:dabbler/data/models/check_in/check_in_status.dart';
import 'package:dabbler/data/repositories/check_in_repository.dart';
import 'package:dabbler/data/repositories/check_in_repository_impl.dart';
import 'package:riverpod/riverpod.dart';
import 'package:dabbler/features/misc/data/datasources/supabase_remote_data_source.dart';

/// Provider for CheckInRepository
final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  return CheckInRepositoryImpl(supabaseService);
});

/// Provider for current check-in status detail
final checkInStatusDetailProvider = FutureProvider<CheckInStatusDetail>((
  ref,
) async {
  final repository = ref.watch(checkInRepositoryProvider);
  final result = await repository.getCheckInStatus();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (status) => status,
  );
});

/// Provider for full check-in record
final checkInRecordProvider = FutureProvider<CheckInStatus?>((ref) async {
  final repository = ref.watch(checkInRepositoryProvider);
  final result = await repository.getCheckInRecord();

  return result.fold(
    (failure) => throw Exception(failure.message),
    (record) => record,
  );
});

/// Stream provider for real-time check-in status updates
final watchCheckInStatusProvider = StreamProvider<CheckInStatus?>((ref) {
  final repository = ref.watch(checkInRepositoryProvider);

  return repository.watchCheckInStatus().map((result) {
    return result.fold(
      (failure) => throw Exception(failure.message),
      (status) => status,
    );
  });
});
