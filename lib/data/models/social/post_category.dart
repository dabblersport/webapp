/// Static post category definitions for the category picker.
///
/// Categories are stored as tags on the post. Each category has
/// an emoji icon and a display name.
class PostCategory {
  const PostCategory({required this.emoji, required this.name});
  final String emoji;
  final String name;
}

/// All available post categories shown in the category picker.
const kPostCategories = [
  PostCategory(emoji: '❤️', name: 'Relationships'),
  PostCategory(emoji: '👨‍👩‍👧‍👦', name: 'Family'),
  PostCategory(emoji: '💙', name: 'Habits'),
  PostCategory(emoji: '😎', name: 'Friends'),
  PostCategory(emoji: '🌺', name: 'Hopes'),
  PostCategory(emoji: '🙈', name: 'Bullying'),
  PostCategory(emoji: '💪', name: 'Health'),
  PostCategory(emoji: '👤', name: 'Work'),
  PostCategory(emoji: '🎵', name: 'Music'),
  PostCategory(emoji: '💡', name: 'Helpful Tips'),
  PostCategory(emoji: '👶', name: 'Parenting'),
  PostCategory(emoji: '🏫', name: 'Education'),
  PostCategory(emoji: '🙏', name: 'Religion'),
  PostCategory(emoji: '🏳️‍🌈', name: 'LGBTQ+'),
  PostCategory(emoji: '🤰', name: 'Pregnancy'),
  PostCategory(emoji: '👍', name: 'Positive'),
  PostCategory(emoji: '🧘', name: 'Wellbeing'),
  PostCategory(emoji: '🎬', name: 'My Story'),
  PostCategory(emoji: '✏️', name: 'Poetry'),
  PostCategory(emoji: '💬', name: 'Resilience'),
  PostCategory(emoji: '📋', name: 'Challenges'),
];
