// Device harness for the location intro (non-blocking hand-off): the REAL
// intro screen, permission gateway, GPS service and active-location notifier;
// auth is faked (fixed user id), nothing is written. It logs tap -> Home
// timings and the active-location state TYPE (never coordinates):
//   flutter run -d <device> -t test/features/auth_onboarding/web_harness/intro_timing_main.dart
import 'package:dabbler/features/auth_onboarding/presentation/screens/location_intro_screen.dart';
import 'package:dabbler/features/location/providers/active_location_provider.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void _log(String what) =>
    debugPrint('KAN489T ${DateTime.now().millisecondsSinceEpoch} $what');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: 'https://harness.invalid', anonKey: 'x');
  final router = GoRouter(
    initialLocation: '/start',
    routes: <RouteBase>[
      GoRoute(
        path: '/start',
        builder: (_, __) => const LocationIntroScreen(userId: 'harness-user'),
      ),
      GoRoute(path: RoutePaths.home, builder: (_, __) => const _Home()),
    ],
  );
  // Three measured runs: tap the CTA the way a finger does (real pointer
  // events through the gesture system), then come back to a fresh intro.
  var run = 0;
  Future<void> cycle() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    run++;
    final view = ui.PlatformDispatcher.instance.views.first;
    final size = view.physicalSize / view.devicePixelRatio;
    final at = Offset(size.width / 2, size.height * 0.86);
    _log('run-$run tap-down');
    final p = PointerDeviceKind.touch;
    GestureBinding.instance.handlePointerEvent(
      PointerDownEvent(pointer: run, kind: p, position: at),
    );
    GestureBinding.instance.handlePointerEvent(
      PointerUpEvent(pointer: run, kind: p, position: at),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _log('toasts-visible ${DabblerToasts.controller?.visible.length}');
    await Future<void>.delayed(const Duration(seconds: 3));
    if (run < 3) {
      router.go('/start');
      unawaited(cycle());
    } else {
      _log('done');
    }
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(cycle()));
  runApp(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: DabblerDesignSystemTheme.withTokens(
          ThemeData(brightness: Brightness.light),
        ),
        builder: (context, child) => Listener(
          onPointerUp: (_) => _log('pointer-up'),
          child: DabblerToastProvider(child: child!),
        ),
      ),
    ),
  );
}

class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    _log('home-built');
    ref.listen<AsyncValue<ActiveLocationState>>(activeLocationProvider, (
      _,
      next,
    ) {
      _log('active-location ${next.valueOrNull.runtimeType}');
    });
    final s = ref.watch(activeLocationProvider).valueOrNull;
    return Scaffold(
      body: Center(
        child: Text(
          s is ActiveLocationReady ? 'HOME (area set)' : 'HOME (Set location)',
        ),
      ),
    );
  }
}
