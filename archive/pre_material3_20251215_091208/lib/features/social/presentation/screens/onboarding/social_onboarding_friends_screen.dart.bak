import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../../utils/constants/route_constants.dart';

/// Find friends screen for social onboarding
class SocialOnboardingFriendsScreen extends ConsumerStatefulWidget {
  const SocialOnboardingFriendsScreen({super.key});

  @override
  ConsumerState<SocialOnboardingFriendsScreen> createState() =>
      _SocialOnboardingFriendsScreenState();
}

class _SocialOnboardingFriendsScreenState
    extends ConsumerState<SocialOnboardingFriendsScreen> {
  bool _contactsPermissionGranted = false;
  bool _isLoadingContacts = false;
  List<_ContactSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadMockSuggestions();
  }

  void _loadMockSuggestions() {
    // Mock friend suggestions
    _suggestions = [
      _ContactSuggestion(
        name: 'John Smith',
        avatar: 'https://i.pravatar.cc/150?img=1',
        mutualFriends: 3,
        source: 'Contacts',
        isSelected: false,
      ),
      _ContactSuggestion(
        name: 'Emma Johnson',
        avatar: 'https://i.pravatar.cc/150?img=2',
        mutualFriends: 1,
        source: 'Nearby',
        isSelected: false,
      ),
      _ContactSuggestion(
        name: 'Mike Davis',
        avatar: 'https://i.pravatar.cc/150?img=3',
        mutualFriends: 2,
        source: 'Contacts',
        isSelected: false,
      ),
      _ContactSuggestion(
        name: 'Sarah Wilson',
        avatar: 'https://i.pravatar.cc/150?img=4',
        mutualFriends: 0,
        source: 'Suggested',
        isSelected: false,
      ),
      _ContactSuggestion(
        name: 'Alex Chen',
        avatar: 'https://i.pravatar.cc/150?img=5',
        mutualFriends: 4,
        source: 'Contacts',
        isSelected: false,
      ),
    ];
  }

  Future<void> _requestContactsPermission() async {
    setState(() {
      _isLoadingContacts = true;
    });

    try {
      // Simulate permission request - in real app would use permission_handler
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _contactsPermissionGranted = true;
      });

      // In a real app, you would load actual contacts here
      await Future.delayed(const Duration(seconds: 2));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contacts synced successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error accessing contacts. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingContacts = false;
      });
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      _suggestions[index].isSelected = !_suggestions[index].isSelected;
    });
  }

  void _sendFriendRequests() {
    final selectedFriends = _suggestions.where((s) => s.isSelected).toList();

    if (selectedFriends.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Friend requests sent to ${selectedFriends.length} people!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    // Continue to next step
    context.push(RoutePaths.socialOnboardingPrivacy);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _suggestions.where((s) => s.isSelected).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push(RoutePaths.socialOnboardingPrivacy),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description
            Text(
              'Find Your Sports Community',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with friends to share game experiences and discover new opportunities.',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // Sync contacts button
            if (!_contactsPermissionGranted) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingContacts
                      ? null
                      : _requestContactsPermission,
                  icon: _isLoadingContacts
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.userPlus),
                  label: Text(
                    _isLoadingContacts ? 'Syncing...' : 'Sync Contacts',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    foregroundColor: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('or', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Suggested friends section
            Row(
              children: [
                Text(
                  'Suggested for You',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (selectedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$selectedCount selected',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Friends list
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = _suggestions[index];
                  return _buildFriendSuggestionCard(suggestion, index);
                },
              ),
            ),

            // Bottom section
            const SizedBox(height: 16),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendFriendRequests,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  selectedCount > 0
                      ? 'Send ${selectedCount > 1 ? "$selectedCount Requests" : "Request"} & Continue'
                      : 'Continue',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Progress indicator
            _buildProgressIndicator(context, 1, 4),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendSuggestionCard(_ContactSuggestion suggestion, int index) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(suggestion.avatar),
        ),
        title: Text(
          suggestion.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (suggestion.mutualFriends > 0)
              Text(
                '${suggestion.mutualFriends} mutual friend${suggestion.mutualFriends > 1 ? 's' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getSourceColor(suggestion.source).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    suggestion.source,
                    style: TextStyle(
                      color: _getSourceColor(suggestion.source),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: SizedBox(
          width: 100,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suggestion.isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.check, size: 14, color: Colors.green),
                      SizedBox(width: 4),
                      Text(
                        'Added',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => _toggleSelection(index),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  child: const Text('Add'),
                ),
            ],
          ),
        ),
        onTap: () => _toggleSelection(index),
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source) {
      case 'Contacts':
        return Colors.blue;
      case 'Nearby':
        return Colors.green;
      case 'Suggested':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildProgressIndicator(
    BuildContext context,
    int currentStep,
    int totalSteps,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).primaryColor
                : Theme.of(context).primaryColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _ContactSuggestion {
  final String name;
  final String avatar;
  final int mutualFriends;
  final String source;
  bool isSelected;

  _ContactSuggestion({
    required this.name,
    required this.avatar,
    required this.mutualFriends,
    required this.source,
    required this.isSelected,
  });
}
