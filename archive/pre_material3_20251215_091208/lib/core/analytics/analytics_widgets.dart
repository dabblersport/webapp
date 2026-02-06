import 'package:flutter/material.dart';
import 'package:dabbler/core/services/analytics/analytics_service.dart';

/// Widget that tracks user interactions and scrolling behavior
class AnalyticsTrackingWidget extends StatefulWidget {
  final Widget child;
  final String screenName;
  final Map<String, dynamic>? initialContext;
  final bool trackScrolling;
  final bool trackTaps;
  final bool trackTimeSpent;

  const AnalyticsTrackingWidget({
    super.key,
    required this.child,
    required this.screenName,
    this.initialContext,
    this.trackScrolling = false,
    this.trackTaps = false,
    this.trackTimeSpent = true,
  });

  @override
  State<AnalyticsTrackingWidget> createState() =>
      _AnalyticsTrackingWidgetState();
}

class _AnalyticsTrackingWidgetState extends State<AnalyticsTrackingWidget> {
  final AnalyticsService _analytics = AnalyticsService();
  DateTime? _startTime;
  ScrollController? _scrollController;
  double _maxScrollPosition = 0.0;
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    if (widget.trackScrolling) {
      _scrollController = ScrollController();
      _scrollController!.addListener(_onScroll);
    }

    // Track screen entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analytics.trackScreenView(
        screenName: widget.screenName,
        properties: widget.initialContext,
      );
    });
  }

  void _onScroll() {
    final position = _scrollController?.position.pixels ?? 0.0;
    if (position > _maxScrollPosition) {
      _maxScrollPosition = position;

      // Track significant scroll milestones
      final percentage =
          (position / (_scrollController?.position.maxScrollExtent ?? 1)) * 100;
      if (percentage > 0 && percentage % 25 == 0) {
        _analytics.trackFeatureUsed(
          featureName: 'scroll_milestone',
          context: {
            'screen': widget.screenName,
            'percentage': percentage.round(),
            'position': position,
          },
        );
      }
    }
  }

  void _onTap() {
    if (widget.trackTaps) {
      _tapCount++;
      _analytics.trackFeatureUsed(
        featureName: 'screen_tap',
        context: {'screen': widget.screenName, 'tap_count': _tapCount},
      );
    }
  }

  @override
  void dispose() {
    // Track time spent on screen
    if (widget.trackTimeSpent && _startTime != null) {
      final timeSpent = DateTime.now().difference(_startTime!);
      _analytics.trackGameEngagement(
        gameId: 'screen_${widget.screenName}',
        sportType: 'screen_time',
        action: 'time_spent',
        metadata: {'seconds': timeSpent.inSeconds},
      );
    }

    // Track scroll engagement
    if (widget.trackScrolling && _maxScrollPosition > 0) {
      _analytics.trackFeatureUsed(
        featureName: 'scroll_engagement',
        context: {
          'screen': widget.screenName,
          'max_scroll_position': _maxScrollPosition,
          'total_taps': _tapCount,
        },
      );
    }

    _scrollController?.removeListener(_onScroll);
    _scrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    if (widget.trackTaps) {
      child = GestureDetector(onTap: _onTap, child: child);
    }

    if (widget.trackScrolling && _scrollController != null) {
      child = NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            _onScroll();
          }
          return false;
        },
        child: child,
      );
    }

    return child;
  }
}

/// Button that automatically tracks interactions
class AnalyticsButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String actionName;
  final String? category;
  final Map<String, dynamic>? context;

  const AnalyticsButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.actionName,
    this.category,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed == null
          ? null
          : () {
              // Track button press
              AnalyticsService().trackFeatureUsed(
                featureName: actionName,
                context: {
                  'category': category ?? 'button',
                  'timestamp': DateTime.now().toIso8601String(),
                  ...?this.context,
                },
              );

              onPressed!();
            },
      child: child,
    );
  }
}

/// Form field that tracks input behavior
class AnalyticsTextFormField extends StatefulWidget {
  final String fieldName;
  final String? labelText;
  final String? hintText;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool trackTypingBehavior;

  const AnalyticsTextFormField({
    super.key,
    required this.fieldName,
    this.labelText,
    this.hintText,
    this.controller,
    this.validator,
    this.onChanged,
    this.trackTypingBehavior = false,
  });

  @override
  State<AnalyticsTextFormField> createState() => _AnalyticsTextFormFieldState();
}

class _AnalyticsTextFormFieldState extends State<AnalyticsTextFormField> {
  final AnalyticsService _analytics = AnalyticsService();
  DateTime? _focusTime;
  int _characterCount = 0;
  int _backspaceCount = 0;

  void _onFocusChange(bool hasFocus) {
    if (hasFocus) {
      _focusTime = DateTime.now();
      _analytics.trackFeatureUsed(
        featureName: 'form_field_focused',
        context: {'field_name': widget.fieldName},
      );
    } else if (_focusTime != null) {
      final focusDuration = DateTime.now().difference(_focusTime!);
      _analytics.trackFeatureUsed(
        featureName: 'form_field_unfocused',
        context: {
          'field_name': widget.fieldName,
          'focus_duration_seconds': focusDuration.inSeconds,
          'character_count': _characterCount,
          'backspace_count': _backspaceCount,
        },
      );
    }
  }

  void _onTextChanged(String value) {
    if (widget.trackTypingBehavior) {
      if (value.length > _characterCount) {
        _characterCount = value.length;
      } else if (value.length < _characterCount) {
        _backspaceCount++;
        _characterCount = value.length;
      }
    }

    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _onFocusChange,
      child: TextFormField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
        validator: (value) {
          final error = widget.validator?.call(value);
          if (error != null) {
            _analytics.trackError(
              errorType: 'form_validation_error',
              errorMessage: error,
              context: {'screen': 'form_field_${widget.fieldName}'},
            );
          }
          return error;
        },
        onChanged: _onTextChanged,
      ),
    );
  }
}

/// List tile that tracks selection behavior
class AnalyticsListTile extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String itemId;
  final String? category;
  final int? position;
  final Map<String, dynamic>? context;

  const AnalyticsListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    required this.itemId,
    this.category,
    this.position,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: title,
      subtitle: subtitle,
      leading: leading,
      trailing: trailing,
      onTap: onTap == null
          ? null
          : () {
              // Track list item selection
              AnalyticsService().trackFeatureUsed(
                featureName: 'list_item_selected',
                context: {
                  'item_id': itemId,
                  'category': category ?? 'list',
                  'position': position,
                  'timestamp': DateTime.now().toIso8601String(),
                  ...?this.context,
                },
              );

              onTap!();
            },
    );
  }
}

/// Card that tracks view and interaction events
class AnalyticsCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String cardId;
  final String? category;
  final Map<String, dynamic>? context;
  final bool trackViewTime;

  const AnalyticsCard({
    super.key,
    required this.child,
    this.onTap,
    required this.cardId,
    this.category,
    this.context,
    this.trackViewTime = false,
  });

  @override
  State<AnalyticsCard> createState() => _AnalyticsCardState();
}

class _AnalyticsCardState extends State<AnalyticsCard> {
  final AnalyticsService _analytics = AnalyticsService();
  DateTime? _viewStartTime;
  bool _hasTrackedView = false;

  void _trackCardView() {
    if (!_hasTrackedView) {
      _hasTrackedView = true;
      _viewStartTime = DateTime.now();

      _analytics.trackFeatureUsed(
        featureName: 'card_viewed',
        context: {
          'card_id': widget.cardId,
          'category': widget.category ?? 'card',
          ...?widget.context,
        },
      );
    }
  }

  void _trackCardTap() {
    final viewTime = _viewStartTime != null
        ? DateTime.now().difference(_viewStartTime!)
        : null;

    _analytics.trackFeatureUsed(
      featureName: 'card_tapped',
      context: {
        'card_id': widget.cardId,
        'category': widget.category ?? 'card',
        'view_time_seconds': viewTime?.inSeconds,
        ...?widget.context,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('analytics_card_${widget.cardId}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          _trackCardView();
        }
      },
      child: Card(
        child: InkWell(
          onTap: widget.onTap == null
              ? null
              : () {
                  _trackCardTap();
                  widget.onTap!();
                },
          child: widget.child,
        ),
      ),
    );
  }
}

// Note: VisibilityDetector would need to be implemented or imported
// For now, we'll use a simpler approach with gesture detection
class VisibilityDetector extends StatefulWidget {
  final Widget child;
  final Function(VisibilityInfo) onVisibilityChanged;

  const VisibilityDetector({
    required this.child,
    required this.onVisibilityChanged,
    super.key,
  });

  @override
  State<VisibilityDetector> createState() => _VisibilityDetectorState();
}

class _VisibilityDetectorState extends State<VisibilityDetector> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Simulate visibility detection
      widget.onVisibilityChanged(VisibilityInfo(visibleFraction: 1.0));
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class VisibilityInfo {
  final double visibleFraction;

  VisibilityInfo({required this.visibleFraction});
}

/// Error boundary that tracks errors
class AnalyticsErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? context;

  const AnalyticsErrorBoundary({super.key, required this.child, this.context});

  @override
  State<AnalyticsErrorBoundary> createState() => _AnalyticsErrorBoundaryState();
}

class _AnalyticsErrorBoundaryState extends State<AnalyticsErrorBoundary> {
  final AnalyticsService _analytics = AnalyticsService();
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(child: Text('Something went wrong'));
    }

    return ErrorBoundaryWrapper(
      onError: (error, stackTrace) {
        setState(() {
          _hasError = true;
        });

        _analytics.trackError(
          errorType: 'widget_error',
          errorMessage: error.toString(),
          stackTrace: stackTrace.toString(),
          context: {'screen': widget.context},
        );
      },
      child: widget.child,
    );
  }
}

// Simple error boundary wrapper
class ErrorBoundaryWrapper extends StatefulWidget {
  final Widget child;
  final Function(Object error, StackTrace stackTrace) onError;

  const ErrorBoundaryWrapper({
    super.key,
    required this.child,
    required this.onError,
  });

  @override
  State<ErrorBoundaryWrapper> createState() => _ErrorBoundaryWrapperState();
}

class _ErrorBoundaryWrapperState extends State<ErrorBoundaryWrapper> {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
