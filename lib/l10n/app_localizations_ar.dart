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
}
