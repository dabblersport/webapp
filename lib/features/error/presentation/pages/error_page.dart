import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/utils/constants/route_constants.dart';

class ErrorPage extends StatelessWidget {
  final String? message;

  const ErrorPage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Error', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                message ?? 'An error occurred',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please try again or contact support if the problem persists.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.home),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
