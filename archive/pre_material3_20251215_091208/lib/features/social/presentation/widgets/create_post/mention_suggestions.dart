import 'package:flutter/material.dart';
import 'package:dabbler/data/models/authentication/user_model.dart';

class MentionSuggestions extends StatelessWidget {
  final List<UserModel> suggestions;
  final Function(UserModel) onMentionSelected;

  const MentionSuggestions({
    super.key,
    required this.suggestions,
    required this.onMentionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final user = suggestions[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(
                (user.username?.isNotEmpty == true) ? user.username![0] : '?',
              ),
            ),
            title: Text('${user.username ?? ''} ${user.displayName}'),
            subtitle: Text(
              '@${user.username?.toLowerCase() ?? ''}${user.displayName.toLowerCase()}',
            ),
            onTap: () => onMentionSelected(user),
          );
        },
      ),
    );
  }
}
