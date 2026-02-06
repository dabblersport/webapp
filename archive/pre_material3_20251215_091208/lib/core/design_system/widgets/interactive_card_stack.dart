import 'package:flutter/material.dart';
import 'package:dabbler/core/design_system/widgets/upcoming_game_card.dart';

/// Interactive card stack that allows expanding/collapsing cards with drag gestures
/// Only one card can be expanded at a time
class InteractiveCardStack extends StatefulWidget {
  final List<StackCardData> cards;
  final double expandedCardHeight;
  final double collapsedCardHeight;
  final double spacing;

  const InteractiveCardStack({
    super.key,
    required this.cards,
    this.expandedCardHeight = 180.0,
    this.collapsedCardHeight = 52.0,
    this.spacing = 12.0,
  });

  @override
  State<InteractiveCardStack> createState() => _InteractiveCardStackState();
}

class _InteractiveCardStackState extends State<InteractiveCardStack>
    with TickerProviderStateMixin {
  int _expandedIndex = 0;
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _controllers = List.generate(
      widget.cards.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return CurvedAnimation(parent: controller, curve: Curves.easeInOut);
    }).toList();

    // Set initial state - first card expanded
    _controllers[0].value = 1.0;
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _expandCard(int index) {
    if (_expandedIndex == index) return;

    setState(() {
      // Collapse current expanded card
      _controllers[_expandedIndex].reverse();
      // Expand new card
      _controllers[index].forward();
      _expandedIndex = index;
    });
  }

  double _getCardTop(int index) {
    double top = 0;
    for (int i = 0; i < index; i++) {
      if (i == _expandedIndex) {
        top += widget.expandedCardHeight + widget.spacing;
      } else {
        top += widget.collapsedCardHeight + widget.spacing;
      }
    }
    return top;
  }

  double _getTotalHeight() {
    double height = 0;
    for (int i = 0; i < widget.cards.length; i++) {
      if (i == _expandedIndex) {
        height += widget.expandedCardHeight;
      } else {
        height += widget.collapsedCardHeight;
      }
      if (i < widget.cards.length - 1) {
        height += widget.spacing;
      }
    }
    return height;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _getTotalHeight(),
      child: Stack(
        children: List.generate(widget.cards.length, (index) {
          return AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              final isExpanded = index == _expandedIndex;
              final height =
                  widget.collapsedCardHeight +
                  (widget.expandedCardHeight - widget.collapsedCardHeight) *
                      _animations[index].value;

              return Positioned(
                top: _getCardTop(index),
                left: 0,
                right: 0,
                height: height,
                child: GestureDetector(
                  onTap: () => _expandCard(index),
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: widget.expandedCardHeight,
                        child: _buildCard(index, isExpanded),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildCard(int index, bool isExpanded) {
    final card = widget.cards[index];
    final borderRadius = _getBorderRadius(index);

    if (isExpanded) {
      return UpcomingGameCard.expanded(
        title: card.title,
        sportIcon: card.sportIcon,
        gameName: card.gameName,
        timeRemaining: card.timeRemaining,
        dateTime: card.dateTime ?? '',
        location: card.location ?? '',
        borderRadiusVariant: borderRadius,
      );
    } else {
      return UpcomingGameCard.collapsed(
        title: card.title,
        sportIcon: card.sportIcon,
        gameName: card.gameName,
        timeRemaining: card.timeRemaining,
        borderRadiusVariant: borderRadius,
      );
    }
  }

  BorderRadiusVariant _getBorderRadius(int index) {
    if (index == 0) {
      // First card - only bottom corners rounded
      return BorderRadiusVariant.bottomOnly;
    } else if (index == widget.cards.length - 1) {
      // Last card - all corners rounded
      return BorderRadiusVariant.all;
    } else {
      // Middle cards - all corners rounded
      return BorderRadiusVariant.all;
    }
  }
}

/// Data class for stack cards
class StackCardData {
  final String title;
  final Widget sportIcon;
  final String gameName;
  final String timeRemaining;
  final String? dateTime;
  final String? location;

  const StackCardData({
    required this.title,
    required this.sportIcon,
    required this.gameName,
    required this.timeRemaining,
    this.dateTime,
    this.location,
  });
}
