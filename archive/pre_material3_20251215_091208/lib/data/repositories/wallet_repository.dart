import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/wallet.dart';
import '../models/payout.dart';

abstract class WalletRepository {
  /// Current user's wallet (RLS-scoped). Null if not created yet.
  Future<Result<Wallet?, Failure>> getWallet();

  /// Current user's ledger entries, newest first.
  Future<Result<List<WalletLedgerEntry>, Failure>> getLedger({
    int limit = 50,
    int offset = 0,
  });

  /// Current user's payout history, newest first.
  Future<Result<List<Payout>, Failure>> getPayouts({
    int limit = 50,
    int offset = 0,
  });
}
