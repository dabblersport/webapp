import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/core/services/auth_service.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

import 'transactions_parts.dart';

export 'transaction_details_sheet.dart' show TransactionDetailsSheet;

/// Transactions history screen (route behind a feature flag, mock data).
///
/// No design frame: same structure as before on DS defaults. The history body
/// (summary, search, filters, grouped list, details sheet) lives in
/// [TransactionsHistoryView].
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final user = _authService.getCurrentUser();

    // One layout at every width: the wide-screen rail wrapper is
    // not a DS component; the app shell owns wide navigation.
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        onBack: Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null,
        actions: [
          DabblerNavigationAction(
            icon: 'document-download',
            label: 'Export',
            onPressed: _exportTransactions,
          ),
        ],
      ),
      body: user == null
          ? const TransactionsSignInPrompt()
          : const TransactionsHistoryView(),
    );
  }

  void _exportTransactions() {
    DabblerToastProvider.of(context).show(
      const DabblerToastSpec(
        message: 'Exporting transactions...',
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Signed-out body: prompt plus a sign-in button.
class TransactionsSignInPrompt extends StatelessWidget {
  const TransactionsSignInPrompt({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(DabblerSpacing.space8),
      child: DabblerEmptyState(
        icon: 'profile-delete',
        size: DabblerEmptyStateSize.page,
        title: 'Sign in to view transactions',
        text: 'Track your payments and transaction history',
        action: DabblerButton(
          label: 'Sign In',
          onPressed: () => context.go(RoutePaths.authWelcome),
        ),
      ),
    ),
  );
}
