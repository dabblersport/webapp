import 'package:flutter/material.dart';

import 'package:dabbler/data/models/profile/user_profile.dart';

class ProfileBasicsCard extends StatelessWidget {
  const ProfileBasicsCard({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  final UserProfile? profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Contact & basics',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (profile != null && (profile!.email?.isNotEmpty ?? false))
              _InfoRow(icon: Icons.email_outlined, text: profile!.email ?? ''),
            if (profile?.phoneNumber?.isNotEmpty == true)
              _InfoRow(icon: Icons.phone_outlined, text: profile!.phoneNumber!),
            if (profile?.city?.isNotEmpty == true ||
                profile?.country?.isNotEmpty == true)
              _InfoRow(
                icon: Icons.location_city_outlined,
                text: _formatLocation(profile!.city, profile!.country),
              ),
            if (profile?.age != null)
              _InfoRow(
                icon: Icons.cake_outlined,
                text: '${profile!.age!} years old',
              ),
            if (profile?.gender?.isNotEmpty == true)
              _InfoRow(icon: Icons.person_outline, text: profile!.gender!),
            if (profile?.language?.isNotEmpty == true)
              _InfoRow(icon: Icons.language_outlined, text: profile!.language!),
            if (profile?.preferredSport?.isNotEmpty == true)
              _InfoRow(
                icon: Icons.sports_soccer,
                text: profile!.preferredSport!,
              ),
            if (profile?.intention?.isNotEmpty == true)
              _InfoRow(icon: Icons.flag_outlined, text: profile!.intention!),
            if (_isEmpty(profile))
              _EmptyState(message: 'Add your basic information'),
          ],
        ),
      ),
    );
  }

  bool _isEmpty(UserProfile? profile) {
    if (profile == null) return true;

    return (profile.email?.isEmpty ?? true) &&
        profile.phoneNumber == null &&
        (profile.city == null || profile.city!.isEmpty) &&
        (profile.country == null || profile.country!.isEmpty) &&
        profile.age == null &&
        (profile.gender == null || profile.gender!.isEmpty) &&
        (profile.language == null || profile.language!.isEmpty) &&
        (profile.preferredSport == null || profile.preferredSport!.isEmpty) &&
        (profile.intention == null || profile.intention!.isEmpty);
  }

  String _formatLocation(String? city, String? country) {
    final cityStr = city?.trim();
    final countryStr = country?.trim();

    if (cityStr != null &&
        cityStr.isNotEmpty &&
        countryStr != null &&
        countryStr.isNotEmpty) {
      return '$cityStr, $countryStr';
    } else if (cityStr != null && cityStr.isNotEmpty) {
      return cityStr;
    } else if (countryStr != null && countryStr.isNotEmpty) {
      return countryStr;
    }
    return '';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
