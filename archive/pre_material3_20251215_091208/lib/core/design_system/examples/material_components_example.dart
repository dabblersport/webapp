import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart'; // Import color extensions

/// Example screen demonstrating native Material 3 components with custom color tokens
class MaterialComponentsExample extends StatelessWidget {
  const MaterialComponentsExample({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Material 3 Components'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section: Buttons
          Text('Buttons', style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Filled Button (Primary)
              FilledButton(onPressed: () {}, child: const Text('Filled')),
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('With Icon'),
              ),

              // Outlined Button
              OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.edit),
                label: const Text('Edit'),
              ),

              // Text Button (Ghost)
              TextButton(onPressed: () {}, child: const Text('Text')),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),

              // Elevated Button
              ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Section: Cards
          Text('Cards', style: textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Filled Card
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filled Card', style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'This is a filled card with surface container color',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Outlined Card
          Card.outlined(
            child: ListTile(
              leading: Icon(Icons.info, color: colorScheme.primary),
              title: const Text('Outlined Card'),
              subtitle: const Text('With border and no fill'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {},
            ),
          ),

          const SizedBox(height: 12),

          // Card with custom color (using category token)
          Card.filled(
            color: colorScheme.categorySocial.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.people, color: colorScheme.categorySocial),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Social Card',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.categorySocial,
                          ),
                        ),
                        Text(
                          'Using custom category colors',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Section: Input Fields
          Text('Input Fields', style: textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Standard TextField
          const TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email),
            ),
          ),

          const SizedBox(height: 16),

          // TextField with error
          TextField(
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () {},
              ),
              errorText: 'Password is required',
            ),
          ),

          const SizedBox(height: 16),

          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Section: Chips
          Text('Chips', style: textTheme.headlineSmall),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Filter Chips
              FilterChip(
                label: const Text('Filter 1'),
                selected: true,
                onSelected: (value) {},
              ),
              FilterChip(
                label: const Text('Filter 2'),
                selected: false,
                onSelected: (value) {},
              ),

              // Action Chips
              ActionChip(
                label: const Text('Action'),
                onPressed: () {},
                avatar: const Icon(Icons.add, size: 18),
              ),

              // Input Chips
              InputChip(label: const Text('Tag'), onDeleted: () {}),

              // Custom color chip (Sports)
              FilterChip(
                label: const Text('Sports'),
                selected: true,
                backgroundColor: colorScheme.categorySports.withOpacity(0.1),
                selectedColor: colorScheme.categorySports.withOpacity(0.2),
                checkmarkColor: colorScheme.categorySports,
                labelStyle: TextStyle(color: colorScheme.categorySports),
                onSelected: (value) {},
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Section: Category Colors Demo
          Text('Category Colors', style: textTheme.headlineSmall),
          const SizedBox(height: 16),

          _CategoryColorCard(
            title: 'Main',
            color: colorScheme.primary,
            lightColor: colorScheme.primaryContainer,
          ),
          const SizedBox(height: 12),
          _CategoryColorCard(
            title: 'Social',
            color: colorScheme.secondary,
            lightColor: colorScheme.secondaryContainer,
          ),
          const SizedBox(height: 12),
          _CategoryColorCard(
            title: 'Sports',
            color: colorScheme.tertiary,
            lightColor: colorScheme.tertiaryContainer,
          ),
          const SizedBox(height: 12),
          _CategoryColorCard(
            title: 'Activities',
            color: colorScheme.primary,
            lightColor: colorScheme.primaryContainer,
          ),
          const SizedBox(height: 12),
          _CategoryColorCard(
            title: 'Profile',
            color: colorScheme.secondary,
            lightColor: colorScheme.secondaryContainer,
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Section: Semantic Colors
          Text('Semantic Colors', style: textTheme.headlineSmall),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Card.filled(
                  color: colorScheme.tertiary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, color: colorScheme.tertiary),
                        const SizedBox(height: 8),
                        Text(
                          'Success',
                          style: TextStyle(color: colorScheme.tertiary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card.filled(
                  color: colorScheme.error.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.warning, color: colorScheme.error),
                        const SizedBox(height: 8),
                        Text(
                          'Warning',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card.filled(
                  color: colorScheme.error.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.error, color: colorScheme.error),
                        const SizedBox(height: 8),
                        Text(
                          'Error',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryColorCard extends StatelessWidget {
  final String title;
  final Color color;
  final Color lightColor;

  const _CategoryColorCard({
    required this.title,
    required this.color,
    required this.lightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      color: lightColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Main: ${_colorToHex(color)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Light: ${_colorToHex(lightColor)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }
}
