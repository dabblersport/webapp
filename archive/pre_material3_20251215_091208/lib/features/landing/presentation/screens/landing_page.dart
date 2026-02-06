import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/core/design_system/design_system.dart';

/// Landing page shown before login/signup
/// Features a user testimonial and value proposition
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withOpacity(0.95),
                ],
              ),
            ),
          ),

          // Decorative Frame overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: SvgPicture.asset(
                'assets/elements/Frame.svg',
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.white.withOpacity(0.1),
                  BlendMode.softLight,
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // User testimonial card
                          _buildUserCard(),

                          const SizedBox(height: 48),

                          // User quote

                          // Main headline
                          Text(
                            'I promised myself I\'d play at least twice a week but, between work and life finding a game feels harder than a 90-minute run.',
                            style: AppTypography.displayLarge.copyWith(
                              color: Colors.white,
                            ),
                          ),

                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),

                  // Value proposition - fixed before button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    child: Text(
                      'Dabbler connects players, captains, and venues so you can stop searching and start playing',
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  // Continue button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 60),
                    child: FilledButton(
                      onPressed: () => context.go(RoutePaths.phoneInput),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: colorScheme.primary,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 60, 0, 0),
      decoration: BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with image
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: const DecorationImage(
                image: AssetImage('assets/elements/Avatar.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 18),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge with emoji
                AppLabel(
                  text: 'Determined',
                  size: AppLabelSize.defaultSize,
                  leftIcon: const Text('💪', style: TextStyle(fontSize: 15)),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF7327CE),
                ),
                const SizedBox(height: 12),

                // Name
                Text(
                  'Noor',
                  style: AppTypography.headlineSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
