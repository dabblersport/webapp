import 'package:dabbler/core/cache/cache_providers.dart';
import 'package:dabbler/core/data/supabase_client.dart';
import 'package:dabbler/core/services/connectivity_service.dart';
import 'package:dabbler/features/bench/data/bench_repository.dart';
import 'package:dabbler/features/bench/data/bench_status.dart';
import 'package:dabbler/features/bench/presentation/controllers/bench_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final benchRepositoryProvider = Provider<BenchRepository>(
  (ref) => BenchRepository(ref.watch(supabaseClientProvider)),
);

/// The viewer's bench state. Kept on the device per account, so offline the
/// last read status still shows (KAN-706 behaviour 6). Invalidated after
/// every write.
final benchStatusProvider = FutureProvider.autoDispose<BenchStatus>((ref) {
  // An account switch reads the new viewer's row.
  ref.watch(cacheAccountIdProvider);
  final repo = ref.watch(benchRepositoryProvider);
  return swrFetch<BenchStatus>(
    ref,
    key: 'bench.status',
    fetch: () async =>
        (await repo.load()).fold((failure) => throw failure, (s) => s),
    encode: (status) => status.toJson(),
    decode: (json) =>
        BenchStatus.fromRow(Map<String, dynamic>.from(json as Map)),
  );
});

/// Whether the device is offline: writes are disabled and nothing is queued.
final benchOfflineProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(connectivityProvider) == ConnectionStatus.offline,
);

/// Start, save and end, with their in-flight and failed states.
final benchControllerProvider =
    StateNotifierProvider.autoDispose<BenchController, BenchActionState>(
      (ref) => BenchController(
        repository: ref.watch(benchRepositoryProvider),
        onWritten: () => ref.invalidate(benchStatusProvider),
      ),
    );
