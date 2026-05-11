// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get games_browse_empty_title => 'لا توجد مباريات عامة حالياً';

  @override
  String get games_browse_empty_desc => 'تحقق لاحقاً.';

  @override
  String get games_browse_error => 'تعذّر تحميل المباريات العامة.';

  @override
  String get my_games_empty_title => 'لم تنضم إلى أي مباراة بعد';

  @override
  String get my_games_empty_desc => 'انضم إلى مباراة عامة لتظهر هنا.';

  @override
  String get error_generic => 'حدث خطأ ما';

  @override
  String get game_full => 'المباراة ممتلئة';

  @override
  String get game_waitlisted => 'تمت إضافتك إلى قائمة الانتظار';

  @override
  String get pull_to_refresh => 'اسحب للتحديث';

  @override
  String get rating_thanks => 'شكرًا على تقييمك!';

  @override
  String get rating_submit_error => 'تعذّر إرسال التقييم.';

  @override
  String get venues_search_disabled_mvp =>
      'ميزة البحث غير متاحة في الإصدار الأول';

  @override
  String get tab_most_recent => 'الأحدث';

  @override
  String get tab_following => 'المتابَعون';

  @override
  String get tab_nearby => 'القريبة';

  @override
  String get tab_active => 'النشِطة';

  @override
  String get tab_news => 'الأخبار';

  @override
  String get feed_empty_no_posts => 'لا توجد منشورات بعد';

  @override
  String get feed_empty_no_posts_hint => 'شارك لحظاتك ومبارياتك مع مجتمعك.';

  @override
  String get feed_could_not_load => 'تعذّر تحميل المحتوى';

  @override
  String get feed_retry => 'إعادة المحاولة';

  @override
  String get news_empty_title => 'لا توجد أخبار حالياً.';

  @override
  String get news_empty_hint =>
      'تحقق لاحقاً للاطلاع على آخر تحديثات فريق دابلر.';

  @override
  String get news_hide_sheet_title => 'إخفاء الأخبار من المنشورات؟';

  @override
  String get news_hide_sheet_body =>
      'لن تظهر بطاقات الأخبار في تبويب الأحدث، لكنها ستبقى متاحة بالكامل في تبويب الأخبار.';

  @override
  String get news_hide_confirm => 'إخفاء الأخبار';

  @override
  String get news_hide_cancel => 'إلغاء';

  @override
  String get news_hidden_snack => 'تم إخفاء الأخبار من تبويب الأحدث';

  @override
  String get news_resubscribed_snack => 'ستظهر الأخبار مجدداً في تبويب الأحدث';

  @override
  String get news_resubscribe_banner => 'الأخبار مخفية من تبويب الأحدث.';

  @override
  String get news_resubscribe_action => 'إظهار مجدداً';
}
