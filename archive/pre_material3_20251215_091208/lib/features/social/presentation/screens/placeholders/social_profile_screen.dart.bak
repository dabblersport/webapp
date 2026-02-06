import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Social profile screen showing user's social information and posts
class SocialProfileScreen extends StatelessWidget {
  final String userId;

  const SocialProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(icon: const Icon(LucideIcons.share), onPressed: () {}),
          IconButton(
            icon: const Icon(LucideIcons.moreHorizontal),
            onPressed: () {},
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(
                      LucideIcons.user,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // User Info
                  Text(
                    'User $userId',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '@user$userId',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Basketball enthusiast 🏀 | Coffee lover ☕ | Always up for a game!',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatColumn(title: 'Posts', value: '42'),
                      _StatColumn(title: 'Friends', value: '156'),
                      _StatColumn(title: 'Games', value: '23'),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(LucideIcons.userPlus),
                          label: const Text('Add Friend'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(LucideIcons.messageCircle),
                          label: const Text('Message'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Tab Bar
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
                ),
              ),
              child: TabBar(
                controller: DefaultTabController.of(context),
                tabs: const [
                  Tab(text: 'Posts'),
                  Tab(text: 'Games'),
                  Tab(text: 'Photos'),
                ],
              ),
            ),
          ),

          // Posts List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Post Header
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            child: Icon(LucideIcons.user, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User $userId',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${index + 1} days ago',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Post Content
                      Text(
                        'This is post ${index + 1} from this user. Great game today! Looking forward to the next one.',
                      ),
                      const SizedBox(height: 12),

                      // Post Actions
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.heart, size: 20),
                            onPressed: () {},
                          ),
                          Text('${12 + index}'),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(
                              LucideIcons.messageCircle,
                              size: 20,
                            ),
                            onPressed: () {},
                          ),
                          Text('${3 + index}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              childCount: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String title;
  final String value;

  const _StatColumn({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}
