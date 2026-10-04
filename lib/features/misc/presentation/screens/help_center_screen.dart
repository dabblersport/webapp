import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: 'Help Center',
        border: true,
        onBack: () => Navigator.maybePop(context),
      ),
      body: const Center(
        child: DabblerEmptyState(
          icon: 'message-question',
          title: 'Help Center',
          text: 'This screen is under development',
        ),
      ),
    );
  }
}
