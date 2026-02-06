import 'package:meta/meta.dart';
import 'package:dabbler/core/fp/failure.dart';

import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/utils/json.dart';
import '../models/payout.dart';
import '../models/wallet.dart';
import 'base_repository.dart';
import 'wallet_repository.dart';

@immutable
class WalletRepositoryImpl extends BaseRepository implements WalletRepository {
  const WalletRepositoryImpl(super.svc);

  @override
  Future<Result<Wallet?, Failure>> getWallet() {
    return guard<Wallet?>(() async {
      // RLS should scope to the caller's row; we fetch one.
      final row = await svc.client.from('wallets').select().maybeSingle();

      if (row == null) return null;
      return Wallet.fromMap(asMap(row));
    });
  }

  @override
  Future<Result<List<WalletLedgerEntry>, Failure>> getLedger({
    int limit = 50,
    int offset = 0,
  }) {
    return guard<List<WalletLedgerEntry>>(() async {
      final rows = await svc.client
          .from('wallet_ledger')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return rows.map((m) => WalletLedgerEntry.fromMap(asMap(m))).toList();
    });
  }

  @override
  Future<Result<List<Payout>, Failure>> getPayouts({
    int limit = 50,
    int offset = 0,
  }) {
    return guard<List<Payout>>(() async {
      final rows = await svc.client
          .from('payouts')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return rows.map((m) => Payout.fromMap(asMap(m))).toList();
    });
  }
}
