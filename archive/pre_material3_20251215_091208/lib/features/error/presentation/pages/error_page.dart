import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/app_button.dart';
import '../../../../core/config/design_system/design_tokens/spacing.dart';
import '../../../../core/config/design_system/design_tokens/typography.dart';

class ErrorPage extends StatelessWidget {
  final String? message;

  const ErrorPage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Error', style: DabblerTypography.headline6()),
      ),
      body: Padding(
        padding: DabblerSpacing.all24,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: DabblerSpacing.spacing24),
              Text(
                message ?? 'An error occurred',
                style: DabblerTypography.headline5(),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: DabblerSpacing.spacing16),
              Text(
                'Please try again or contact support if the problem persists.',
                style: DabblerTypography.body1(),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: DabblerSpacing.spacing32),
              AppButton(label: 'Retry', onPressed: () => context.pop()),
            ],
          ),
        ),
      ),
    );
  }
}
