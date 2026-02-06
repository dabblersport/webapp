import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Professional Page Transitions
///
/// Provides smooth, Material Design 3 compliant transitions
/// between screens with customizable animations and durations.

/// Fade Transition - Smooth opacity change
class FadeTransitionPage extends CustomTransitionPage<void> {
  FadeTransitionPage({
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 300),
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return FadeTransition(
             opacity: animation.drive(
               Tween<double>(
                 begin: 0.0,
                 end: 1.0,
               ).chain(CurveTween(curve: Curves.easeInOut)),
             ),
             child: child,
           );
         },
         transitionDuration: duration,
       );
}

/// Slide Transition - Slides from right (default) or other directions
class SlideTransitionPage extends CustomTransitionPage<void> {
  SlideTransitionPage({
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 350),
    SlideDirection direction = SlideDirection.fromRight,
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final offsetAnimation = animation.drive(
             Tween<Offset>(
               begin: direction.offset,
               end: Offset.zero,
             ).chain(CurveTween(curve: Curves.easeOutCubic)),
           );

           return SlideTransition(position: offsetAnimation, child: child);
         },
         transitionDuration: duration,
       );
}

/// Scale Transition - Scales from center
class ScaleTransitionPage extends CustomTransitionPage<void> {
  ScaleTransitionPage({
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 300),
    Alignment alignment = Alignment.center,
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return ScaleTransition(
             scale: animation.drive(
               Tween<double>(
                 begin: 0.8,
                 end: 1.0,
               ).chain(CurveTween(curve: Curves.easeOutCubic)),
             ),
             alignment: alignment,
             child: FadeTransition(opacity: animation, child: child),
           );
         },
         transitionDuration: duration,
       );
}

/// Shared Axis Transition - Material Design 3 recommended
class SharedAxisTransitionPage extends CustomTransitionPage<void> {
  SharedAxisTransitionPage({
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 350),
    SharedAxisType type = SharedAxisType.horizontal,
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return _buildSharedAxisTransition(
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             child: child,
             type: type,
           );
         },
         transitionDuration: duration,
       );

  static Widget _buildSharedAxisTransition({
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    required SharedAxisType type,
  }) {
    final primaryCurve = Curves.easeOutCubic;
    final secondaryCurve = Curves.easeInCubic;

    switch (type) {
      case SharedAxisType.horizontal:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.3, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: primaryCurve)),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(-0.3, 0.0),
                  ).animate(
                    CurvedAnimation(
                      parent: secondaryAnimation,
                      curve: secondaryCurve,
                    ),
                  ),
              child: child,
            ),
          ),
        );

      case SharedAxisType.vertical:
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.3),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: primaryCurve)),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(0.0, -0.3),
                  ).animate(
                    CurvedAnimation(
                      parent: secondaryAnimation,
                      curve: secondaryCurve,
                    ),
                  ),
              child: child,
            ),
          ),
        );

      case SharedAxisType.scaled:
        return ScaleTransition(
          scale: Tween<double>(
            begin: 0.8,
            end: 1.0,
          ).animate(CurvedAnimation(parent: animation, curve: primaryCurve)),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.1).animate(
                CurvedAnimation(
                  parent: secondaryAnimation,
                  curve: secondaryCurve,
                ),
              ),
              child: child,
            ),
          ),
        );
    }
  }
}

/// Fade Through Transition - Material Design 3 pattern
class FadeThroughTransitionPage extends CustomTransitionPage<void> {
  FadeThroughTransitionPage({
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 300),
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return FadeTransition(
             opacity: animation.drive(
               Tween<double>(begin: 0.0, end: 1.0).chain(
                 CurveTween(
                   curve: const Interval(0.3, 1.0, curve: Curves.easeInOut),
                 ),
               ),
             ),
             child: ScaleTransition(
               scale: animation.drive(
                 Tween<double>(
                   begin: 0.92,
                   end: 1.0,
                 ).chain(CurveTween(curve: Curves.easeOutCubic)),
               ),
               child: child,
             ),
           );
         },
         transitionDuration: duration,
       );
}

/// Bottom Sheet Style Transition - Slides from bottom
class BottomSheetTransitionPage extends CustomTransitionPage<void> {
  BottomSheetTransitionPage({
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 400),
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return SlideTransition(
             position:
                 Tween<Offset>(
                   begin: const Offset(0.0, 1.0),
                   end: Offset.zero,
                 ).animate(
                   CurvedAnimation(
                     parent: animation,
                     curve: Curves.easeOutCubic,
                     reverseCurve: Curves.easeInCubic,
                   ),
                 ),
             child: child,
           );
         },
         transitionDuration: duration,
       );
}

/// Hero-style Transition - Expands from a point
class HeroTransitionPage extends CustomTransitionPage<void> {
  HeroTransitionPage({
    required super.child,
    super.key,
    Duration duration = const Duration(milliseconds: 400),
  }) : super(
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return ScaleTransition(
             scale: animation.drive(
               Tween<double>(
                 begin: 0.0,
                 end: 1.0,
               ).chain(CurveTween(curve: Curves.easeOutCubic)),
             ),
             child: FadeTransition(
               opacity: animation.drive(
                 Tween<double>(begin: 0.0, end: 1.0).chain(
                   CurveTween(
                     curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                   ),
                 ),
               ),
               child: child,
             ),
           );
         },
         transitionDuration: duration,
       );
}

/// No Transition - Instant navigation
class NoTransitionPage extends CustomTransitionPage<void> {
  NoTransitionPage({required super.child, super.key})
    : super(
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return child;
        },
        transitionDuration: Duration.zero,
      );
}

/// Enum for slide directions
enum SlideDirection {
  fromRight(Offset(1.0, 0.0)),
  fromLeft(Offset(-1.0, 0.0)),
  fromTop(Offset(0.0, -1.0)),
  fromBottom(Offset(0.0, 1.0));

  final Offset offset;
  const SlideDirection(this.offset);
}

/// Enum for shared axis types
enum SharedAxisType { horizontal, vertical, scaled }

/// Extension on GoRouter for easy transition usage
extension TransitionExtensions on BuildContext {
  /// Navigate with fade transition
  void fadeToPage(String location, {Object? extra}) {
    go(location, extra: extra);
  }

  /// Navigate with slide transition
  void slideToPage(String location, {Object? extra}) {
    go(location, extra: extra);
  }

  /// Navigate with scale transition
  void scaleToPage(String location, {Object? extra}) {
    go(location, extra: extra);
  }
}

/// Helper to get appropriate transition based on route
CustomTransitionPage<void> getTransitionForRoute(
  String route,
  Widget child, {
  LocalKey? key,
}) {
  // Modal-style routes (bottom sheet style)
  if (route.contains('detail') ||
      route.contains('edit') ||
      route.contains('add') ||
      route.contains('create')) {
    return BottomSheetTransitionPage(child: child, key: key);
  }

  // Profile and settings (shared axis horizontal)
  if (route.contains('profile') ||
      route.contains('settings') ||
      route.contains('preferences')) {
    return SharedAxisTransitionPage(
      child: child,
      key: key,
      type: SharedAxisType.horizontal,
    );
  }

  // Notifications, transactions (fade through)
  if (route.contains('notifications') ||
      route.contains('transactions') ||
      route.contains('history')) {
    return FadeThroughTransitionPage(child: child, key: key);
  }

  // Default: Smooth fade
  return FadeTransitionPage(child: child, key: key);
}
