import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Messages screen showing list of conversations
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.search), onPressed: () {}),
          IconButton(icon: const Icon(LucideIcons.edit), onPressed: () {}),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Active Now Section
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Active Now',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 8,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.grey[200],
                                child: Icon(
                                  LucideIcons.user,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'User ${index + 1}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(),
              ],
            ),
          ),

          // Conversations List
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final isUnread = index < 3;
              final hasTyping = index == 1;

              return ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.grey[200],
                      child: Icon(LucideIcons.user, color: Colors.grey[600]),
                    ),
                    if (index < 5)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: index < 3 ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chat Partner ${index + 1}',
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      index == 0 ? 'now' : '${index + 1}h',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isUnread
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                        fontWeight: isUnread
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hasTyping
                            ? 'Typing...'
                            : index == 0
                            ? 'Perfect! See you there 🏀'
                            : 'Hey! Ready for the game tonight?',
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: hasTyping
                              ? Theme.of(context).primaryColor
                              : isUnread
                              ? Colors.black87
                              : Colors.grey[600],
                          fontStyle: hasTyping
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUnread && !hasTyping)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/social/chat/conversation_${index + 1}',
                  );
                },
              );
            }, childCount: 15),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: Icon(Icons.message),
      ),
    );
  }
}
