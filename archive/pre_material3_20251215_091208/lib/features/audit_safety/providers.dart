import 'package:riverpod/riverpod.dart';

import 'package:dabbler/data/models/abuse_flag.dart';
import 'package:dabbler/data/models/ban_term.dart';
import 'package:dabbler/data/models/moderation_action.dart';
import 'package:dabbler/data/models/moderation_ticket.dart';
import '../../data/repositories/audit_safety_repository.dart';
import 'package:dabbler/core/fp/result.dart';
import '../../data/repositories/audit_safety_repository_impl.dart';
import '../../features/misc/data/datasources/supabase_remote_data_source.dart';

final auditSafetyRepositoryProvider = Provider<AuditSafetyRepository>((ref) {
  final service = ref.watch(supabaseServiceProvider);
  return AuditSafetyRepositoryImpl(service);
});

class FlagsArgs {
  const FlagsArgs({
    this.status,
    this.subjectType,
    this.limit = 50,
    this.before,
  });

  final String? status;
  final String? subjectType;
  final int limit;
  final DateTime? before;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlagsArgs &&
        other.status == status &&
        other.subjectType == subjectType &&
        other.limit == limit &&
        other.before == before;
  }

  @override
  int get hashCode => Object.hash(status, subjectType, limit, before);
}

final flagsProvider = FutureProvider.family<List<AbuseFlag>, FlagsArgs>((
  ref,
  args,
) async {
  final repo = ref.watch(auditSafetyRepositoryProvider);
  final result = await repo.listFlags(
    status: args.status,
    subjectType: args.subjectType,
    limit: args.limit,
    before: args.before,
  );

  return result.match((failure) => throw failure, (flags) => flags);
});

class TicketsArgs {
  const TicketsArgs({this.status, this.limit = 50, this.before});

  final String? status;
  final int limit;
  final DateTime? before;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TicketsArgs &&
        other.status == status &&
        other.limit == limit &&
        other.before == before;
  }

  @override
  int get hashCode => Object.hash(status, limit, before);
}

final ticketsProvider =
    FutureProvider.family<List<ModerationTicket>, TicketsArgs>((
      ref,
      args,
    ) async {
      final repo = ref.watch(auditSafetyRepositoryProvider);
      final result = await repo.listTickets(
        status: args.status,
        limit: args.limit,
        before: args.before,
      );

      return result.match((failure) => throw failure, (tickets) => tickets);
    });

class ActionsArgs {
  const ActionsArgs({
    this.subjectType,
    this.subjectId,
    this.limit = 50,
    this.before,
  });

  final String? subjectType;
  final String? subjectId;
  final int limit;
  final DateTime? before;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActionsArgs &&
        other.subjectType == subjectType &&
        other.subjectId == subjectId &&
        other.limit == limit &&
        other.before == before;
  }

  @override
  int get hashCode => Object.hash(subjectType, subjectId, limit, before);
}

final actionsProvider =
    FutureProvider.family<List<ModerationAction>, ActionsArgs>((
      ref,
      args,
    ) async {
      final repo = ref.watch(auditSafetyRepositoryProvider);
      final result = await repo.listActions(
        subjectType: args.subjectType,
        subjectId: args.subjectId,
        limit: args.limit,
        before: args.before,
      );

      return result.match((failure) => throw failure, (actions) => actions);
    });

final banTermsProvider = FutureProvider.family<List<BanTerm>, bool?>((
  ref,
  enabled,
) async {
  final repo = ref.watch(auditSafetyRepositoryProvider);
  final result = await repo.listBanTerms(enabled: enabled);

  return result.match((failure) => throw failure, (terms) => terms);
});
