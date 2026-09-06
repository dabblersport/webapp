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
  String get games_browse_empty_desc => 'اتحقق تاني بعدين.';

  @override
  String get games_browse_error => 'مقدرناش نحمل المباريات العامة.';

  @override
  String get my_games_empty_title => 'لسه ما انضمتش لأي مباراة';

  @override
  String get my_games_empty_desc => 'انضم لمباراة عامة وهتظهر هنا.';

  @override
  String get error_generic => 'حصل حاجة غلط';

  @override
  String get game_full => 'المباراة اتملت';

  @override
  String get game_waitlisted => 'اتضفت على قايمة الانتظار';

  @override
  String get pull_to_refresh => 'اسحب للتحديث';

  @override
  String get rating_thanks => 'شكراً على تقييمك!';

  @override
  String get rating_submit_error => 'مقدرناش نبعت التقييم.';

  @override
  String get venues_search_disabled_mvp => 'البحث مش متاح في الإصدار ده';

  @override
  String get tab_most_recent => 'الأحدث';

  @override
  String get tab_following => 'المتابَعين';

  @override
  String get tab_nearby => 'القريبة';

  @override
  String get tab_active => 'النشطة';

  @override
  String get tab_news => 'الأخبار';

  @override
  String get feed_empty_no_posts => 'مفيش بوستات لسه';

  @override
  String get feed_empty_no_posts_hint => 'شارك لحظاتك ومبارياتك مع مجتمعك.';

  @override
  String get feed_could_not_load => 'مقدرناش نحمل الفيد';

  @override
  String get feed_retry => 'حاول تاني';

  @override
  String get news_empty_title => 'مفيش أخبار دلوقتي.';

  @override
  String get news_empty_hint => 'اتابع بعدين لأحدث تحديثات تيم دابلر.';

  @override
  String get news_hide_sheet_title => 'تخبي الأخبار من الفيد؟';

  @override
  String get news_hide_sheet_body =>
      'كروت الأخبار مش هتبان في الأحدث. تقدر تقراهم كلهم في تبويب الأخبار.';

  @override
  String get news_hide_confirm => 'خبّي الأخبار';

  @override
  String get news_hide_cancel => 'إلغاء';

  @override
  String get news_hidden_snack => 'الأخبار اتخبت من الأحدث';

  @override
  String get news_resubscribed_snack => 'الأخبار هتبان تاني في الأحدث';

  @override
  String get news_resubscribe_banner => 'الأخبار متخبية من الأحدث.';

  @override
  String get news_resubscribe_action => 'وريهم تاني';

  @override
  String get auth_welcome_title => 'أهلاً بيك!';

  @override
  String get auth_welcome_subtitle =>
      'يسعدنا انضمامك لينا. أنشئ حساب وابدأ تلعب رياضة مع مجتمعك.';

  @override
  String get auth_welcome_trust_heading => 'مبني على الثقة';

  @override
  String get auth_welcome_trust_verified =>
      'لاعبين موثوقين، عضويات معتمدة، وملاعب متقيَّمة';

  @override
  String get auth_welcome_trust_personalised =>
      'توصيات وتواصل مخصص لرياضاتك المفضلة';

  @override
  String get auth_welcome_trust_privacy =>
      'مش بنبيع بياناتك — الخصوصية أولوية عندنا';

  @override
  String get auth_welcome_get_started => 'يلا نبدأ';

  @override
  String get auth_welcome_get_started_subtitle => 'أنشئ حساب أو سجّل دخولك';

  @override
  String get auth_welcome_btn_google => 'متابعه عبر Google';

  @override
  String get auth_welcome_btn_apple => 'متابعه عبر Apple';

  @override
  String get auth_welcome_btn_email => 'متابعه عبر الإيميل';

  @override
  String get auth_welcome_btn_login => 'عندك حساب بالفعل؟ سجّل دخولك';

  @override
  String get auth_welcome_apple_soon => 'تسجيل الدخول بـ Apple جاي قريباً.';

  @override
  String auth_welcome_google_error(String error) {
    return 'مقدرناش ندخل بـ Google: $error';
  }

  @override
  String get auth_welcome_country_picker_title => 'اختار بلدك';

  @override
  String get auth_welcome_language_picker_title => 'اختار اللغة';

  @override
  String get landing_quote1 => 'وعدت نفسي إني ألعب مرتين في الأسبوع على الأقل.';

  @override
  String get landing_quote2 =>
      'بين الشغل والحياة، لقاء مباراة بقت أصعب من ماراثون.';

  @override
  String get landing_tagline =>
      'دابلر بيربط اللاعبين والكابتنية والملاعب — وقّف تدور وابدأ تلعب';

  @override
  String get landing_continue => 'متابعه';

  @override
  String get landing_choose_language => 'اختار اللغة';

  @override
  String get email_input_title => 'تسجيل';

  @override
  String get email_input_subtitle => 'أدخل إيميلك عشان نبدأ';

  @override
  String get email_input_label => 'الإيميل';

  @override
  String get email_input_hint => 'email@domain.com';

  @override
  String get email_input_continue => 'متابعه';

  @override
  String get email_input_keep_in_loop => 'خليني على اطلاع بتحديثات وأخبار';

  @override
  String get email_input_already_account => 'عندك حساب بالفعل؟ سجّل دخولك';

  @override
  String get email_input_btn_google => 'متابعه عبر Google';

  @override
  String get email_input_btn_apple => 'متابعه عبر Apple';

  @override
  String get email_input_terms_prefix => 'بالضغط على متابعه، إنت بتوافق على ';

  @override
  String get email_input_terms_link => 'شروط الخدمة';

  @override
  String get email_input_terms_and => ' و';

  @override
  String get email_input_privacy_link => 'سياسة الخصوصية';

  @override
  String get email_input_validate_required => 'الإيميل مطلوب';

  @override
  String get email_input_validate_invalid => 'أدخل إيميل صح';

  @override
  String get email_input_error_generic => 'حصل خطأ. جرب تاني.';

  @override
  String get email_input_google_failed =>
      'تسجيل الدخول بـ Google فشل. جرب تاني.';

  @override
  String get email_password_title => 'تسجيل الدخول';

  @override
  String get email_password_subtitle =>
      'أدخل إيميلك وكلمة سرك\nأو سجّل دخولك بـ OTP';

  @override
  String get email_password_forgot => 'نسيت كلمة السر؟';

  @override
  String get email_password_send_otp => 'ابعتلي OTP على الإيميل';

  @override
  String get email_password_login_btn => 'دخول';

  @override
  String get email_password_btn_google => 'متابعه عبر Google';

  @override
  String get email_password_btn_apple => 'متابعه عبر Apple';

  @override
  String get email_password_hint_email => 'email@domain.com';

  @override
  String get email_password_hint_password => 'كلمة السر';

  @override
  String get email_password_show_password => 'وري كلمة السر';

  @override
  String get email_password_hide_password => 'خبّي كلمة السر';

  @override
  String get email_password_validate_email_required => 'الإيميل مطلوب';

  @override
  String get email_password_validate_email_invalid => 'أدخل إيميل صح';

  @override
  String get email_password_validate_password_required => 'أدخل كلمة السر';

  @override
  String get email_password_error_invalid_creds => 'الإيميل أو كلمة السر غلط';

  @override
  String get email_password_error_login_failed => 'فشل تسجيل الدخول.';

  @override
  String get email_password_error_otp_failed =>
      'مقدرناش نبعت الـ OTP. جرب تاني.';

  @override
  String get email_password_apple_soon => 'تسجيل الدخول بـ Apple جاي قريباً.';

  @override
  String get email_password_google_failed => 'تسجيل الدخول بـ Google فشل.';

  @override
  String get email_password_validate_email_hint => 'أدخل إيميل صح.';

  @override
  String get email_verify_appbar => 'تأكيد الإيميل';

  @override
  String get email_verify_title => 'اتحقق من صندوق الوارد';

  @override
  String email_verify_body_with_email(String email) {
    return 'بعتنالك لينك تأكيد على $email.\n\nأكّد إيميلك عشان تكمّل إنشاء حسابك.';
  }

  @override
  String get email_verify_body_no_email =>
      'بعتنالك لينك تأكيد على إيميلك.\n\nأكّد إيميلك عشان تكمّل إنشاء حسابك.';

  @override
  String get email_verify_instruction =>
      'بعد ما تأكد إيميلك، ارجع للتطبيق واضغط \"أكّدت إيميلي\" عشان تكمّل.';

  @override
  String get email_verify_confirmed_btn => 'أكّدت إيميلي';

  @override
  String get email_verify_resend_btn => 'ابعت إيميل تأكيد تاني';

  @override
  String get email_verify_different_account => 'استخدم حساب تاني';

  @override
  String get email_verify_no_email_error => 'مفيش إيميل للمستخدم الحالي.';

  @override
  String get email_verify_spam_note =>
      'لو ما لقيتش الإيميل، اتحقق من الـ Spam أو اطلب لينك جديد من شاشة الدخول.';

  @override
  String get forgot_password_title => 'إعادة تعيين كلمة السر';

  @override
  String get forgot_password_subtitle =>
      'أدخل إيميلك وهنبعتلك لينك تغيير كلمة السر.';

  @override
  String get forgot_password_email_hint => 'الإيميل';

  @override
  String get forgot_password_send_btn => 'ابعت لينك الإعادة';

  @override
  String get forgot_password_sent_msg =>
      'اتبعت اللينك! اتحقق من صندوق الوارد والـ Spam عندك.';

  @override
  String get forgot_password_back_to_signin => 'ارجع لتسجيل الدخول';

  @override
  String get forgot_password_validate_email => 'أدخل إيميل صح';

  @override
  String get otp_verify_title_email => 'تأكيد الإيميل';

  @override
  String get otp_verify_title_phone => 'تأكيد الموبايل';

  @override
  String get otp_verify_subtitle_email =>
      'أدخل الـ 6 أرقام اللي بعتناهالك على إيميلك';

  @override
  String get otp_verify_subtitle_phone =>
      'أدخل الـ 6 أرقام اللي بعتناهالك على موبايلك';

  @override
  String get otp_verify_change_email => 'غيّر الإيميل';

  @override
  String get otp_verify_change_phone => 'غيّر الموبايل';

  @override
  String get otp_verify_continue => 'متابعه';

  @override
  String get otp_verify_didnt_get => 'ما وصلكش الكود؟ ';

  @override
  String otp_verify_resend_countdown(int seconds) {
    return 'ابعت كود تاني ($secondsث)';
  }

  @override
  String get otp_verify_resend => 'ابعت كود تاني';

  @override
  String get otp_verify_sending => 'بيتبعت...';

  @override
  String get otp_verify_sent_email => 'اتبعت الـ OTP على إيميلك بنجاح';

  @override
  String get otp_verify_sent_phone => 'اتبعت الـ OTP على موبايلك بنجاح';

  @override
  String otp_verify_error_prefix(String error) {
    return 'خطأ: $error';
  }

  @override
  String get reset_password_title => 'تغيير كلمة السر';

  @override
  String get reset_password_subtitle => 'أنشئ كلمة سر جديدة لحسابك';

  @override
  String get reset_password_new_label => 'كلمة السر الجديدة';

  @override
  String get reset_password_confirm_label => 'تأكيد كلمة السر';

  @override
  String get reset_password_update_btn => 'حدّث كلمة السر';

  @override
  String get reset_password_validate_enter => 'أدخل كلمة سر';

  @override
  String get reset_password_validate_min => 'استخدم 8 حروف على الأقل';

  @override
  String get reset_password_validate_confirm => 'أكّد كلمة السر';

  @override
  String get reset_password_validate_match => 'كلمتا السر مش متطابقتين';

  @override
  String get set_password_title => 'أنشئ حسابك';

  @override
  String set_password_email_prefix(String email) {
    return 'الإيميل: $email';
  }

  @override
  String get set_password_username_label => 'اسم المستخدم';

  @override
  String get set_password_username_hint => 'اختار اسم مستخدم مميز';

  @override
  String get set_password_password_label => 'كلمة السر';

  @override
  String get set_password_password_hint => 'أدخل كلمة سر قوية';

  @override
  String get set_password_confirm_label => 'تأكيد كلمة السر';

  @override
  String get set_password_confirm_hint => 'أعد إدخال كلمة السر';

  @override
  String get set_password_create_btn => 'أنشئ الحساب';

  @override
  String get set_password_creating_btn => 'بيتنشأ الحساب...';

  @override
  String set_password_wait_btn(int seconds) {
    return 'استنّى $seconds ث';
  }

  @override
  String get set_password_validate_username_required => 'اسم المستخدم مطلوب';

  @override
  String get set_password_validate_username_min =>
      'اسم المستخدم لازم يكون 3 حروف على الأقل';

  @override
  String get set_password_validate_username_max =>
      'اسم المستخدم لازم يكون 20 حرف أو أقل';

  @override
  String get set_password_validate_username_chars => 'حروف وأرقام وـ بس';

  @override
  String get set_password_validate_username_taken => 'اسم المستخدم مش متاح';

  @override
  String get set_password_validate_username_checking =>
      'خطأ في التحقق من اسم المستخدم';

  @override
  String get set_password_validate_password_required => 'كلمة السر مطلوبة';

  @override
  String get set_password_validate_password_min =>
      'كلمة السر لازم تكون 6 حروف على الأقل';

  @override
  String get set_password_validate_confirm_required => 'أكّد كلمة السر';

  @override
  String get set_password_validate_confirm_match => 'كلمتا السر مش متطابقتين';

  @override
  String get set_password_wait_validation =>
      'استنّى حتى ينتهي التحقق من اسم المستخدم';

  @override
  String get set_password_account_exists =>
      'الحساب موجود بالفعل. سجّل دخولك بكلمة سرك.';

  @override
  String get set_password_rate_limit => 'استنّى شوية وحاول تاني.';

  @override
  String set_password_error_prefix(String error) {
    return 'خطأ: $error';
  }

  @override
  String get create_info_title => 'قولنا عن نفسك شوية';

  @override
  String get create_info_subtitle =>
      'أكّد سنك، لازم تكون عندك 16 سنة أو أكتر عشان تستخدم دابلر';

  @override
  String get create_info_birth_date => 'تاريخ الميلاد';

  @override
  String get create_info_birth_date_placeholder => 'اختار تاريخ ميلادك';

  @override
  String create_info_age_display(int age) {
    return 'عندك $age سنة';
  }

  @override
  String get create_info_gender => 'الجنس (اختياري)';

  @override
  String get create_info_continue => 'متابعه';

  @override
  String get create_info_error_fill_required => 'إملا كل الحقول المطلوبة صح';

  @override
  String get create_info_error_select_birth => 'اختار تاريخ ميلادك';

  @override
  String get create_info_error_min_age =>
      'لازم تكون عندك 16 سنة على الأقل عشان تسجّل';

  @override
  String create_info_error_max_age(int max) {
    return 'السن لازم تكون بين 16 و$max سنة';
  }

  @override
  String get create_info_error_select_gender => 'اختار جنسك';

  @override
  String create_info_error_occurred(String error) {
    return 'حصل خطأ: $error';
  }

  @override
  String get set_username_title_onboarding => 'عرّف بنفسك';

  @override
  String get set_username_title_conversion => 'أكمل التحويل';

  @override
  String get set_username_title_new_profile => 'أكمل البروفايل الجديد';

  @override
  String get set_username_subtitle_onboarding =>
      'اختار إزاي الناس تناديك وحدد اسم مستخدمك';

  @override
  String set_username_subtitle_persona(String persona) {
    return 'اختار اسم عرض واسم مستخدم لبروفايل الـ $persona بتاعك';
  }

  @override
  String get set_username_display_name_label => 'الاسم المعروض';

  @override
  String get set_username_display_name_hint => 'أدخل اسمك المعروض';

  @override
  String get set_username_username_label => 'اسم المستخدم';

  @override
  String get set_username_username_hint => 'اختار اسم مستخدم مميز';

  @override
  String get set_username_suggestions => 'اقتراحات';

  @override
  String get set_username_btn_complete => 'خلصنا';

  @override
  String get set_username_btn_create_profile => 'أنشئ البروفايل';

  @override
  String get set_username_btn_complete_conversion => 'أكمل التحويل';

  @override
  String get set_username_back => 'ارجع';

  @override
  String set_username_converting_to(String persona) {
    return 'بيتحول لـ $persona';
  }

  @override
  String set_username_adding_profile(String persona) {
    return 'بيضاف بروفايل $persona';
  }

  @override
  String get set_username_validate_display_required => 'الاسم المعروض مطلوب';

  @override
  String get set_username_validate_display_min =>
      'الاسم المعروض لازم يكون حرفين على الأقل';

  @override
  String get set_username_validate_username_required => 'اسم المستخدم مطلوب';

  @override
  String get set_username_validate_username_min =>
      'اسم المستخدم لازم يكون 3 حروف على الأقل';

  @override
  String get set_username_validate_username_chars => 'حروف وأرقام وـ بس';

  @override
  String get set_username_unavailable => 'اسم المستخدم مش متاح';

  @override
  String get set_username_check_error => 'خطأ في التحقق من اسم المستخدم';

  @override
  String get set_username_missing_onboarding =>
      'بيانات التسجيل ناقصة. ابدأ من الأول.';

  @override
  String get set_username_missing_steps => 'معلومات ناقصة. أكمل كل الخطوات.';

  @override
  String get set_username_session_expired =>
      'جلستك انتهت. أكّد رقم موبايلك تاني.';

  @override
  String get set_username_missing_persona_data =>
      'بيانات ناقصة. ابدأ من الأول.';

  @override
  String get intent_title => 'إيه اللي جابك هنا؟';

  @override
  String get intent_subtitle => 'قولنا عشان نخلي دابلر مناسب ليك';

  @override
  String get intent_compete_title => 'تنافس';

  @override
  String get intent_compete_desc => 'انضم لمباريات، تابع مستواك، العب بانتظام';

  @override
  String get intent_organise_title => 'نظّم';

  @override
  String get intent_organise_desc => 'أنشئ مباريات، حدد قواعد، أدر اللاعبين';

  @override
  String get intent_host_title => 'استضيف';

  @override
  String get intent_host_desc => 'أدر الملاعب والتوافر والحجوزات';

  @override
  String get intent_socialise_title => 'تواصل';

  @override
  String get intent_socialise_desc => 'تابع رياضات وناس ومجتمعات';

  @override
  String get intent_continue => 'متابعه';

  @override
  String get intent_back => 'ارجع';

  @override
  String get intent_select_role => 'اختار دورك';

  @override
  String get interests_title_player => 'إيه الرياضات اللي بتمارسها؟';

  @override
  String get interests_title_organiser => 'إيه الرياضات اللي بتنظمها؟';

  @override
  String get interests_title_host => 'إيه الرياضات اللي بتاستضيفها؟';

  @override
  String get interests_title_socialiser => 'إيه الرياضات اللي بتحبها؟';

  @override
  String get interests_title_default => 'إيه الرياضات اللي بتمارسها؟';

  @override
  String get interests_subtitle => 'تقدر تغيّر وتضيف رياضات تانية بعدين';

  @override
  String get interests_available_sports => 'الرياضات المتاحة';

  @override
  String interests_selected_count_one(int count) {
    return 'رياضة واحدة اتختارت ($count)';
  }

  @override
  String interests_selected_count_many(int count) {
    return '$count رياضات اتختارت';
  }

  @override
  String get interests_continue => 'متابعه';

  @override
  String get interests_back => 'ارجع';

  @override
  String get interests_cancel => 'إلغاء';

  @override
  String get interests_select_one => 'اختار رياضة واحدة على الأقل';

  @override
  String get interests_failed_load => 'فشل تحميل الرياضات';

  @override
  String get interests_retry => 'حاول تاني';

  @override
  String get primary_sport_title => 'اختار رياضتك الأساسية';

  @override
  String get primary_sport_subtitle =>
      'الرياضة دي هتبان على بروفايلك وهتتستخدم افتراضياً.';

  @override
  String get primary_sport_helper => 'تقدر تغيّرها بعدين.';

  @override
  String get primary_sport_badge => 'أساسية';

  @override
  String get primary_sport_continue => 'متابعه';

  @override
  String get primary_sport_back => 'ارجع';

  @override
  String get primary_sport_cancel => 'إلغاء';

  @override
  String get primary_sport_select_error => 'اختار رياضتك الأساسية';

  @override
  String get primary_sport_failed_load => 'فشل تحميل الرياضات';

  @override
  String get primary_sport_no_sports => 'مفيش رياضات متاخترة. ارجع للخلف.';

  @override
  String primary_sport_adding(String label) {
    return 'بيضاف بروفايل $label';
  }

  @override
  String get identity_verify_title => 'التحقق من الهوية';

  @override
  String get identity_verify_email_label => 'الإيميل';

  @override
  String get identity_verify_email_hint => 'أدخل إيميلك';

  @override
  String get identity_verify_continue_sending => 'بيتبعت...';

  @override
  String get identity_verify_continue => 'متابعه';

  @override
  String get identity_verify_or => 'أو';

  @override
  String get identity_verify_google_btn => 'متابعه عبر Google';

  @override
  String get identity_verify_terms_prefix => 'بالكمال، إنت بتوافق على ';

  @override
  String get identity_verify_terms_link => 'شروط الخدمة';

  @override
  String get identity_verify_terms_and => ' و';

  @override
  String get identity_verify_privacy_link => 'سياسة الخصوصية';

  @override
  String get identity_verify_otp_sent_email =>
      'اتبعت الـ OTP! اتحقق من إيميلك.';

  @override
  String get identity_verify_otp_sent_phone =>
      'اتبعت الـ OTP! اتحقق من موبايلك.';

  @override
  String get identity_verify_phone_disabled =>
      'التحقق بالموبايل مش متاح لسه. استخدم الإيميل عشان تكمّل.';

  @override
  String identity_verify_service_error(String error) {
    return 'خطأ في الخدمة: $error';
  }

  @override
  String get identity_verify_error_generic => 'مقدرناش نبعت الـ OTP. جرب تاني.';

  @override
  String identity_verify_nav_failed(String error) {
    return 'فشل الانتقال: $error';
  }

  @override
  String get identity_verify_use_email => 'استخدم إيميلك';

  @override
  String get identity_verify_required => 'الإيميل أو رقم الموبايل مطلوب';

  @override
  String get identity_verify_google_failed =>
      'تسجيل الدخول بـ Google فشل. جرب تاني.';

  @override
  String get welcome_screen_title_first_time => 'أهلاً بيك في دابلر 😉';

  @override
  String get welcome_screen_title_returning => 'أهلاً بيك تاني! 👋';

  @override
  String get welcome_screen_title_conversion => 'التحويل اكتمل! 🎉';

  @override
  String get welcome_screen_dont_forget => 'متنساش';

  @override
  String get welcome_screen_continue => 'متابعه';

  @override
  String get welcome_screen_chip_player => 'لاعب رياضي';

  @override
  String get welcome_screen_chip_organiser => 'منظّم مباريات';

  @override
  String get welcome_screen_chip_host => 'مضيف ملعب';

  @override
  String get welcome_screen_chip_socialiser => 'متواصل رياضي';

  @override
  String get welcome_screen_player_guidance =>
      'انضم لمباريات بمستواك، احترم قواعد المنظّم، وأكّد مشاركتك بس لما تكون متأكد إنك هتيجي.';

  @override
  String get welcome_screen_player_philosophy => 'التزامك ببني سمعتك.';

  @override
  String get welcome_screen_player_reminder =>
      'أكّد بس لما تكون متأكد إنك تقدر تيجي.\nاحترم القواعد والمواعيد واللاعبين التانيين.';

  @override
  String get welcome_screen_player_emphasis => 'أكّد بس لما تكون جاهز تلعب';

  @override
  String get welcome_screen_organiser_guidance =>
      'أنشئ مباريات بقواعد واضحة ومستويات عادلة ومواعيد معقولة.';

  @override
  String get welcome_screen_organiser_philosophy =>
      'إنت بتحدد الأجواء — المباريات العظيمة بتبدأ بتنظيم عظيم.';

  @override
  String get welcome_screen_organiser_reminder =>
      'حدد قواعد واضحة ومواعيد معقولة.\nبلّغ عن أي تغييرات بدري وبوضوح.';

  @override
  String get welcome_screen_organiser_emphasis => 'كمّل بس لما تكون جاهز!';

  @override
  String get welcome_screen_host_guidance =>
      'خلّي اللاعبين يحسوا بالترحيب بإنك تخلّي المعلومات دقيقة والمساحات جاهزة.';

  @override
  String get welcome_screen_host_philosophy =>
      'الوضوح في التوافر والتنسيم السلس بيحسّن تجربة الكل.';

  @override
  String get welcome_screen_host_reminder =>
      'خلّي التوافر والتفاصيل دايماً محدّثة.\nحدّث المعلومات فور ما أي حاجة تتغير.';

  @override
  String get welcome_screen_host_emphasis => 'كمّل بس لما تكون جاهز!';

  @override
  String get welcome_screen_socialiser_guidance =>
      'تواصل مع اللاعبين، ابدأ محادثات، وخلّي المباريات أكتر إنسانية.';

  @override
  String get welcome_screen_socialiser_philosophy =>
      'وجودك بيشكّل المجتمع — ودود وشامل ومحترم.';

  @override
  String get welcome_screen_socialiser_reminder =>
      'كون محترم وشامل.\nضيف قيمة من غير ما تعطّل المباراة.';

  @override
  String get welcome_screen_socialiser_emphasis => 'كمّل بس لما تكون جاهز!';

  @override
  String get onboarding_welcome_title => 'بيتضبط حسابك';

  @override
  String get onboarding_welcome_subtitle => 'ده هياخد لحظة بس...';

  @override
  String get onboarding_welcome_step_profile => 'بيتنشأ بروفايلك';

  @override
  String get social_onboarding_welcome_title => 'أهلاً في السوشيال';

  @override
  String get social_onboarding_welcome_subtitle =>
      'تواصل مع لاعبين زيك، شارك تجارب مبارياتك، وابني مجتمعك الرياضي.';

  @override
  String get social_onboarding_welcome_skip => 'تخطّي';

  @override
  String get social_onboarding_welcome_get_started => 'يلا نبدأ';

  @override
  String get social_onboarding_welcome_find_friends_title => 'لاقي أصحابك';

  @override
  String get social_onboarding_welcome_find_friends_desc =>
      'تواصل مع لاعبين في منطقتك';

  @override
  String get social_onboarding_welcome_chat_title => 'شات وشارك';

  @override
  String get social_onboarding_welcome_chat_desc =>
      'راسل أصحابك وشارك لحظاتك في المباريات';

  @override
  String get social_onboarding_welcome_game_title => 'العب مع بعض';

  @override
  String get social_onboarding_welcome_game_desc =>
      'اكتشف وانضم لمباريات مع شبكتك';

  @override
  String get social_onboarding_friends_appbar => 'لاقي أصحابك';

  @override
  String get social_onboarding_friends_title => 'لاقي مجتمعك الرياضي';

  @override
  String get social_onboarding_friends_subtitle =>
      'تواصل مع أصحابك عشان تشارك تجارب المباريات وتكتشف فرص جديدة.';

  @override
  String get social_onboarding_friends_sync_btn => 'زامن جهات الاتصال';

  @override
  String get social_onboarding_friends_syncing => 'بيتزامن...';

  @override
  String get social_onboarding_friends_or => 'أو';

  @override
  String get social_onboarding_friends_suggested => 'مقترح ليك';

  @override
  String social_onboarding_friends_selected(int count) {
    return '$count اتختارت';
  }

  @override
  String social_onboarding_friends_mutual_one(int count) {
    return 'صاحب مشترك ($count)';
  }

  @override
  String social_onboarding_friends_mutual_many(int count) {
    return '$count أصحاب مشتركين';
  }

  @override
  String get social_onboarding_friends_add_btn => 'أضف';

  @override
  String get social_onboarding_friends_added => 'اتضاف';

  @override
  String get social_onboarding_friends_skip => 'تخطّي';

  @override
  String get social_onboarding_friends_continue => 'متابعه';

  @override
  String social_onboarding_friends_send_requests(int count) {
    return 'ابعت $count طلبات وكمّل';
  }

  @override
  String get social_onboarding_friends_send_request => 'ابعت الطلب وكمّل';

  @override
  String get social_onboarding_friends_synced => 'اتزامنت جهات الاتصال بنجاح!';

  @override
  String get social_onboarding_friends_sync_error =>
      'خطأ في الوصول لجهات الاتصال. جرب تاني.';

  @override
  String social_onboarding_friends_sent(int count) {
    return 'اتبعتت طلبات صداقة لـ $count ناس!';
  }

  @override
  String get social_onboarding_notif_appbar => 'الإشعارات';

  @override
  String get social_onboarding_notif_title => 'الإشعارات متوقفة دلوقتي';

  @override
  String get social_onboarding_notif_body =>
      'بنبني إعدادات الإشعارات من الأول. تقدر تكمّل التسجيل دلوقتي وهنضيف خيارات الضبط في تحديث جاي.';

  @override
  String get social_onboarding_notif_finish => 'خلّصنا';

  @override
  String get social_onboarding_privacy_appbar => 'إعدادات الخصوصية';

  @override
  String get social_onboarding_privacy_title => 'الخصوصية والأمان';

  @override
  String get social_onboarding_privacy_subtitle =>
      'تحكّم في مين يشوف بروفايلك ويتفاعل معاك. تقدر تغيّر الإعدادات دي بعدين.';

  @override
  String get social_onboarding_privacy_step => '3 من 4';

  @override
  String get social_onboarding_privacy_profile_visible_title =>
      'البروفايل واضح للأصحاب';

  @override
  String get social_onboarding_privacy_profile_visible_subtitle =>
      'بروفايلك واضح لأصحابك';

  @override
  String get social_onboarding_privacy_posts_public_title => 'البوستات عامة';

  @override
  String get social_onboarding_privacy_posts_public_subtitle =>
      'أي حد يقدر يشوف بوستاتك';

  @override
  String get social_onboarding_privacy_allow_requests_title =>
      'السماح بطلبات الصداقة';

  @override
  String get social_onboarding_privacy_allow_requests_subtitle =>
      'الناس تقدر تبعتلك طلبات صداقة';

  @override
  String get social_onboarding_privacy_allow_messages_title =>
      'السماح بطلبات الرسايل';

  @override
  String get social_onboarding_privacy_allow_messages_subtitle =>
      'غير الأصحاب يقدروا يبعتولك رسايل';

  @override
  String get social_onboarding_privacy_online_status_title =>
      'إظهار حالة الاتصال';

  @override
  String get social_onboarding_privacy_online_status_subtitle =>
      'أصحابك يشوفوا لما تكون أونلاين';

  @override
  String get social_onboarding_privacy_back => 'ارجع';

  @override
  String get social_onboarding_privacy_continue => 'متابعه';

  @override
  String get social_onboarding_complete_title => 'أهلاً بيك في السوشيال!';

  @override
  String get social_onboarding_complete_subtitle =>
      'خلّصنا! ابدأ تتواصل مع أصحابك، شارك تجارب مبارياتك، واكتشف لاعبين جدد في منطقتك.';

  @override
  String get social_onboarding_complete_connect_title => 'تواصل مع اللاعبين';

  @override
  String get social_onboarding_complete_connect_desc =>
      'لاقي وأضف أصحاب بيحبوا نفس الرياضات';

  @override
  String get social_onboarding_complete_share_title => 'شارك رحلتك';

  @override
  String get social_onboarding_complete_share_desc =>
      'انشر تحديثات وصور واحتفل بإنجازاتك';

  @override
  String get social_onboarding_complete_discover_title => 'اكتشف مباريات';

  @override
  String get social_onboarding_complete_discover_desc =>
      'شوف إيه المباريات اللي أصحابك بيلعبوها';

  @override
  String get social_onboarding_complete_explore_btn => 'استكشف السوشيال';

  @override
  String get social_onboarding_complete_home_btn => 'روح الهوم';

  @override
  String get social_onboarding_complete_later => 'هستكشف بعدين';

  @override
  String get language_select_title => 'اختار لغتك';

  @override
  String get language_select_saving => 'بيتحفظ...';

  @override
  String get register_title => 'إنشاء حساب';

  @override
  String get register_btn => 'سجّل';

  @override
  String get post_card_author_anonymous => 'مجهول';

  @override
  String get post_card_user_fallback => 'مستخدم';

  @override
  String get post_card_persona_organiser => 'منظّم';

  @override
  String get post_card_persona_player => 'لاعب';

  @override
  String get post_card_near_you => 'قريّب منك';

  @override
  String get post_card_edited => 'اتعدّل';

  @override
  String get post_card_menu_repost => 'إعادة نشر';

  @override
  String get post_card_menu_quote_repost => 'اقتباس وإعادة نشر';

  @override
  String get post_card_kind_moment => 'لحظة';

  @override
  String get post_card_kind_dab => 'Dab';

  @override
  String get post_card_kind_kick_in => 'Kick-in';

  @override
  String get post_card_kind_game => 'ماتش';

  @override
  String get post_card_kind_achievement => 'إنجاز';

  @override
  String get post_card_kind_venue => 'ملعب';

  @override
  String get post_card_kind_admin => 'إدارة';

  @override
  String get post_card_kind_system => 'النظام';

  @override
  String get post_card_kind_repost => 'إعادة نشر';

  @override
  String get post_card_expired => 'خلص';

  @override
  String post_card_expires_in_days(int n) {
    return 'بيخلص بعد $nي';
  }

  @override
  String post_card_expires_in_hours(int n) {
    return 'بيخلص بعد $nس';
  }

  @override
  String post_card_expires_in_minutes(int n) {
    return 'بيخلص بعد $nد';
  }

  @override
  String get post_card_expiring_soon => 'قرّب يخلص';

  @override
  String get repost_card_unavailable => 'البوست الأصلي مش متاح.';

  @override
  String get post_type_original => 'أصلي';

  @override
  String get post_type_news => 'أخبار';

  @override
  String get post_type_announcement => 'إعلان';

  @override
  String get post_type_alert => 'تنبيه';

  @override
  String get post_type_highlight => 'لقطة';

  @override
  String get post_type_general => 'عام';

  @override
  String get post_type_feature => 'مميز';

  @override
  String get post_card_my_story => 'ستوري';

  @override
  String get post_card_kick_in_label => 'Kick-In';

  @override
  String get post_card_allocated => 'متحجز';

  @override
  String get nav_feeds => 'الفيد';

  @override
  String get nav_community => 'المجتمع';

  @override
  String get nav_venues => 'الملاعب';

  @override
  String get nav_games => 'الماتشات';

  @override
  String get nav_meetups => 'اللمّات';

  @override
  String get nav_create_post => 'بوست جديد';

  @override
  String get nav_create_game => 'ماتش جديد';

  @override
  String get nav_create_meetup => 'لمّة جديدة';

  @override
  String get nav_meetups_coming_soon => 'اللمّات جايّة قريب!';

  @override
  String get nav_exit_app_title => 'تخرج من التطبيق؟';

  @override
  String get nav_exit_app_body => 'متأكد إنك عايز تخرج من دابلر؟';

  @override
  String get nav_exit_app_cancel => 'إلغاء';

  @override
  String get nav_exit_app_confirm => 'اخرج';

  @override
  String get nav_press_back_to_exit => 'اضغط رجوع تاني عشان تخرج';

  @override
  String get nav_search_hint => 'دوّر في دابلر';

  @override
  String get nav_whats_happening => 'اللي بيحصل دلوقتي';

  @override
  String get nav_trend_sports_category => 'رياضة';

  @override
  String get nav_trend_sports_title => 'ماتشات جديدة قريّب منك';

  @override
  String get nav_trend_sports_subtitle => 'شوف أحدث الماتشات في منطقتك';

  @override
  String get nav_trend_community_category => 'مجتمع';

  @override
  String get nav_trend_community_title => 'Squads بتكبر';

  @override
  String get nav_trend_community_subtitle => 'انضم لـ Squad وكمّل لعب';

  @override
  String get nav_trend_dabbler_category => 'دابلر';

  @override
  String get nav_trend_dabbler_title => 'شارك لحظاتك';

  @override
  String get nav_trend_dabbler_subtitle => 'انشر تحديثاتك واتواصل مع اللاعبين';

  @override
  String get nav_quick_actions => 'اختصارات';

  @override
  String get nav_find_friends => 'لاقي أصحابك';

  @override
  String get nav_settings => 'الإعدادات';

  @override
  String get settings_header_title => 'الإعدادات';

  @override
  String get settings_header_help_tooltip => 'مركز المساعدة';

  @override
  String get settings_hero_eyebrow => 'خصص تجربتك';

  @override
  String get settings_hero_title => 'اضبط Dabbler على طريقة لعبك';

  @override
  String get settings_hero_subtitle =>
      'تحكم في حسابك وتفضيلاتك وإشعاراتك من مكان واحد.';

  @override
  String get settings_search_hint => 'دور في الإعدادات';

  @override
  String get settings_section_account => 'الحساب';

  @override
  String get settings_section_display => 'العرض';

  @override
  String get settings_section_about => 'عن التطبيق';

  @override
  String get settings_section_profiles => 'البروفايلات';

  @override
  String get settings_item_account_management_title => 'إدارة الحساب';

  @override
  String get settings_item_account_management_subtitle =>
      'الإيميل وكلمة السر والأمان';

  @override
  String get settings_item_privacy_settings_title => 'إعدادات الخصوصية';

  @override
  String get settings_item_privacy_settings_subtitle =>
      'تحكم في إعدادات الخصوصية والمستخدمين المحظورين';

  @override
  String get settings_item_theme_title => 'المظهر';

  @override
  String get settings_item_theme_subtitle =>
      'فاتح أو غامق أو حسب إعدادات الجهاز';

  @override
  String get settings_item_language_title => 'اللغة';

  @override
  String get settings_item_country_title => 'دولة التطبيق';

  @override
  String get settings_item_country_default_subtitle =>
      'مصر · الإمارات · السعودية · المغرب';

  @override
  String get settings_country_picker_helper =>
      'بتحدد الرياضات والأماكن اللي هتشوفها';

  @override
  String get settings_item_terms_title => 'شروط الخدمة';

  @override
  String get settings_item_terms_subtitle => 'اقرأ الشروط والأحكام بتاعتنا';

  @override
  String get settings_item_privacy_policy_title => 'سياسة الخصوصية';

  @override
  String get settings_item_privacy_policy_subtitle => 'إزاي بنتعامل مع بياناتك';

  @override
  String get settings_item_licenses_title => 'التراخيص';

  @override
  String get settings_item_licenses_subtitle => 'تراخيص المصادر المفتوحة';

  @override
  String get settings_sign_out_title => 'تسجيل الخروج';

  @override
  String get settings_sign_out_subtitle => 'هتسيب حسابك على الجهاز ده';

  @override
  String get settings_sign_out_dialog_title => 'تسجيل الخروج';

  @override
  String get settings_sign_out_dialog_body =>
      'متأكد إنك عايز تسجل خروج من حسابك؟';

  @override
  String get settings_sign_out_dialog_cancel => 'إلغاء';

  @override
  String settings_sign_out_error(String error) {
    return 'حصل خطأ أثناء تسجيل الخروج: $error';
  }

  @override
  String get settings_version_app_name => 'Dabbler';

  @override
  String settings_version_label(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settings_version_copyright =>
      '© 2026 Dabbler. جميع الحقوق محفوظة.';

  @override
  String settings_persona_become_title(String persona) {
    return 'بقى $persona';
  }

  @override
  String settings_persona_convert_title(String persona) {
    return 'تحوّل لـ $persona';
  }

  @override
  String settings_persona_convert_subtitle(String persona) {
    return 'هيستبدل بروفايل $persona بتاعك';
  }

  @override
  String settings_persona_convert_confirm_body(
    String fromPersona,
    String toPersona,
  ) {
    return 'هيتعطل بروفايل $fromPersona بتاعك وهيتعمل بروفايل $toPersona جديد.\n\nبيانات حسابك (السن والنوع) هتفضل زي ما هي.';
  }

  @override
  String get persona_label_host => 'مضيف';

  @override
  String get persona_label_socialiser => 'متواصل';

  @override
  String get profile_header_fallback => 'البروفايل';

  @override
  String get profile_section_sports => 'الرياضات';

  @override
  String get profile_complete_your_profile => 'كمّل بروفايلك';

  @override
  String get profile_bio_placeholder =>
      'اكتب نبذة قصيرة عشان الناس تعرف تتوقع منك إيه.';

  @override
  String get profile_btn_edit => 'تعديل البروفايل';

  @override
  String get profile_btn_share => 'شارك البروفايل';

  @override
  String get profile_btn_manage_profiles_tooltip => 'إدارة البروفايلات';

  @override
  String get profile_manage_profiles_title => 'إدارة البروفايلات';

  @override
  String get profile_add_profile => 'إضافة بروفايل';

  @override
  String get profile_no_profiles_found => 'مفيش بروفايلات';

  @override
  String get profile_error_loading_profiles => 'حصل خطأ في تحميل البروفايلات';

  @override
  String get profile_error_switch_profile_failed => 'مقدرناش نبدّل البروفايل';

  @override
  String get profile_btn_cancel => 'إلغاء';

  @override
  String get profile_btn_continue => 'متابعه';

  @override
  String get profile_persona_convert_badge => 'تحويل';

  @override
  String profile_convert_to(String persona) {
    return 'تحوّل لـ $persona؟';
  }

  @override
  String profile_convert_confirm_body(String fromPersona, String toPersona) {
    return 'هتتحوّل من $fromPersona لـ $toPersona. بروفايلك الحالي هيتغيّر.';
  }

  @override
  String get profile_tab_posts => 'البوستات';

  @override
  String get profile_tab_replies => 'الردود';

  @override
  String get profile_tab_liked => 'اللي عجبني';

  @override
  String get profile_tab_reposts => 'إعادات النشر';

  @override
  String get profile_tab_activity => 'النشاط';

  @override
  String get profile_empty_no_activity => 'مفيش نشاط لسه';

  @override
  String get profile_empty_no_posts => 'مفيش بوستات لسه';

  @override
  String get profile_empty_no_replies => 'مفيش ردود لسه';

  @override
  String get profile_empty_no_liked => 'مفيش بوستات عجبتك لسه';

  @override
  String get profile_empty_no_reposts => 'مفيش إعادات نشر لسه';

  @override
  String get profile_empty_no_sports => 'ما اضفتش رياضات لسه';

  @override
  String get profile_error_failed_load_posts => 'مقدرناش نحمل البوستات.';

  @override
  String profile_post_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بوستات',
      one: 'بوست',
    );
    return '$_temp0';
  }

  @override
  String profile_follower_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'متابعين',
      one: 'متابِع',
    );
    return '$_temp0';
  }

  @override
  String get profile_following_label => 'بيتابع';

  @override
  String get profile_takedown_title => 'المحتوى اتشال';

  @override
  String get profile_takedown_body =>
      'المحتوى ده اتشال لأنه بيخالف قواعد المجتمع عندنا.';

  @override
  String get user_profile_error_not_found_title => 'البروفايل مش موجود';

  @override
  String get user_profile_error_unable_to_load => 'مقدرناش نحمل البروفايل';

  @override
  String get user_profile_btn_go_back => 'ارجع';

  @override
  String get user_profile_btn_loading => 'بيتحمّل';

  @override
  String get user_profile_btn_unblock => 'فك الحظر';

  @override
  String get user_profile_btn_follow => 'تابع';

  @override
  String get user_profile_btn_following => 'بتتابعه';

  @override
  String get user_profile_age_suffix => 'سنة';

  @override
  String get user_profile_stat_games => 'ماتشات';

  @override
  String get user_profile_stat_win_rate => 'نسبة الفوز';

  @override
  String get user_profile_stat_sports => 'الرياضات';

  @override
  String get user_profile_stat_reliability => 'الالتزام';

  @override
  String get user_profile_stat_activity => 'النشاط';

  @override
  String get user_profile_stat_last_play => 'آخر ماتش';

  @override
  String get user_profile_block_dialog_title => 'حظر المستخدم';

  @override
  String get user_profile_block_dialog_body =>
      'متأكد إنك عايز تحظر المستخدم ده؟ مش هيقدر يشوف بروفايلك أو يكلّمك.';

  @override
  String get user_profile_block_btn_block => 'احظر';

  @override
  String get user_profile_blocked_snack => 'تم حظر المستخدم';

  @override
  String get user_profile_unblocked_snack => 'تم فك الحظر';

  @override
  String get user_profile_menu_unblock_user => 'فك حظر المستخدم';

  @override
  String get user_profile_menu_block_user => 'احظر المستخدم';

  @override
  String get user_profile_menu_report_user => 'بلّغ عن المستخدم';

  @override
  String get user_profile_cannot_message_blocked => 'مقدرش تراسل مستخدم محظور';

  @override
  String get notif_signin_required => 'سجّل دخولك عشان تشوف الإشعارات';

  @override
  String get notif_title_notifications => 'الإشعارات';

  @override
  String get notif_title_activity_log => 'سجل النشاط';

  @override
  String get notif_chip_all => 'الكل';

  @override
  String get notif_chip_games => 'ماتشات';

  @override
  String get notif_chip_bookings => 'حجوزات';

  @override
  String get notif_chip_social => 'سوشيال';

  @override
  String get notif_chip_achievements => 'إنجازات';

  @override
  String get notif_chip_you => 'إنت';

  @override
  String get notif_chip_rewards => 'مكافآت';

  @override
  String get notif_chip_security => 'الأمان';

  @override
  String get notif_section_today => 'النهارده';

  @override
  String get notif_section_yesterday => 'إمبارح';

  @override
  String get notif_section_earlier => 'قبل كده';

  @override
  String get notif_mark_all_read => 'علّم الكل كمقروء';

  @override
  String get notif_action_respond => 'رد';

  @override
  String get notif_action_follow_back => 'تابعه أنت كمان';

  @override
  String get notif_action_view => 'اعرض';

  @override
  String get notif_action_see_circle => 'شوف الـ Circle';

  @override
  String get notif_load_older => 'حمّل أقدم';

  @override
  String get notif_empty_no_notifications => 'مفيش إشعارات لسه';

  @override
  String get notif_empty_subtitle => 'هنبلّغك لما يحصل أي حاجة';

  @override
  String get notif_btn_retry => 'حاول تاني';

  @override
  String notif_error_prefix(String message) {
    return 'خطأ: $message';
  }

  @override
  String get activity_last_7_days => 'آخر ٧ أيام';

  @override
  String get activity_search_hint => 'دوّر في النشاط…';

  @override
  String get activity_pill_upcoming => 'قريّب';

  @override
  String get activity_pill_live => 'لايڤ';

  @override
  String get activity_subject_reward => 'مكافأة';

  @override
  String get activity_subject_security => 'الأمان';

  @override
  String get activity_all_normal_title => 'كل النشاط طبيعي';

  @override
  String get activity_all_normal_body =>
      'مفيش تسجيلات دخول غريبة أو تغييرات في الأجهزة في آخر ٣٠ يوم. ';

  @override
  String get activity_manage_devices => 'إدارة الأجهزة ←';

  @override
  String get activity_empty_no_activity => 'مفيش نشاط لسه';

  @override
  String get activity_empty_subtitle => 'نشاطك هيظهر هنا';

  @override
  String get activity_day_streak => 'يوم متواصل';

  @override
  String activity_participants_count(int count) {
    return '$count مشارك';
  }

  @override
  String get time_just_now => 'دلوقتي';

  @override
  String time_minutes_ago(int n) {
    return 'من $nد';
  }

  @override
  String time_hours_ago(int n) {
    return 'من $nس';
  }

  @override
  String time_days_ago(int n) {
    return 'من $nي';
  }

  @override
  String notif_kind_friend_requested(String actor) {
    return '$actor بعتلك طلب صداقة';
  }

  @override
  String get notif_kind_friend_requested_anon => 'عندك طلب صداقة جديد';

  @override
  String notif_kind_friend_accepted(String actor) {
    return '$actor قبل طلب الصداقة';
  }

  @override
  String get notif_kind_friend_accepted_anon => 'طلب الصداقة بتاعك اتقبل';

  @override
  String notif_kind_social_followed(String actor) {
    return '$actor بدأ يتابعك';
  }

  @override
  String get notif_kind_social_followed_anon => 'عندك متابع جديد';

  @override
  String notif_kind_social_circle_joined(String actor) {
    return '$actor انضم لـ Circle بتاعك';
  }

  @override
  String get notif_kind_social_circle_joined_anon => 'حد انضم لـ Circle بتاعك';

  @override
  String notif_kind_social_post_liked(String actor) {
    return '$actor عجبه بوستك';
  }

  @override
  String get notif_kind_social_post_liked_anon => 'حد عجبه بوستك';

  @override
  String notif_kind_social_post_commented(String actor) {
    return '$actor علّق على بوستك';
  }

  @override
  String get notif_kind_social_post_commented_anon => 'تعليق جديد على بوستك';

  @override
  String notif_kind_social_comment_liked(String actor) {
    return '$actor عجبه تعليقك';
  }

  @override
  String get notif_kind_social_comment_liked_anon => 'حد عجبه تعليقك';

  @override
  String notif_kind_social_mentioned(String actor) {
    return '$actor منشن عليك';
  }

  @override
  String get notif_kind_social_mentioned_anon => 'اتعمل منشن عليك';

  @override
  String notif_kind_game_invited(String actor) {
    return '$actor دعاك لماتش';
  }

  @override
  String get notif_kind_game_invited_anon => 'عندك دعوة ماتش جديدة';

  @override
  String get notif_kind_game_updated => 'تفاصيل الماتش اتغيرت';

  @override
  String notif_kind_game_join_request(String actor) {
    return '$actor طلب ينضم لماتشك';
  }

  @override
  String get notif_kind_game_join_request_anon => 'حد طلب ينضم لماتشك';

  @override
  String get notif_kind_game_waitlist_promoted => 'أنت داخل! اتفتح مكان';

  @override
  String get notif_kind_game_reminder => 'تذكير بالماتش';

  @override
  String get notif_kind_arena_payment_required => 'محتاج تدفع لحجزك';

  @override
  String get notif_kind_reward_badge_awarded => 'حصلت على بادج جديد';

  @override
  String get notif_kind_achievement_earned => 'فتحت إنجاز جديد';
}
