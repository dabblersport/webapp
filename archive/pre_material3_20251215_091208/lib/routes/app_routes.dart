import 'package:flutter/material.dart';

import '../routes/route_arguments.dart';
import 'package:dabbler/features/misc/presentation/screens/activities_screen_v2.dart';
import 'package:dabbler/features/misc/presentation/screens/create_game_screen.dart';
import 'package:dabbler/features/home/presentation/screens/home_screen.dart';

class AppRoutes {
  AppRoutes._();

  // Primary entry points still backed by Navigator routes.
  static const String home = '/';
  static const String bookings = '/bookings';
  static const String gameCreate = '/gameCreate';

  // Onboarding routes (aliases for RoutePaths)
  static const String onboardingWelcome = '/onboarding-welcome';
  static const String onboardingSports = '/onboarding-sports';

  /// Static routes that don't require arguments.
  static Map<String, WidgetBuilder> get routes => {
    home: (_) => const HomeScreen(),
    bookings: (_) => const ActivitiesScreenV2(),
  };

  /// Route factory used by legacy Navigator.pushNamed flows.
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case bookings:
        return MaterialPageRoute(builder: (_) => const ActivitiesScreenV2());
      case gameCreate:
        final args = settings.arguments;
        Map<String, dynamic>? initialData;
        if (args is CreateGameRouteArgs) {
          // Convert CreateGameRouteArgs to Map for CreateGameScreen
          initialData = {
            if (args.draftId != null) 'draftId': args.draftId,
            if (args.fromBooking != null)
              'fromBooking': {
                'bookingId': args.fromBooking!.bookingId,
                if (args.fromBooking!.venueId != null)
                  'venueId': args.fromBooking!.venueId,
                'venueName': args.fromBooking!.venueName,
                if (args.fromBooking!.venueLocation != null)
                  'venueLocation': args.fromBooking!.venueLocation,
                'date': args.fromBooking!.date.toIso8601String(),
                'timeLabel': args.fromBooking!.timeLabel,
                'sport': args.fromBooking!.sport,
              },
          };
        }
        return MaterialPageRoute(
          builder: (_) => CreateGameScreen(initialData: initialData),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
    }
  }

  static void goHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(home, (route) => false);
  }

  static void goToBookings(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(bookings, (route) => false);
  }

  static void openCreateGame(
    BuildContext context, {
    CreateGameRouteArgs? args,
    bool clearStack = false,
  }) {
    final resolvedArgs = args ?? const CreateGameRouteArgs();
    if (clearStack) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        gameCreate,
        (route) => false,
        arguments: resolvedArgs,
      );
    } else {
      Navigator.of(context).pushNamed(gameCreate, arguments: resolvedArgs);
    }
  }
}
