/// The sample copy of `Home Feed.dc.html`, in the design's own two languages.
///
/// The English strings are the file's `RECENT`/`NEWS`/`UPCOMING` data. The
/// Arabic strings are the Arabic frame's own dictionary in the same file
/// (`Home Feed.dc.html`, the `'Create post': 'منشور جديد'` block) — copied
/// from the design, never written here.
library;

class FrameData {
  const FrameData({
    required this.location,
    required this.gameTitle,
    required this.venue,
    required this.name,
    required this.place,
    required this.body,
    required this.cricket,
    required this.football,
    required this.newsTitle,
    required this.newsExcerpt,
    required this.newsTitleKey,
    required this.newsExcerptKey,
    required this.region,
  });

  final String location;
  final String gameTitle;
  final String venue;
  final String name;
  final String place;
  final String body;
  final String cricket;
  final String football;
  final String newsTitle;
  final String newsExcerpt;

  /// A short prefix of [newsTitle] / [newsExcerpt] to find them by.
  final String newsTitleKey;
  final String newsExcerptKey;
  final String region;

  static const FrameData en = FrameData(
    location: 'Sheikha Fatima Bint Mubarak Street',
    gameTitle: 'Tuesday 5-a-side',
    venue: 'Dubai Sports City',
    name: 'Suraj Mehta',
    place: 'Nad Al Sheba',
    body:
        'Anyone playing cricket in Dubai this weekend? We need 2 more for a '
        'full side. DM if interested #dabblersport',
    cricket: 'Cricket',
    football: 'Football',
    newsTitle:
        'Dubai adds twelve floodlit community pitches before the winter season',
    newsExcerpt:
        'The municipality confirmed the first six sites open in November, '
        'with booking handled inside the same apps residents already use for '
        'public courts.',
    newsTitleKey: 'Dubai adds twelve',
    newsExcerptKey: 'The municipality confirmed',
    region: 'Dubai',
  );

  static const FrameData ar = FrameData(
    location: 'شارع الشيخة فاطمة بنت مبارك',
    gameTitle: 'خماسي الثلاثاء',
    venue: 'مدينة دبي الرياضية',
    name: 'سوراج ميهتا',
    place: 'ند الشبا',
    body:
        'أحد يلعب كريكيت في دبي نهاية الأسبوع؟ نحتاج لاعبَين لإكمال الفريق. '
        'راسلني إن كنت مهتمًا #dabblersport',
    cricket: 'كريكيت',
    football: 'كرة القدم',
    newsTitle: 'دبي تضيف اثني عشر ملعبًا مجتمعيًا مضاءً قبل موسم الشتاء',
    newsExcerpt:
        'أكدت البلدية افتتاح أول ستة مواقع في نوفمبر، مع الحجز عبر التطبيقات '
        'نفسها التي يستخدمها السكان للملاعب العامة.',
    newsTitleKey: 'دبي تضيف',
    newsExcerptKey: 'أكدت البلدية',
    region: 'دبي',
  );

  static FrameData of(bool rtl) => rtl ? ar : en;
}
