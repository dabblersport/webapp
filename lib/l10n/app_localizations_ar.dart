// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get games_browse_empty_title => 'لا توجد مباريات عامة حاليًا';

  @override
  String get games_browse_empty_desc => 'عاود الزيارة لاحقًا.';

  @override
  String get games_browse_error => 'تعذّر تحميل المباريات العامة.';

  @override
  String get my_games_empty_title => 'لم تنضم إلى أي مباراة بعد';

  @override
  String get my_games_empty_desc => 'انضم إلى مباراة عامة لتظهر هنا.';

  @override
  String get error_generic => 'حدث خطأ ما';

  @override
  String get game_full => 'اكتمل عدد اللاعبين';

  @override
  String get game_waitlisted => 'أنت في قائمة الانتظار';

  @override
  String get pull_to_refresh => 'اسحب للتحديث';

  @override
  String get rating_thanks => 'شكرًا على تقييمك!';

  @override
  String get rating_submit_error => 'تعذّر إرسال التقييم.';

  @override
  String get venues_search_disabled_mvp => 'البحث غير متاح في هذا الإصدار';

  @override
  String get tab_most_recent => 'لك';

  @override
  String get tab_following => 'أتابعهم';

  @override
  String get tab_nearby => 'بالقرب';

  @override
  String get tab_active => 'نشط';

  @override
  String get tab_news => 'أخبار';

  @override
  String get feed_empty_no_posts => 'لا توجد منشورات بعد';

  @override
  String get feed_empty_no_posts_hint => 'شارك لحظاتك ومبارياتك مع مجتمعك.';

  @override
  String get feed_could_not_load => 'تعذّر تحميل الخلاصة';

  @override
  String get feed_retry => 'أعد المحاولة';

  @override
  String get news_empty_title => 'لا توجد أخبار حاليًا.';

  @override
  String get news_empty_hint => 'عاود الزيارة لاحقًا لأحدث مستجدات فريق دابلر.';

  @override
  String get news_hide_sheet_title => 'إخفاء الأخبار من الخلاصة؟';

  @override
  String get news_hide_sheet_body =>
      'لن تظهر بطاقات الأخبار في «لك». يمكنك قراءة كل الأخبار في تبويب الأخبار.';

  @override
  String get news_hide_confirm => 'أخفِ الأخبار';

  @override
  String get news_hide_cancel => 'إلغاء';

  @override
  String get news_hidden_snack => 'تم إخفاء الأخبار من «لك»';

  @override
  String get news_resubscribed_snack => 'ستظهر الأخبار من جديد في «لك»';

  @override
  String get news_resubscribe_banner => 'الأخبار مخفية من «لك».';

  @override
  String get news_resubscribe_action => 'أظهرها من جديد';

  @override
  String get auth_welcome_title => 'أهلًا بك!';

  @override
  String get auth_welcome_subtitle =>
      'يسعدنا انضمامك إلينا. أنشئ حسابًا وابدأ اللعب مع مجتمعك الرياضي.';

  @override
  String get auth_welcome_trust_heading => 'مبني على الثقة';

  @override
  String get auth_welcome_trust_verified =>
      'لاعبون موثوقون، وعضويات معتمدة، وملاعب مقيَّمة';

  @override
  String get auth_welcome_trust_personalised =>
      'توصيات وتواصل مخصّصان لرياضاتك المفضلة';

  @override
  String get auth_welcome_trust_privacy =>
      'لا نبيع بياناتك — الخصوصية أولًا في تصميمنا';

  @override
  String get auth_welcome_get_started => 'لنبدأ';

  @override
  String get auth_welcome_get_started_subtitle => 'أنشئ حسابًا أو سجّل دخولك';

  @override
  String get auth_welcome_btn_google => 'المتابعة عبر Google';

  @override
  String get auth_welcome_btn_apple => 'المتابعة عبر Apple';

  @override
  String get auth_welcome_btn_email => 'المتابعة بالبريد الإلكتروني';

  @override
  String get auth_welcome_btn_login => 'لديك حساب بالفعل؟ سجّل دخولك';

  @override
  String get auth_welcome_apple_soon => 'تسجيل الدخول عبر Apple قادم قريبًا.';

  @override
  String auth_welcome_google_error(String error) {
    return 'تعذّر تسجيل الدخول عبر Google: $error';
  }

  @override
  String get auth_welcome_country_picker_title => 'اختر بلدك';

  @override
  String get auth_welcome_language_picker_title => 'اختر اللغة';

  @override
  String get landing_quote1 => 'وعدت نفسي أن ألعب مرتين في الأسبوع على الأقل.';

  @override
  String get landing_quote2 =>
      'بين العمل والحياة، إيجاد مباراة أصعب من جري تسعين دقيقة.';

  @override
  String get landing_tagline =>
      'يربط دابلر اللاعبين والكباتن والملاعب، فتتوقف عن البحث وتبدأ اللعب';

  @override
  String get landing_continue => 'المتابعة';

  @override
  String get landing_choose_language => 'اختر اللغة';

  @override
  String get auth_already_have_account => 'لديك حساب بالفعل؟';

  @override
  String get auth_log_in => 'سجّل دخولك';

  @override
  String get auth_new_here => 'مستخدم جديد؟';

  @override
  String get auth_create_account => 'إنشاء حساب';

  @override
  String get auth_sheet_done => 'تم';

  @override
  String get auth_sheet_got_it => 'فهمت';

  @override
  String get auth_back => 'رجوع';

  @override
  String get landing_dc_tagline =>
      'دابلر يجمع اللاعبين والمنظّمين والملاعب، لتتوقف عن البحث وتبدأ باللعب.';

  @override
  String get landing_dc_continue => 'المتابعة';

  @override
  String get landing_vignette_marcus_quote =>
      'نصف مجموعة الدردشة غير ملتزم، والنصف الآخر يغيّر رأيه بحلول الجمعة.';

  @override
  String get landing_vignette_marcus_want =>
      'أريد فقط مكانًا واحدًا لتنظيم مباراة خماسية دون ملاحقة الردود.';

  @override
  String get landing_vignette_aisha_quote =>
      'مدينة جديدة، قدم يسرى جيدة، ولا أحد أمرّر له.';

  @override
  String get landing_vignette_aisha_want =>
      'أريد مباراة هذا الأسبوع، لا محادثة جماعية عن مباراة.';

  @override
  String get landing_vignette_priya_quote => 'أتابع بادل أكثر مما لعبته فعلًا.';

  @override
  String get landing_vignette_priya_want => 'أرني من يلعب قربي وسأجد طريقي.';

  @override
  String get landing_vignette_sevens_quote =>
      'ثلاثة ملاعب فارغة عند التاسعة مساءً ولا أحد يعلم.';

  @override
  String get landing_vignette_sevens_want =>
      'ضع ملاعبي أمام لاعبين يبحثون عن ملعب أصلًا.';

  @override
  String get auth_entry_title => 'هيّا نلعب';

  @override
  String get auth_entry_subtitle => 'حساب واحد للمباريات والفِرق والملاعب.';

  @override
  String get auth_entry_trust_verified =>
      'لاعبون موثوقون، ملاعب موثّقة، مباريات مقيّمة';

  @override
  String get auth_entry_trust_personalised =>
      'مباريات وأشخاص مختارون حسب رياضاتك';

  @override
  String get auth_entry_trust_privacy => 'لا نبيع بياناتك. الخصوصية أولًا';

  @override
  String get auth_entry_continue_email => 'المتابعة بالبريد الإلكتروني';

  @override
  String get auth_entry_continue_google => 'المتابعة عبر Google';

  @override
  String get auth_entry_continue_apple => 'المتابعة عبر Apple';

  @override
  String get auth_legal_prefix => 'بالمتابعة، فإنك توافق على ';

  @override
  String get auth_legal_terms => 'شروط الخدمة';

  @override
  String get auth_legal_and => ' و';

  @override
  String get auth_legal_privacy => 'سياسة الخصوصية';

  @override
  String get auth_sheet_language => 'اللغة';

  @override
  String get auth_sheet_region => 'المنطقة';

  @override
  String get auth_email_title => 'ما بريدك الإلكتروني؟';

  @override
  String get auth_email_subtitle =>
      'سنرسل لك رمزًا. وإن سبق أن زرتنا، سنكمل من حيث توقفت.';

  @override
  String get auth_email_label => 'البريد الإلكتروني';

  @override
  String get auth_email_placeholder => 'you@email.com';

  @override
  String get auth_email_marketing =>
      'أبقِني على اطلاع بالمباريات والمزايا القريبة مني';

  @override
  String get auth_email_send_code => 'أرسل لي رمزًا';

  @override
  String get auth_email_invalid => 'هذا لا يبدو كعنوان بريد إلكتروني.';

  @override
  String get auth_login_title => 'أهلًا بعودتك';

  @override
  String get auth_login_subtitle =>
      'سجّل دخولك بالطريقة التي تناسبك — كلمة مرور، أو رمز لمرة واحدة، أو حساب مرتبط.';

  @override
  String get auth_login_password_label => 'كلمة المرور';

  @override
  String get auth_login_password_placeholder => 'كلمة مرورك';

  @override
  String get auth_login_button => 'تسجيل الدخول';

  @override
  String get auth_login_email_code => 'أرسل لي رمزًا بدلًا من ذلك';

  @override
  String get auth_login_password_wrong =>
      'كلمة المرور غير مطابقة. حاول مجددًا، أو أرسل لنفسك رمزًا.';

  @override
  String get auth_otp_title => 'تحقق من بريدك الإلكتروني';

  @override
  String get auth_otp_subtitle =>
      'أرسلنا رمزًا من 6 أرقام إلى بريدك الإلكتروني.';

  @override
  String get auth_otp_change => 'تغيير';

  @override
  String get auth_otp_invalid =>
      'هذا الرمز غير صحيح. تحقق من البريد وحاول مرة أخرى.';

  @override
  String get auth_otp_expired => 'انتهت صلاحية هذا الرمز. أرسل رمزًا جديدًا.';

  @override
  String get auth_otp_resend => 'أرسل رمزًا جديدًا';

  @override
  String auth_otp_resend_in(int seconds) {
    return 'أرسل رمزًا جديدًا خلال $secondsث';
  }

  @override
  String get auth_otp_continue => 'المتابعة';

  @override
  String auth_welcome_back_title(String name) {
    return 'أهلًا بعودتك، $name';
  }

  @override
  String get auth_welcome_continue => 'المتابعة';

  @override
  String get auth_welcome_list_title => 'لا تنسَ';

  @override
  String get persona_player_name => 'اللاعب';

  @override
  String get persona_player_headline => 'أنت جاهز. هيّا نلعب.';

  @override
  String get persona_player_principle => 'احضر، العب بنزاهة، وابنِ سمعتك.';

  @override
  String get persona_player_list_title => 'لا تنسَ';

  @override
  String get persona_player_item1 => 'أكّد فقط حين تعرف أنك تستطيع اللعب.';

  @override
  String get persona_player_item2 => 'احترم قواعد المنظّم وموعد البداية.';

  @override
  String get persona_player_item3 => 'الحضور هو ما يبني سمعتك.';

  @override
  String get persona_player_cta => 'ابحث عن مباراتي الأولى';

  @override
  String get persona_organiser_name => 'المنظّم';

  @override
  String get persona_organiser_headline => 'حان وقت جمع المباراة.';

  @override
  String get persona_organiser_principle => 'تبدأ المباريات الجيدة بتنظيم جيد.';

  @override
  String get persona_organiser_list_title => 'ما يتوقعه اللاعبون';

  @override
  String get persona_organiser_item1 =>
      'تفاصيل دقيقة — الملعب والوقت والمستوى والسعر.';

  @override
  String get persona_organiser_item2 =>
      'تغييرات تُشارَك مبكرًا لا عند الانطلاق.';

  @override
  String get persona_organiser_item3 => 'حضور يُدار بإنصاف في كل مرة.';

  @override
  String get persona_organiser_cta => 'أنشئ مباراتي الأولى';

  @override
  String get persona_host_name => 'المضيف';

  @override
  String get persona_host_headline => 'ملعبك على الخريطة.';

  @override
  String get persona_host_principle => 'الملاعب الرائعة تجعل اللعب سهلًا.';

  @override
  String get persona_host_list_title => 'ما يتوقعه اللاعبون';

  @override
  String get persona_host_item1 => 'توفّر يطابق الواقع.';

  @override
  String get persona_host_item2 => 'أسعار ومرافق محدّثة دائمًا.';

  @override
  String get persona_host_item3 => 'حجوزات يُوفى بها — وهذا ما يعيدهم.';

  @override
  String get persona_host_cta => 'جهّز ملعبي';

  @override
  String get persona_socialiser_name => 'الاجتماعي';

  @override
  String get persona_socialiser_headline => 'دائرتك الرياضية تبدأ من هنا.';

  @override
  String get persona_socialiser_principle =>
      'تابع ما تحب، وتعرّف على رفاقك، وانضم حين يناسبك.';

  @override
  String get persona_socialiser_list_title => 'كيف يعمل هذا';

  @override
  String get persona_socialiser_item1 =>
      'تابع الرياضات والأشخاص الذين تهتم بهم فعلًا.';

  @override
  String get persona_socialiser_item2 =>
      'شارك في الحوار قبل أن تشارك في المباراة.';

  @override
  String get persona_socialiser_item3 =>
      'كن ودودًا، فكل من هنا هو زميل فريق لشخص ما.';

  @override
  String get persona_socialiser_cta => 'ابدأ الاستكشاف';

  @override
  String get auth_or => 'أو';

  @override
  String get email_input_title => 'المصادقة';

  @override
  String get email_input_subtitle => 'أدخل بريدك الإلكتروني للبدء';

  @override
  String get email_input_label => 'البريد الإلكتروني';

  @override
  String get email_input_hint => 'email@domain.com';

  @override
  String get email_input_continue => 'المتابعة';

  @override
  String get email_input_keep_in_loop =>
      'أبقِني على اطلاع بالتحديثات والمزيد عبر البريد';

  @override
  String get email_input_already_account => 'لديك حساب بالفعل؟ سجّل الدخول';

  @override
  String get email_input_btn_google => 'المتابعة عبر Google';

  @override
  String get email_input_btn_apple => 'المتابعة عبر Apple';

  @override
  String get email_input_terms_prefix =>
      'بالنقر على «المتابعة»، فإنك تقرّ بأنك قرأت ووافقت على ';

  @override
  String get email_input_terms_link => 'شروط الخدمة';

  @override
  String get email_input_terms_and => ' و';

  @override
  String get email_input_privacy_link => 'سياسة الخصوصية';

  @override
  String get email_input_validate_required => 'البريد الإلكتروني مطلوب';

  @override
  String get email_input_validate_invalid => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get email_input_error_generic => 'حدث خطأ. يرجى المحاولة مرة أخرى.';

  @override
  String get email_input_google_failed =>
      'فشل تسجيل الدخول عبر Google. يرجى المحاولة مرة أخرى.';

  @override
  String get email_password_title => 'تسجيل الدخول';

  @override
  String get email_password_subtitle =>
      'أدخل بريدك الإلكتروني وكلمة المرور\nأو سجّل الدخول برمز التحقق';

  @override
  String get email_password_forgot => 'نسيت كلمة المرور؟';

  @override
  String get email_password_send_otp => 'أرسل رمز التحقق إلى بريدي';

  @override
  String get email_password_login_btn => 'تسجيل الدخول';

  @override
  String get email_password_btn_google => 'المتابعة عبر Google';

  @override
  String get email_password_btn_apple => 'المتابعة عبر Apple';

  @override
  String get email_password_hint_email => 'email@domain.com';

  @override
  String get email_password_hint_password => 'كلمة المرور';

  @override
  String get email_password_show_password => 'إظهار كلمة المرور';

  @override
  String get email_password_hide_password => 'إخفاء كلمة المرور';

  @override
  String get email_password_validate_email_required =>
      'البريد الإلكتروني مطلوب';

  @override
  String get email_password_validate_email_invalid =>
      'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get email_password_validate_password_required => 'أدخل كلمة المرور';

  @override
  String get email_password_error_invalid_creds =>
      'البريد الإلكتروني أو كلمة المرور غير صحيحة';

  @override
  String get email_password_error_login_failed => 'فشل تسجيل الدخول.';

  @override
  String get email_password_error_otp_failed =>
      'تعذّر إرسال رمز التحقق. يرجى المحاولة مرة أخرى.';

  @override
  String get email_password_apple_soon => 'تسجيل الدخول عبر Apple قادم قريبًا.';

  @override
  String get email_password_google_failed => 'فشل تسجيل الدخول عبر Google.';

  @override
  String get email_password_validate_email_hint =>
      'أدخل بريدًا إلكترونيًا صالحًا.';

  @override
  String get email_verify_appbar => 'تأكيد البريد الإلكتروني';

  @override
  String get email_verify_title => 'تحقق من صندوق الوارد';

  @override
  String email_verify_body_with_email(String email) {
    return 'أرسلنا رابط تأكيد إلى $email.\n\nيرجى تأكيد بريدك الإلكتروني لإكمال إنشاء حسابك.';
  }

  @override
  String get email_verify_body_no_email =>
      'أرسلنا رابط تأكيد إلى بريدك الإلكتروني.\n\nيرجى تأكيد بريدك الإلكتروني لإكمال إنشاء حسابك.';

  @override
  String get email_verify_instruction =>
      'بعد تأكيد بريدك الإلكتروني، عد إلى التطبيق واضغط «أكّدت بريدي الإلكتروني» للمتابعة.';

  @override
  String get email_verify_confirmed_btn => 'أكّدت بريدي الإلكتروني';

  @override
  String get email_verify_resend_btn => 'أعد إرسال رسالة التأكيد';

  @override
  String get email_verify_different_account => 'استخدم حسابًا آخر';

  @override
  String get email_verify_no_email_error =>
      'لا يوجد بريد إلكتروني للمستخدم الحالي.';

  @override
  String get email_verify_spam_note =>
      'إن لم تجد الرسالة، تحقق من مجلد البريد المزعج أو اطلب رابطًا جديدًا من شاشة تسجيل الدخول.';

  @override
  String get forgot_password_title => 'إعادة تعيين كلمة المرور';

  @override
  String get forgot_password_subtitle =>
      'أدخل بريدك الإلكتروني وسنرسل إليك رابطًا لإعادة تعيين كلمة المرور.';

  @override
  String get forgot_password_email_hint => 'البريد الإلكتروني';

  @override
  String get forgot_password_send_btn => 'أرسل رابط إعادة التعيين';

  @override
  String get forgot_password_sent_msg =>
      'تم إرسال الرابط! تحقق من صندوق الوارد ومجلد البريد المزعج لمعرفة خطوات إعادة تعيين كلمة المرور.';

  @override
  String get forgot_password_back_to_signin => 'العودة إلى تسجيل الدخول';

  @override
  String get forgot_password_validate_email => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get otp_verify_title_email => 'تأكيد البريد الإلكتروني';

  @override
  String get otp_verify_title_phone => 'تأكيد رقم الهاتف';

  @override
  String get otp_verify_subtitle_email =>
      'أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى بريدك الإلكتروني';

  @override
  String get otp_verify_subtitle_phone =>
      'أدخل الرمز المكوّن من 6 أرقام الذي أرسلناه إلى هاتفك';

  @override
  String get otp_verify_change_email => 'تغيير البريد الإلكتروني';

  @override
  String get otp_verify_change_phone => 'تغيير رقم الهاتف';

  @override
  String get otp_verify_continue => 'المتابعة';

  @override
  String get otp_verify_didnt_get => 'لم يصلك الرمز؟ ';

  @override
  String otp_verify_resend_countdown(int seconds) {
    return 'أعد إرسال الرمز ($secondsث)';
  }

  @override
  String get otp_verify_resend => 'أعد إرسال الرمز';

  @override
  String get otp_verify_sending => 'جارٍ الإرسال...';

  @override
  String get otp_verify_sent_email =>
      'تم إرسال رمز التحقق إلى بريدك الإلكتروني بنجاح';

  @override
  String get otp_verify_sent_phone => 'تم إرسال رمز التحقق إلى هاتفك بنجاح';

  @override
  String otp_verify_error_prefix(String error) {
    return 'خطأ: $error';
  }

  @override
  String get reset_password_title => 'إعادة تعيين كلمة المرور';

  @override
  String get reset_password_subtitle => 'أنشئ كلمة مرور جديدة لحسابك';

  @override
  String get reset_password_new_label => 'كلمة المرور الجديدة';

  @override
  String get reset_password_confirm_label => 'تأكيد كلمة المرور';

  @override
  String get reset_password_update_btn => 'تحديث كلمة المرور';

  @override
  String get reset_password_validate_enter => 'أدخل كلمة مرور';

  @override
  String get reset_password_validate_min => 'استخدم 8 أحرف على الأقل';

  @override
  String get reset_password_validate_confirm => 'أعد إدخال كلمة المرور';

  @override
  String get reset_password_validate_match => 'كلمتا المرور غير متطابقتين';

  @override
  String get set_password_title => 'أنشئ حسابك';

  @override
  String set_password_email_prefix(String email) {
    return 'البريد الإلكتروني: $email';
  }

  @override
  String get set_password_username_label => 'المعرّف';

  @override
  String get set_password_username_hint => 'اختر معرّفًا فريدًا';

  @override
  String get set_password_password_label => 'كلمة المرور';

  @override
  String get set_password_password_hint => 'أدخل كلمة مرور قوية';

  @override
  String get set_password_confirm_label => 'تأكيد كلمة المرور';

  @override
  String get set_password_confirm_hint => 'أعد إدخال كلمة المرور';

  @override
  String get set_password_create_btn => 'إنشاء الحساب';

  @override
  String get set_password_creating_btn => 'جارٍ إنشاء الحساب...';

  @override
  String set_password_wait_btn(int seconds) {
    return 'انتظر $seconds ث';
  }

  @override
  String get set_password_validate_username_required => 'المعرّف مطلوب';

  @override
  String get set_password_validate_username_min =>
      'يجب أن يتكون المعرّف من 3 أحرف على الأقل';

  @override
  String get set_password_validate_username_max =>
      'يجب ألا يزيد المعرّف على 20 حرفًا';

  @override
  String get set_password_validate_username_chars =>
      'يُسمح بالحروف والأرقام والشرطة السفلية فقط';

  @override
  String get set_password_validate_username_taken =>
      'هذا المعرّف مستخدم بالفعل';

  @override
  String get set_password_validate_username_checking =>
      'خطأ في التحقق من المعرّف';

  @override
  String get set_password_validate_password_required => 'كلمة المرور مطلوبة';

  @override
  String get set_password_validate_password_min =>
      'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل';

  @override
  String get set_password_validate_confirm_required => 'يرجى تأكيد كلمة المرور';

  @override
  String get set_password_validate_confirm_match =>
      'كلمتا المرور غير متطابقتين';

  @override
  String get set_password_wait_validation =>
      'انتظر حتى ينتهي التحقق من المعرّف';

  @override
  String get set_password_account_exists =>
      'الحساب موجود بالفعل. سجّل الدخول بكلمة المرور.';

  @override
  String get set_password_rate_limit => 'انتظر بضع ثوانٍ ثم حاول مرة أخرى.';

  @override
  String set_password_error_prefix(String error) {
    return 'خطأ: $error';
  }

  @override
  String get create_info_title => 'أخبرنا قليلًا عن نفسك';

  @override
  String get create_info_subtitle =>
      'أكّد عمرك؛ يجب أن يكون عمرك 16 عامًا أو أكثر لاستخدام دابلر';

  @override
  String get create_info_birth_date => 'تاريخ الميلاد';

  @override
  String get create_info_birth_date_placeholder => 'اختر تاريخ ميلادك';

  @override
  String create_info_age_display(int age) {
    return 'عمرك $age سنة';
  }

  @override
  String get create_info_gender => 'الجنس (اختياري)';

  @override
  String get create_info_continue => 'المتابعة';

  @override
  String get create_info_error_fill_required =>
      'يرجى تعبئة جميع الحقول المطلوبة بشكل صحيح';

  @override
  String get create_info_error_select_birth => 'يرجى اختيار تاريخ ميلادك';

  @override
  String get create_info_error_min_age =>
      'يجب أن يكون عمرك 16 عامًا على الأقل للتسجيل';

  @override
  String create_info_error_max_age(int max) {
    return 'يجب أن يكون العمر بين 16 و$max عامًا';
  }

  @override
  String get create_info_error_select_gender => 'يرجى اختيار الجنس';

  @override
  String create_info_error_occurred(String error) {
    return 'حدث خطأ: $error';
  }

  @override
  String get set_username_title_onboarding => 'عرّف بنفسك';

  @override
  String get set_username_title_conversion => 'أكمل التحويل';

  @override
  String get set_username_title_new_profile => 'أكمل ملفك الشخصي الجديد';

  @override
  String get set_username_subtitle_onboarding =>
      'اختر كيف يناديك الآخرون وحدّد معرّفك';

  @override
  String set_username_subtitle_persona(String persona) {
    return 'اختر اسمًا ظاهرًا ومعرّفًا لملفك بصفة $persona';
  }

  @override
  String get set_username_display_name_label => 'الاسم الظاهر';

  @override
  String get set_username_display_name_hint => 'أدخل اسمك الظاهر';

  @override
  String get set_username_username_label => 'المعرّف';

  @override
  String get set_username_username_hint => 'اختر معرّفًا فريدًا';

  @override
  String get set_username_suggestions => 'مقترحات';

  @override
  String get set_username_btn_complete => 'إتمام';

  @override
  String get set_username_btn_create_profile => 'إنشاء الملف الشخصي';

  @override
  String get set_username_btn_complete_conversion => 'أكمل التحويل';

  @override
  String get set_username_back => 'رجوع';

  @override
  String set_username_converting_to(String persona) {
    return 'جارٍ التحويل إلى $persona';
  }

  @override
  String set_username_adding_profile(String persona) {
    return 'جارٍ إضافة ملف $persona';
  }

  @override
  String get set_username_validate_display_required => 'الاسم الظاهر مطلوب';

  @override
  String get set_username_validate_display_min =>
      'يجب أن يتكون الاسم الظاهر من حرفين على الأقل';

  @override
  String get set_username_validate_username_required => 'المعرّف مطلوب';

  @override
  String get set_username_validate_username_min =>
      'يجب أن يتكون المعرّف من 3 أحرف على الأقل';

  @override
  String get set_username_validate_username_chars =>
      'الحروف والأرقام والشرطة السفلية فقط';

  @override
  String get set_username_unavailable => 'المعرّف غير متاح';

  @override
  String get set_username_check_error => 'خطأ في التحقق من المعرّف';

  @override
  String get set_username_missing_onboarding =>
      'بيانات التسجيل ناقصة. ابدأ من جديد.';

  @override
  String get set_username_missing_steps =>
      'معلومات مطلوبة ناقصة. يرجى إكمال جميع الخطوات.';

  @override
  String get set_username_session_expired =>
      'انتهت جلستك. يرجى تأكيد رقم هاتفك مرة أخرى.';

  @override
  String get set_username_missing_persona_data => 'بيانات ناقصة. ابدأ من جديد.';

  @override
  String get intent_title => 'ما الذي أتى بك إلى هنا؟';

  @override
  String get intent_subtitle => 'ساعدنا في تخصيص دابلر لك';

  @override
  String get intent_compete_title => 'تنافس';

  @override
  String get intent_compete_desc =>
      'انضم إلى المباريات، وتابع مستواك، والعب بانتظام';

  @override
  String get intent_organise_title => 'نظّم';

  @override
  String get intent_organise_desc =>
      'أنشئ المباريات، وحدّد القواعد، وأدر اللاعبين';

  @override
  String get intent_host_title => 'استضف';

  @override
  String get intent_host_desc => 'أدر الملاعب والتوافر والحجوزات';

  @override
  String get intent_socialise_title => 'تواصل';

  @override
  String get intent_socialise_desc => 'تابع الرياضات والأشخاص والمجتمعات';

  @override
  String get intent_continue => 'المتابعة';

  @override
  String get intent_back => 'رجوع';

  @override
  String get intent_select_role => 'يرجى اختيار دورك';

  @override
  String get interests_title_player => 'ما الرياضات التي تمارسها بانتظام؟';

  @override
  String get interests_title_organiser => 'ما الرياضات التي تنوي تنظيمها؟';

  @override
  String get interests_title_host => 'ما الرياضات التي تستضيفها؟';

  @override
  String get interests_title_socialiser => 'ما الرياضات التي تهمّك؟';

  @override
  String get interests_title_default => 'ما الرياضات التي تمارسها بانتظام؟';

  @override
  String get interests_subtitle => 'يمكنك تغيير الرياضات وإضافة المزيد لاحقًا';

  @override
  String get interests_available_sports => 'الرياضات المتاحة';

  @override
  String interests_selected_count_one(int count) {
    return 'تم اختيار رياضة واحدة ($count)';
  }

  @override
  String interests_selected_count_many(int count) {
    return 'الرياضات المختارة: $count';
  }

  @override
  String get interests_continue => 'المتابعة';

  @override
  String get interests_back => 'رجوع';

  @override
  String get interests_cancel => 'إلغاء';

  @override
  String get interests_select_one => 'يرجى اختيار رياضة واحدة على الأقل';

  @override
  String get interests_failed_load => 'تعذّر تحميل الرياضات';

  @override
  String get interests_retry => 'أعد المحاولة';

  @override
  String get primary_sport_title => 'اختر رياضتك الأساسية';

  @override
  String get primary_sport_subtitle =>
      'ستظهر هذه الرياضة في ملفك الشخصي وتُستخدم افتراضيًا.';

  @override
  String get primary_sport_helper => 'يمكنك تغييرها لاحقًا.';

  @override
  String get primary_sport_badge => 'أساسية';

  @override
  String get primary_sport_continue => 'المتابعة';

  @override
  String get primary_sport_back => 'رجوع';

  @override
  String get primary_sport_cancel => 'إلغاء';

  @override
  String get primary_sport_select_error => 'يرجى اختيار رياضتك الأساسية';

  @override
  String get primary_sport_failed_load => 'تعذّر تحميل الرياضات';

  @override
  String get primary_sport_no_sports => 'لم تُختر أي رياضة. يرجى الرجوع.';

  @override
  String get onb_back => 'رجوع';

  @override
  String get onb_continue => 'المتابعة';

  @override
  String onb_step_label(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get onb_dob_title => 'عرّفنا بنفسك قليلًا';

  @override
  String get onb_dob_subtitle =>
      'عمرك يساعدنا على إبقاء المباريات والمجتمعات مناسبة للأعمار. ولا يظهر في ملفك الشخصي.';

  @override
  String get onb_dob_label => 'تاريخ الميلاد';

  @override
  String get onb_dob_placeholder => 'اختر تاريخ ميلادك';

  @override
  String get onb_dob_helper_min =>
      'يجب أن يكون عمرك 16 عامًا أو أكثر لاستخدام دابلر.';

  @override
  String onb_dob_helper_ok(int age) {
    return 'العمر $age. كل شيء جاهز.';
  }

  @override
  String get onb_dob_error_min => 'يجب أن يكون عمرك 16 عامًا أو أكثر.';

  @override
  String onb_dob_error_max(int max) {
    return 'يجب أن يكون العمر بين 16 و$max عامًا.';
  }

  @override
  String get onb_gender_label => 'الجنس (اختياري)';

  @override
  String get onb_gender_male => 'ذكر';

  @override
  String get onb_gender_female => 'أنثى';

  @override
  String get onb_dob_sheet_confirm => 'تأكيد';

  @override
  String get onb_dob_sheet_cancel => 'إلغاء';

  @override
  String get onb_day => 'اليوم';

  @override
  String get onb_month => 'الشهر';

  @override
  String get onb_year => 'السنة';

  @override
  String get onb_month_1 => 'يناير';

  @override
  String get onb_month_2 => 'فبراير';

  @override
  String get onb_month_3 => 'مارس';

  @override
  String get onb_month_4 => 'أبريل';

  @override
  String get onb_month_5 => 'مايو';

  @override
  String get onb_month_6 => 'يونيو';

  @override
  String get onb_month_7 => 'يوليو';

  @override
  String get onb_month_8 => 'أغسطس';

  @override
  String get onb_month_9 => 'سبتمبر';

  @override
  String get onb_month_10 => 'أكتوبر';

  @override
  String get onb_month_11 => 'نوفمبر';

  @override
  String get onb_month_12 => 'ديسمبر';

  @override
  String get onb_persona_title => 'لماذا أنت هنا؟';

  @override
  String get onb_persona_subtitle =>
      'اختر ما يناسبك اليوم. يمكنك إضافة غيره لاحقًا.';

  @override
  String get onb_persona_footnote =>
      'يمكنك إضافة طريقة أخرى لاستخدام دابلر لاحقًا من الإعدادات.';

  @override
  String get onb_persona_socialiser_name => 'الاجتماعي';

  @override
  String get onb_persona_socialiser_hook => 'اعثر على رفاقك';

  @override
  String get onb_persona_socialiser_body =>
      'تابع الرياضات، اكتشف المجتمعات، وابقَ على اطلاع.';

  @override
  String get onb_sports_title_socialiser => 'ما الذي يهمّك؟';

  @override
  String get onb_sports_subtitle_socialiser =>
      'اختر الرياضات التي تريد رؤية المزيد منها.';

  @override
  String get onb_primary_title_socialiser => 'ما رياضتك المفضلة؟';

  @override
  String get onb_primary_subtitle_socialiser =>
      'سنعرض لك المزيد من المجتمعات والأشخاص والنشاط حولها.';

  @override
  String get onb_persona_player_name => 'اللاعب';

  @override
  String get onb_persona_player_hook => 'انطلق إلى الملعب';

  @override
  String get onb_persona_player_body =>
      'انضم إلى المباريات، ارفع مستواك، والعب أكثر.';

  @override
  String get onb_sports_title_player => 'ما الرياضات التي تلعبها؟';

  @override
  String get onb_sports_subtitle_player =>
      'اختر الرياضات التي تهمّك. يمكنك تغييرها في أي وقت.';

  @override
  String get onb_primary_title_player => 'ما رياضتك المفضلة للعب؟';

  @override
  String get onb_primary_subtitle_player =>
      'سنجعلها الافتراضية ونبني ملف رياضتك الأساسية حولها.';

  @override
  String get onb_persona_organiser_name => 'المنظّم';

  @override
  String get onb_persona_organiser_hook => 'اجمع المباراة';

  @override
  String get onb_persona_organiser_body =>
      'أنشئ المباريات، أدر اللاعبين، ورتّب كل شيء.';

  @override
  String get onb_sports_title_organiser => 'ماذا تنظّم؟';

  @override
  String get onb_sports_subtitle_organiser =>
      'اختر الرياضات التي تنشئ لها المباريات عادةً.';

  @override
  String get onb_primary_title_organiser => 'ما الذي تنظّمه أكثر؟';

  @override
  String get onb_primary_subtitle_organiser =>
      'سنستخدمها افتراضيًا عند إنشاء المباريات والفعاليات.';

  @override
  String get onb_persona_host_name => 'المضيف';

  @override
  String get onb_persona_host_hook => 'املأ ملعبك';

  @override
  String get onb_persona_host_body =>
      'اعرض مساحاتك، وصِل إلى اللاعبين، وأدر الحجوزات.';

  @override
  String get onb_sports_title_host => 'ماذا يمكن للناس أن يلعبوا في ملعبك؟';

  @override
  String get onb_sports_subtitle_host => 'اختر الرياضات التي تستضيفها مساحاتك.';

  @override
  String get onb_primary_title_host => 'بماذا يشتهر ملعبك؟';

  @override
  String get onb_primary_subtitle_host =>
      'سنجعلها الرياضة الأساسية في ملف ملعبك.';

  @override
  String get onb_sports_search => 'ابحث عن رياضة';

  @override
  String get onb_sports_none => 'لا نتائج مطابقة. جرّب اسمًا آخر.';

  @override
  String get onb_sports_count_zero => 'اختر رياضة واحدة على الأقل للمتابعة.';

  @override
  String get onb_sports_count_one => 'تم اختيار رياضة واحدة';

  @override
  String onb_sports_count_many(int count) {
    return 'الرياضات المختارة: $count';
  }

  @override
  String get onb_primary_more => 'أضف المزيد من الرياضات';

  @override
  String get onb_identity_title => 'بماذا يناديك الناس؟';

  @override
  String get onb_identity_subtitle =>
      'اضبط الاسم والمعرّف اللذين سيراهما الناس في دابلر.';

  @override
  String get onb_display_name_label => 'الاسم الظاهر';

  @override
  String get onb_display_name_helper =>
      'هذا هو الاسم الذي يراه الناس في دابلر.';

  @override
  String get onb_suggestions => 'مقترحات';

  @override
  String get onb_username_label => 'المعرّف';

  @override
  String get onb_username_placeholder => '@اسمك';

  @override
  String get onb_username_helper => 'أحرف وأرقام وشرطة سفلية فقط.';

  @override
  String get onb_username_short => 'يحتاج المعرّف إلى 3 أحرف على الأقل.';

  @override
  String get onb_username_invalid => 'أحرف وأرقام وشرطة سفلية فقط.';

  @override
  String get onb_username_checking => 'جارٍ التحقق من التوفر…';

  @override
  String get onb_username_taken => 'هذا المعرّف مستخدم. جرّب غيره.';

  @override
  String get onb_username_available => 'متاح — هذا لك.';

  @override
  String get onb_username_check_error =>
      'تعذّر التحقق من المعرّف. حاول مرة أخرى.';

  @override
  String get onb_create_account => 'إنشاء الحساب';

  @override
  String get onb_setup_title => 'جارٍ إعداد حسابك';

  @override
  String get onb_setup_subtitle => 'يستغرق هذا لحظة فقط.';

  @override
  String get onb_setup_stage_profile => 'إنشاء ملفك الشخصي';

  @override
  String get onb_setup_failed_title => 'لم يكتمل الإعداد';

  @override
  String primary_sport_adding(String label) {
    return 'جارٍ إضافة ملف $label';
  }

  @override
  String get identity_verify_title => 'التحقق من الهوية';

  @override
  String get identity_verify_email_label => 'البريد الإلكتروني';

  @override
  String get identity_verify_email_hint => 'أدخل بريدك الإلكتروني';

  @override
  String get identity_verify_continue_sending => 'جارٍ الإرسال...';

  @override
  String get identity_verify_continue => 'المتابعة';

  @override
  String get identity_verify_or => 'أو';

  @override
  String get identity_verify_google_btn => 'المتابعة عبر Google';

  @override
  String get identity_verify_terms_prefix => 'بالمتابعة، فإنك توافق على ';

  @override
  String get identity_verify_terms_link => 'شروط الخدمة';

  @override
  String get identity_verify_terms_and => ' و';

  @override
  String get identity_verify_privacy_link => 'سياسة الخصوصية';

  @override
  String get identity_verify_otp_sent_email =>
      'تم إرسال رمز التحقق! تحقق من بريدك الإلكتروني.';

  @override
  String get identity_verify_otp_sent_phone =>
      'تم إرسال رمز التحقق! تحقق من هاتفك.';

  @override
  String get identity_verify_phone_disabled =>
      'التحقق عبر الهاتف غير متاح بعد. استخدم البريد الإلكتروني للمتابعة.';

  @override
  String identity_verify_service_error(String error) {
    return 'خطأ في الخدمة: $error';
  }

  @override
  String get identity_verify_error_generic =>
      'تعذّر إرسال رمز التحقق. يرجى المحاولة مرة أخرى.';

  @override
  String identity_verify_nav_failed(String error) {
    return 'فشل الانتقال: $error';
  }

  @override
  String get identity_verify_use_email => 'يرجى استخدام بريدك الإلكتروني';

  @override
  String get identity_verify_required =>
      'البريد الإلكتروني أو رقم الهاتف مطلوب';

  @override
  String get identity_verify_google_failed =>
      'فشل تسجيل الدخول عبر Google. يرجى المحاولة مرة أخرى.';

  @override
  String get welcome_screen_title_first_time => 'أهلًا بك في دابلر 😉';

  @override
  String get welcome_screen_title_returning => 'أهلًا بعودتك! 👋';

  @override
  String get welcome_screen_title_conversion => 'اكتمل التحويل! 🎉';

  @override
  String get welcome_screen_dont_forget => 'لا تنسَ';

  @override
  String get welcome_screen_continue => 'المتابعة';

  @override
  String get welcome_screen_chip_player => 'لاعب رياضي';

  @override
  String get welcome_screen_chip_organiser => 'منظّم مباريات';

  @override
  String get welcome_screen_chip_host => 'مضيف ملعب';

  @override
  String get welcome_screen_chip_socialiser => 'اجتماعي رياضي';

  @override
  String get welcome_screen_player_guidance =>
      'انضم إلى مباريات تناسب مستواك، واحترم قواعد المنظّم، ولا تؤكد مشاركتك إلا حين تكون جاهزًا للعب.';

  @override
  String get welcome_screen_player_philosophy => 'التزامك يبني سمعتك.';

  @override
  String get welcome_screen_player_reminder =>
      'لا تؤكد إلا إذا كنت متأكدًا من قدرتك على اللعب.\nاحترم القواعد والمواعيد واللاعبين الآخرين.';

  @override
  String get welcome_screen_player_emphasis =>
      'لا تؤكد إلا حين تكون جاهزًا للعب';

  @override
  String get welcome_screen_organiser_guidance =>
      'أنشئ مباريات بقواعد واضحة ومستويات عادلة ومواعيد معقولة.';

  @override
  String get welcome_screen_organiser_philosophy =>
      'أنت من يحدّد الأجواء — فالمباريات العظيمة تبدأ بتنظيم عظيم.';

  @override
  String get welcome_screen_organiser_reminder =>
      'حدّد قواعد واضحة ومواعيد معقولة.\nأبلِغ عن أي تغيير مبكرًا وبوضوح.';

  @override
  String get welcome_screen_organiser_emphasis => 'تابع حين تكون جاهزًا فقط!';

  @override
  String get welcome_screen_host_guidance =>
      'اجعل اللاعبين يشعرون بالترحيب بإبقاء المعلومات دقيقة والمساحات جاهزة.';

  @override
  String get welcome_screen_host_philosophy =>
      'وضوح التوفّر وسلاسة التنسيق يحسّنان تجربة الجميع.';

  @override
  String get welcome_screen_host_reminder =>
      'أبقِ التوفّر والتفاصيل دقيقة.\nحدّث المعلومات فور حدوث أي تغيير.';

  @override
  String get welcome_screen_host_emphasis => 'تابع حين تكون جاهزًا فقط!';

  @override
  String get welcome_screen_socialiser_guidance =>
      'تواصل مع اللاعبين، وابدأ الحوارات، واجعل المباريات أكثر إنسانية.';

  @override
  String get welcome_screen_socialiser_philosophy =>
      'حضورك يشكّل المجتمع — ودود وشامل ومحترم.';

  @override
  String get welcome_screen_socialiser_reminder =>
      'كن محترمًا وشاملًا.\nأضف قيمة دون تعطيل المباراة.';

  @override
  String get welcome_screen_socialiser_emphasis => 'تابع حين تكون جاهزًا فقط!';

  @override
  String get onboarding_welcome_title => 'جارٍ إعداد حسابك';

  @override
  String get onboarding_welcome_subtitle => 'يستغرق هذا لحظة فقط…';

  @override
  String get onboarding_welcome_step_profile => 'جارٍ إنشاء ملفك الشخصي';

  @override
  String get social_onboarding_welcome_title => 'أهلًا بك في المجتمع';

  @override
  String get social_onboarding_welcome_subtitle =>
      'تواصل مع لاعبين مثلك، وشارك تجارب مبارياتك، وابنِ مجتمعك الرياضي.';

  @override
  String get social_onboarding_welcome_skip => 'تخطّي';

  @override
  String get social_onboarding_welcome_get_started => 'لنبدأ';

  @override
  String get social_onboarding_welcome_find_friends_title => 'ابحث عن أصدقائك';

  @override
  String get social_onboarding_welcome_find_friends_desc =>
      'تواصل مع لاعبين في منطقتك';

  @override
  String get social_onboarding_welcome_chat_title => 'تحدّث وشارك';

  @override
  String get social_onboarding_welcome_chat_desc =>
      'راسل أصدقاءك وشارك لحظات المباريات';

  @override
  String get social_onboarding_welcome_game_title => 'العب معًا';

  @override
  String get social_onboarding_welcome_game_desc =>
      'اكتشف المباريات وانضم إليها مع شبكتك';

  @override
  String get social_onboarding_friends_appbar => 'ابحث عن أصدقائك';

  @override
  String get social_onboarding_friends_title => 'ابحث عن مجتمعك الرياضي';

  @override
  String get social_onboarding_friends_subtitle =>
      'تواصل مع أصدقائك لمشاركة تجارب المباريات واكتشاف فرص جديدة.';

  @override
  String get social_onboarding_friends_sync_btn => 'مزامنة جهات الاتصال';

  @override
  String get social_onboarding_friends_syncing => 'جارٍ المزامنة...';

  @override
  String get social_onboarding_friends_or => 'أو';

  @override
  String get social_onboarding_friends_suggested => 'مقترح لك';

  @override
  String social_onboarding_friends_selected(int count) {
    return 'تم اختيار $count';
  }

  @override
  String social_onboarding_friends_mutual_one(int count) {
    return 'صديق مشترك ($count)';
  }

  @override
  String social_onboarding_friends_mutual_many(int count) {
    return 'الأصدقاء المشتركون: $count';
  }

  @override
  String get social_onboarding_friends_add_btn => 'أضف';

  @override
  String get social_onboarding_friends_added => 'تمت الإضافة';

  @override
  String get social_onboarding_friends_skip => 'تخطّي';

  @override
  String get social_onboarding_friends_continue => 'المتابعة';

  @override
  String social_onboarding_friends_send_requests(int count) {
    return 'أرسل الطلبات ($count) وتابع';
  }

  @override
  String get social_onboarding_friends_send_request => 'أرسل الطلب وتابع';

  @override
  String get social_onboarding_friends_synced =>
      'تمت مزامنة جهات الاتصال بنجاح!';

  @override
  String get social_onboarding_friends_sync_error =>
      'تعذّر الوصول إلى جهات الاتصال. يرجى المحاولة مرة أخرى.';

  @override
  String social_onboarding_friends_sent(int count) {
    return 'تم إرسال طلبات صداقة إلى $count من الأشخاص!';
  }

  @override
  String get social_onboarding_notif_appbar => 'الإشعارات';

  @override
  String get social_onboarding_notif_title => 'الإشعارات متوقفة مؤقتًا';

  @override
  String get social_onboarding_notif_body =>
      'نعيد بناء تفضيلات الإشعارات. يمكنك إنهاء الإعداد الآن وسنضيف خيارات الضبط في تحديث قادم.';

  @override
  String get social_onboarding_notif_finish => 'إنهاء';

  @override
  String get social_onboarding_privacy_appbar => 'إعدادات الخصوصية';

  @override
  String get social_onboarding_privacy_title => 'الخصوصية والأمان';

  @override
  String get social_onboarding_privacy_subtitle =>
      'تحكّم في من يرى ملفك الشخصي ويتفاعل معك. يمكنك تغيير هذه الإعدادات لاحقًا في أي وقت.';

  @override
  String get social_onboarding_privacy_step => '3 من 4';

  @override
  String get social_onboarding_privacy_profile_visible_title =>
      'الملف الشخصي ظاهر للأصدقاء';

  @override
  String get social_onboarding_privacy_profile_visible_subtitle =>
      'ملفك الشخصي ظاهر لأصدقائك';

  @override
  String get social_onboarding_privacy_posts_public_title =>
      'المنشورات ظاهرة للعامة';

  @override
  String get social_onboarding_privacy_posts_public_subtitle =>
      'يمكن لأي شخص رؤية منشوراتك';

  @override
  String get social_onboarding_privacy_allow_requests_title =>
      'السماح بطلبات الصداقة';

  @override
  String get social_onboarding_privacy_allow_requests_subtitle =>
      'يمكن للآخرين إرسال طلبات صداقة إليك';

  @override
  String get social_onboarding_privacy_allow_messages_title =>
      'السماح بطلبات المراسلة';

  @override
  String get social_onboarding_privacy_allow_messages_subtitle =>
      'يمكن لغير الأصدقاء مراسلتك';

  @override
  String get social_onboarding_privacy_online_status_title =>
      'إظهار حالة الاتصال';

  @override
  String get social_onboarding_privacy_online_status_subtitle =>
      'يستطيع أصدقاؤك رؤية متى تكون متصلًا';

  @override
  String get social_onboarding_privacy_back => 'رجوع';

  @override
  String get social_onboarding_privacy_continue => 'المتابعة';

  @override
  String get social_onboarding_complete_title => 'أهلًا بك في المجتمع!';

  @override
  String get social_onboarding_complete_subtitle =>
      'أصبح كل شيء جاهزًا! ابدأ التواصل مع أصدقائك، وشارك تجارب مبارياتك، واكتشف لاعبين جددًا في منطقتك.';

  @override
  String get social_onboarding_complete_connect_title => 'تواصل مع اللاعبين';

  @override
  String get social_onboarding_complete_connect_desc =>
      'ابحث عن أصدقاء يحبون الرياضات نفسها وأضفهم';

  @override
  String get social_onboarding_complete_share_title => 'شارك رحلتك';

  @override
  String get social_onboarding_complete_share_desc =>
      'انشر التحديثات والصور واحتفل بإنجازاتك';

  @override
  String get social_onboarding_complete_discover_title => 'اكتشف المباريات';

  @override
  String get social_onboarding_complete_discover_desc =>
      'شاهد المباريات التي يلعبها أصدقاؤك';

  @override
  String get social_onboarding_complete_explore_btn => 'استكشف المجتمع';

  @override
  String get social_onboarding_complete_home_btn => 'اذهب إلى الرئيسية';

  @override
  String get social_onboarding_complete_later => 'سأستكشف لاحقًا';

  @override
  String get language_select_title => 'اختر لغتك';

  @override
  String get language_select_saving => 'جارٍ الحفظ...';

  @override
  String get register_title => 'إنشاء حساب';

  @override
  String get register_btn => 'إنشاء حساب';

  @override
  String get post_card_author_anonymous => 'مجهول';

  @override
  String get post_card_user_fallback => 'مستخدم';

  @override
  String get post_card_persona_organiser => 'منظّم';

  @override
  String get post_card_persona_player => 'لاعب';

  @override
  String get post_card_near_you => 'قريب منك';

  @override
  String get post_card_edited => 'معدَّل';

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
  String get post_card_kind_game => 'المباراة';

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
  String get post_card_expired => 'انتهى';

  @override
  String post_card_expires_in_days(int n) {
    return 'ينتهي بعد $nي';
  }

  @override
  String post_card_expires_in_hours(int n) {
    return 'ينتهي بعد $nس';
  }

  @override
  String post_card_expires_in_minutes(int n) {
    return 'ينتهي بعد $nد';
  }

  @override
  String get post_card_expiring_soon => 'على وشك الانتهاء';

  @override
  String get repost_card_unavailable => 'المنشور الأصلي لم يعد متاحًا.';

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
  String get post_card_my_story => 'قصتي';

  @override
  String get post_card_kick_in_label => 'Kick-In';

  @override
  String get post_card_allocated => 'محجوز';

  @override
  String get nav_feeds => 'الرئيسية';

  @override
  String get nav_community => 'المجتمع';

  @override
  String get nav_venues => 'ملاعب';

  @override
  String get nav_games => 'مباريات';

  @override
  String get nav_meetups => 'اللقاءات';

  @override
  String get nav_create_post => 'منشور جديد';

  @override
  String get nav_create_game => 'مباراة جديدة';

  @override
  String get nav_create_meetup => 'لقاء جديد';

  @override
  String get nav_meetups_coming_soon => 'اللقاءات قادمة قريبًا!';

  @override
  String get nav_exit_app_title => 'الخروج من التطبيق؟';

  @override
  String get nav_exit_app_body => 'هل تريد الخروج من دابلر؟';

  @override
  String get nav_exit_app_cancel => 'إلغاء';

  @override
  String get nav_exit_app_confirm => 'خروج';

  @override
  String get nav_press_back_to_exit => 'اضغط رجوع مرة أخرى للخروج';

  @override
  String get nav_search_hint => 'ابحث في دابلر';

  @override
  String get nav_whats_happening => 'ما الجديد الآن';

  @override
  String get nav_trend_sports_category => 'رياضة';

  @override
  String get nav_trend_sports_title => 'مباريات جديدة بالقرب منك';

  @override
  String get nav_trend_sports_subtitle => 'اطّلع على أحدث المباريات في منطقتك';

  @override
  String get nav_trend_community_category => 'مجتمع';

  @override
  String get nav_trend_community_title => 'فِرق تنمو';

  @override
  String get nav_trend_community_subtitle => 'انضم إلى فريق لتلعب بانتظام';

  @override
  String get nav_trend_dabbler_category => 'دابلر';

  @override
  String get nav_trend_dabbler_title => 'شارك لحظاتك';

  @override
  String get nav_trend_dabbler_subtitle => 'انشر تحديثاتك وتواصل مع اللاعبين';

  @override
  String get nav_quick_actions => 'اختصارات';

  @override
  String get nav_find_friends => 'ابحث عن أصدقائك';

  @override
  String get nav_settings => 'الإعدادات';

  @override
  String get settings_header_title => 'الإعدادات';

  @override
  String get settings_header_help_tooltip => 'مركز المساعدة';

  @override
  String get settings_hero_eyebrow => 'خصّص تجربتك';

  @override
  String get settings_hero_title => 'اضبط دابلر ليناسب طريقة لعبك';

  @override
  String get settings_hero_subtitle =>
      'أدر حسابك وتفضيلاتك وإشعاراتك في مكان واحد.';

  @override
  String get settings_search_hint => 'ابحث في الإعدادات';

  @override
  String get settings_section_account => 'الحساب';

  @override
  String get settings_section_display => 'العرض';

  @override
  String get settings_section_about => 'حول';

  @override
  String get settings_section_profiles => 'الملفات الشخصية';

  @override
  String get settings_item_account_management_title => 'إدارة الحساب';

  @override
  String get settings_item_account_management_subtitle =>
      'البريد الإلكتروني وكلمة المرور والأمان';

  @override
  String get settings_item_privacy_settings_title => 'إعدادات الخصوصية';

  @override
  String get settings_item_privacy_settings_subtitle =>
      'أدر إعدادات الخصوصية والمستخدمين المحظورين';

  @override
  String get settings_item_theme_title => 'السمة';

  @override
  String get settings_item_theme_subtitle =>
      'فاتح أو داكن أو حسب إعدادات الجهاز';

  @override
  String get settings_item_language_title => 'اللغة';

  @override
  String get settings_item_country_title => 'دولة التطبيق';

  @override
  String get settings_item_country_default_subtitle =>
      'مصر · الإمارات · السعودية · المغرب';

  @override
  String get settings_country_picker_helper =>
      'يحدّد الرياضات والملاعب التي تراها';

  @override
  String get settings_item_terms_title => 'شروط الخدمة';

  @override
  String get settings_item_terms_subtitle => 'اقرأ الشروط والأحكام';

  @override
  String get settings_item_privacy_policy_title => 'سياسة الخصوصية';

  @override
  String get settings_item_privacy_policy_subtitle => 'كيف نتعامل مع بياناتك';

  @override
  String get settings_item_licenses_title => 'التراخيص';

  @override
  String get settings_item_licenses_subtitle => 'تراخيص المصادر المفتوحة';

  @override
  String get settings_sign_out_title => 'تسجيل الخروج';

  @override
  String get settings_sign_out_subtitle => 'اخرج من حسابك على هذا الجهاز';

  @override
  String get settings_sign_out_dialog_title => 'تسجيل الخروج';

  @override
  String get settings_sign_out_dialog_body => 'هل تريد تسجيل الخروج من حسابك؟';

  @override
  String get settings_sign_out_dialog_cancel => 'إلغاء';

  @override
  String settings_sign_out_error(String error) {
    return 'حدث خطأ أثناء تسجيل الخروج: $error';
  }

  @override
  String get account_delete_dialog_warning =>
      'لا يمكن التراجع عن هذا الإجراء. سيُحذف ملفك الشخصي وبياناتك الشخصية. أما سجلات الدفع والحجز فتُحفظ لأغراض محاسبية، ولم تُحدَّد مدة الاحتفاظ بها بعد.';

  @override
  String get account_delete_success_snack => 'تم حذف حسابك وبياناتك الشخصية.';

  @override
  String get danger_zone_delete_confirmation_message =>
      'سيؤدي هذا إلى حذف حسابك وبياناتك الشخصية ولا يمكن التراجع عنه. أما سجلات الدفع والحجز فتُحفظ لأغراض محاسبية، ولم تُحدَّد مدة الاحتفاظ بها بعد.';

  @override
  String get settings_version_app_name => 'دابلر';

  @override
  String settings_version_label(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settings_tile_privacy => 'الخصوصية';

  @override
  String get settings_tile_profile_shown => 'ظاهر في ملفك';

  @override
  String get settings_tile_notifications => 'الإشعارات';

  @override
  String get settings_tile_appearance => 'المظهر';

  @override
  String get settings_tile_language_region => 'اللغة والمنطقة';

  @override
  String get settings_tile_activity_shown => 'النشاط والإحصاءات الظاهرة';

  @override
  String get settings_tile_blocked => 'الحسابات المحظورة';

  @override
  String get settings_tile_privacy_label => 'إعدادات الخصوصية';

  @override
  String get settings_version_copyright => '© 2026 دابلر. جميع الحقوق محفوظة.';

  @override
  String settings_persona_become_title(String persona) {
    return 'ابدأ بصفة $persona';
  }

  @override
  String settings_persona_convert_title(String persona) {
    return 'التحويل إلى $persona';
  }

  @override
  String settings_persona_convert_subtitle(String persona) {
    return 'استبدل ملف $persona الخاص بك';
  }

  @override
  String settings_persona_convert_confirm_body(
    String fromPersona,
    String toPersona,
  ) {
    return 'سيؤدي هذا إلى تعطيل ملفك بصفة $fromPersona وإنشاء ملف جديد بصفة $toPersona.\n\nستبقى بيانات حسابك (العمر والجنس) كما هي.';
  }

  @override
  String get persona_label_host => 'مضيف';

  @override
  String get persona_label_socialiser => 'اجتماعي';

  @override
  String get profile_header_fallback => 'الملف الشخصي';

  @override
  String get profile_section_sports => 'الرياضات';

  @override
  String get profile_complete_your_profile => 'أكمل ملفك الشخصي';

  @override
  String get profile_bio_placeholder =>
      'أضف نبذة قصيرة ليعرف زملاؤك ما يتوقعونه منك.';

  @override
  String get settings_item_edit_profile_subtitle =>
      'الاسم والصورة والنبذة والرياضات';

  @override
  String get profile_btn_edit => 'تعديل الملف الشخصي';

  @override
  String get profile_btn_share => 'مشاركة الملف الشخصي';

  @override
  String get profile_btn_manage_profiles_tooltip => 'إدارة الملفات الشخصية';

  @override
  String get profile_manage_profiles_title => 'تبديل الملف الشخصي';

  @override
  String get profile_add_profile => 'إضافة ملف شخصي';

  @override
  String get profile_no_profiles_found => 'لا توجد ملفات شخصية';

  @override
  String get profile_error_loading_profiles =>
      'حدث خطأ أثناء تحميل الملفات الشخصية';

  @override
  String get profile_error_switch_profile_failed => 'تعذّر تبديل الملف الشخصي';

  @override
  String get profile_btn_cancel => 'إلغاء';

  @override
  String get profile_btn_continue => 'المتابعة';

  @override
  String get profile_persona_convert_badge => 'تحويل';

  @override
  String profile_convert_to(String persona) {
    return 'التحويل إلى $persona؟';
  }

  @override
  String profile_convert_confirm_body(String fromPersona, String toPersona) {
    return 'أنت على وشك التحويل من $fromPersona إلى $toPersona. سيُستبدل ملفك الشخصي الحالي.';
  }

  @override
  String get profile_tab_posts => 'المنشورات';

  @override
  String get profile_tab_replies => 'الردود';

  @override
  String get profile_tab_liked => 'الإعجابات';

  @override
  String get profile_tab_reposts => 'إعادات النشر';

  @override
  String get profile_tab_activity => 'النشاط';

  @override
  String get profile_empty_no_activity => 'لا يوجد نشاط بعد';

  @override
  String get profile_empty_no_posts => 'لا توجد منشورات بعد';

  @override
  String get profile_empty_no_replies => 'لا توجد ردود بعد';

  @override
  String get profile_empty_no_liked => 'لا توجد منشورات مُعجَب بها بعد';

  @override
  String get profile_empty_no_reposts => 'لا توجد إعادات نشر بعد';

  @override
  String get profile_empty_no_sports => 'لم تُضف رياضات بعد';

  @override
  String get profile_error_failed_load_posts => 'تعذّر تحميل المنشورات.';

  @override
  String profile_post_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منشور',
      many: 'منشورًا',
      few: 'منشورات',
      two: 'منشوران',
      one: 'منشور',
      zero: 'منشور',
    );
    return '$_temp0';
  }

  @override
  String profile_follower_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'متابِع',
      many: 'متابِعًا',
      few: 'متابِعين',
      two: 'متابِعان',
      one: 'متابِع',
      zero: 'متابِع',
    );
    return '$_temp0';
  }

  @override
  String get profile_following_label => 'يتابع';

  @override
  String get profile_takedown_title => 'تمت إزالة المحتوى';

  @override
  String get profile_takedown_body =>
      'أُزيل هذا المحتوى لمخالفته إرشادات المجتمع.';

  @override
  String get user_profile_error_not_found_title => 'الملف الشخصي غير موجود';

  @override
  String get user_profile_error_unable_to_load => 'تعذّر تحميل الملف الشخصي';

  @override
  String get user_profile_btn_go_back => 'رجوع';

  @override
  String get user_profile_btn_loading => 'جارٍ التحميل';

  @override
  String get user_profile_btn_unblock => 'إلغاء الحظر';

  @override
  String get user_profile_btn_follow => 'تابع';

  @override
  String get user_profile_btn_following => 'تتابعه';

  @override
  String get user_profile_age_suffix => 'سنة';

  @override
  String get user_profile_stat_games => 'المباريات';

  @override
  String get user_profile_stat_win_rate => 'نسبة الفوز';

  @override
  String get user_profile_stat_sports => 'الرياضات';

  @override
  String get user_profile_stat_reliability => 'الالتزام';

  @override
  String get user_profile_stat_activity => 'النشاط';

  @override
  String get user_profile_stat_last_play => 'آخر مباراة';

  @override
  String get user_profile_block_dialog_title => 'حظر المستخدم';

  @override
  String get user_profile_block_dialog_body =>
      'هل تريد حظر هذا المستخدم؟ لن يتمكن من رؤية ملفك الشخصي أو التواصل معك.';

  @override
  String get user_profile_block_btn_block => 'احظر';

  @override
  String get user_profile_blocked_snack => 'تم حظر المستخدم';

  @override
  String get user_profile_unblocked_snack => 'تم إلغاء الحظر';

  @override
  String get user_profile_menu_unblock_user => 'إلغاء حظر المستخدم';

  @override
  String get user_profile_menu_block_user => 'احظر المستخدم';

  @override
  String get user_profile_menu_report_user => 'بلّغ عن المستخدم';

  @override
  String get user_profile_cannot_message_blocked =>
      'لا يمكنك مراسلة مستخدم محظور';

  @override
  String get notif_signin_required => 'سجّل الدخول لعرض الإشعارات';

  @override
  String get notif_title_notifications => 'الإشعارات';

  @override
  String get notif_title_activity_log => 'سجل النشاط';

  @override
  String get notif_chip_all => 'الكل';

  @override
  String get notif_chip_games => 'المباريات';

  @override
  String get notif_chip_bookings => 'الحجوزات';

  @override
  String get notif_chip_social => 'الاجتماعي';

  @override
  String get notif_chip_achievements => 'الإنجازات';

  @override
  String get notif_chip_you => 'أنت';

  @override
  String get notif_chip_rewards => 'المكافآت';

  @override
  String get notif_chip_security => 'الأمان';

  @override
  String get notif_section_today => 'اليوم';

  @override
  String get notif_section_yesterday => 'أمس';

  @override
  String get notif_section_earlier => 'سابقًا';

  @override
  String get notif_mark_all_read => 'تحديد الكل كمقروء';

  @override
  String get notif_action_respond => 'رد';

  @override
  String get notif_action_follow_back => 'تابِعه أيضًا';

  @override
  String get notif_action_view => 'عرض';

  @override
  String get notif_action_see_circle => 'عرض الدائرة';

  @override
  String get notif_load_older => 'تحميل الأقدم';

  @override
  String get notif_empty_no_notifications => 'لا توجد إشعارات بعد';

  @override
  String get notif_empty_subtitle => 'سنخبرك عندما يحدث شيء';

  @override
  String get notif_btn_retry => 'أعد المحاولة';

  @override
  String notif_error_prefix(String message) {
    return 'خطأ: $message';
  }

  @override
  String get activity_last_7_days => 'آخر 7 أيام';

  @override
  String get activity_search_hint => 'ابحث في النشاط…';

  @override
  String get activity_pill_upcoming => 'القادمة';

  @override
  String get activity_pill_live => 'مباشر';

  @override
  String get activity_subject_reward => 'مكافأة';

  @override
  String get activity_subject_security => 'الأمان';

  @override
  String get activity_all_normal_title => 'كل النشاط طبيعي';

  @override
  String get activity_all_normal_body =>
      'لا توجد عمليات تسجيل دخول غير معتادة أو تغييرات في الأجهزة خلال آخر 30 يومًا. ';

  @override
  String get activity_manage_devices => 'إدارة الأجهزة ←';

  @override
  String get activity_empty_no_activity => 'لا يوجد نشاط بعد';

  @override
  String get activity_empty_subtitle => 'سيظهر نشاطك هنا';

  @override
  String get activity_day_streak => 'يوم متواصل';

  @override
  String activity_participants_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشارك',
      many: '$count مشاركًا',
      few: '$count مشاركين',
      two: 'مشاركان',
      one: 'مشارك واحد',
    );
    return '$_temp0';
  }

  @override
  String get time_just_now => 'الآن';

  @override
  String time_minutes_ago(int n) {
    return 'منذ $nد';
  }

  @override
  String time_hours_ago(int n) {
    return 'منذ $nس';
  }

  @override
  String time_days_ago(int n) {
    return 'منذ $nي';
  }

  @override
  String notif_kind_friend_requested(String actor) {
    return '$actor أرسل إليك طلب صداقة';
  }

  @override
  String get notif_kind_friend_requested_anon => 'لديك طلب صداقة جديد';

  @override
  String notif_kind_friend_accepted(String actor) {
    return '$actor قبل طلب صداقتك';
  }

  @override
  String get notif_kind_friend_accepted_anon => 'تم قبول طلب صداقتك';

  @override
  String notif_kind_social_followed(String actor) {
    return '$actor بدأ يتابعك';
  }

  @override
  String get notif_kind_social_followed_anon => 'لديك متابع جديد';

  @override
  String notif_kind_social_circle_joined(String actor) {
    return '$actor انضم إلى دائرتك';
  }

  @override
  String get notif_kind_social_circle_joined_anon => 'انضم أحدهم إلى دائرتك';

  @override
  String notif_kind_social_post_liked(String actor) {
    return 'أعجب $actor بمنشورك';
  }

  @override
  String get notif_kind_social_post_liked_anon => 'أُعجب أحدهم بمنشورك';

  @override
  String notif_kind_social_post_commented(String actor) {
    return 'علّق $actor على منشورك';
  }

  @override
  String get notif_kind_social_post_commented_anon => 'تعليق جديد على منشورك';

  @override
  String notif_kind_social_comment_liked(String actor) {
    return 'أعجب $actor بتعليقك';
  }

  @override
  String get notif_kind_social_comment_liked_anon => 'أُعجب أحدهم بتعليقك';

  @override
  String notif_kind_social_mentioned(String actor) {
    return '$actor أشار إليك';
  }

  @override
  String get notif_kind_social_mentioned_anon => 'تمت الإشارة إليك';

  @override
  String notif_kind_game_invited(String actor) {
    return '$actor دعاك إلى مباراة';
  }

  @override
  String get notif_kind_game_invited_anon => 'لديك دعوة جديدة إلى مباراة';

  @override
  String get notif_kind_game_updated => 'تم تغيير تفاصيل المباراة';

  @override
  String notif_kind_game_join_request(String actor) {
    return '$actor طلب الانضمام إلى مباراتك';
  }

  @override
  String get notif_kind_game_join_request_anon =>
      'طلب أحدهم الانضمام إلى مباراتك';

  @override
  String get notif_kind_game_waitlist_promoted =>
      'أصبحت ضمن اللاعبين! توفّر مكان';

  @override
  String get notif_kind_game_reminder => 'تذكير بالمباراة';

  @override
  String get notif_kind_arena_payment_required => 'الدفع مطلوب لإتمام حجزك';

  @override
  String get notif_kind_reward_badge_awarded => 'حصلت على وسام جديد';

  @override
  String get notif_kind_achievement_earned => 'حققت إنجازًا جديدًا';

  @override
  String get settings_identity_subtitle => 'الحساب وكلمة المرور والأمان';

  @override
  String get settings_tile_privacy_preset => 'إعداد الخصوصية';

  @override
  String get settings_preset_public => 'عام';

  @override
  String get settings_preset_friends => 'الأصدقاء فقط';

  @override
  String get settings_preset_private => 'خاص';

  @override
  String get settings_theme_light => 'فاتح';

  @override
  String get settings_theme_dark => 'داكن';

  @override
  String get settings_theme_system => 'النظام';

  @override
  String get settings_country_short_eg => 'مصر';

  @override
  String get settings_country_short_ae => 'الإمارات';

  @override
  String get settings_country_short_sa => 'السعودية';

  @override
  String get settings_country_short_ma => 'المغرب';

  @override
  String get settings_organiser_title => 'كن منظّمًا';

  @override
  String get settings_organiser_subtitle => 'أنشئ الفعاليات الرياضية وأدرها';

  @override
  String get settings_organiser_info_body =>
      'ينشئ المنظّمون المباريات ويحددون الملاعب والأسعار ويديرون المنضمّين. الإعداد يستغرق دقائق وتحتفظ بملف اللاعب.';

  @override
  String get settings_organiser_start => 'ابدأ الإعداد';

  @override
  String get settings_about_title => 'حول دابلر';

  @override
  String get settings_about_subtitle => 'الشروط، سياسة الخصوصية، التراخيص';

  @override
  String settings_search_results(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      many: '$count نتيجة',
      few: '$count نتائج',
      zero: '$count نتيجة',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get settings_search_no_match => 'لا إعدادات تطابق ذلك';

  @override
  String get settings_path_account => 'الحساب والأمان';

  @override
  String get settings_path_privacy => 'الخصوصية';

  @override
  String get settings_path_privacy_safety => 'الخصوصية › السلامة';

  @override
  String get settings_path_appearance => 'المظهر';

  @override
  String get settings_path_profiles => 'الإعدادات › الملفات';

  @override
  String get settings_path_root => 'الإعدادات';

  @override
  String get settings_sign_out_confirm_body =>
      'سيتم تسجيل خروجك على هذا الجهاز. تبقى مبارياتك وملفك في حسابك.';

  @override
  String notif_group_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      zero: '$count عنصر',
      two: 'عنصران',
      one: 'عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String get notif_prefs_title => 'ما يصلك';

  @override
  String get notif_prefs_done => 'تم';

  @override
  String get notif_pref_invites_title => 'دعوات المباريات';

  @override
  String get notif_pref_invites_sub => 'عندما يضيفك أحد إلى مباراة';

  @override
  String get notif_pref_waitlist_title => 'أماكن قائمة الانتظار';

  @override
  String get notif_pref_waitlist_sub => 'لحظة توفّر مكان';

  @override
  String get notif_pref_payments_title => 'المدفوعات والتقسيم';

  @override
  String get notif_pref_payments_sub => 'الطلبات والإيصالات والمبالغ المستردة';

  @override
  String get notif_pref_social_title => 'النشاط الاجتماعي';

  @override
  String get notif_pref_social_sub => 'المتابعات والردود والإشارات';

  @override
  String get notif_quiet_hours_title => 'ساعات الهدوء';

  @override
  String get notif_quiet_hours_sub => 'لا اهتزازات بين هذين الوقتين';

  @override
  String get notif_quiet_hours_off => 'متوقف';

  @override
  String notif_quiet_hours_range(String start, String end) {
    return '$start – $end';
  }

  @override
  String get acct_title => 'الحساب';

  @override
  String get acct_group_signin => 'تسجيل الدخول';

  @override
  String get acct_row_email => 'البريد الإلكتروني';

  @override
  String get acct_row_password => 'كلمة المرور';

  @override
  String get acct_group_security => 'الأمان';

  @override
  String get acct_group_security_note => 'احمِ حسابك بإجراءات أمان إضافية';

  @override
  String get acct_2fa_title => 'التحقق بخطوتين';

  @override
  String get acct_2fa_sub => 'أضف طبقة حماية إضافية';

  @override
  String get acct_alerts_title => 'تنبيهات الدخول';

  @override
  String get acct_alerts_sub => 'تلقَّ إشعارًا بعمليات الدخول الجديدة';

  @override
  String get acct_group_danger => 'منطقة الخطر';

  @override
  String get acct_delete_title => 'حذف الحساب';

  @override
  String get acct_delete_sub => 'احذف حسابك وكل بياناتك نهائيًا';

  @override
  String get acct_delete_body =>
      'يحذف هذا حسابك وكل بياناتك نهائيًا، بما فيها المباريات والإحصاءات والرسائل. لا يمكن التراجع.';

  @override
  String get acct_delete_confirm => 'حذف نهائي';

  @override
  String get acct_cancel => 'إلغاء';

  @override
  String get acct_delete_type_error => 'اكتب «DELETE» للتأكيد';

  @override
  String acct_delete_failed(String error) {
    return 'تعذّر حذف الحساب: $error';
  }

  @override
  String get acct_email_sheet_title => 'البريد الإلكتروني';

  @override
  String get acct_email_field => 'البريد';

  @override
  String get acct_email_helper =>
      'نرسل رابط تأكيد إلى العنوان الجديد قبل أن يحل محل القديم.';

  @override
  String get acct_email_update => 'تحديث البريد';

  @override
  String get acct_email_updating => 'جارٍ التحديث…';

  @override
  String get acct_email_empty => 'لا يمكن ترك البريد فارغًا';

  @override
  String get acct_email_invalid => 'أدخل بريدًا إلكترونيًا صالحًا';

  @override
  String get acct_email_same => 'البريد الجديد هو نفسه الحالي';

  @override
  String get acct_email_sent => 'تم إرسال التأكيد';

  @override
  String acct_email_failed(String error) {
    return 'تعذّر تحديث البريد: $error';
  }

  @override
  String get acct_password_change_title => 'تغيير كلمة المرور';

  @override
  String get acct_password_set_title => 'تعيين كلمة المرور';

  @override
  String get acct_password_set_note =>
      'سجّلت الدخول عبر Google أو Apple. عيّن كلمة مرور لتسجّل الدخول ببريدك أيضًا.';

  @override
  String get acct_password_current => 'كلمة المرور الحالية';

  @override
  String get acct_password_new => 'كلمة المرور الجديدة';

  @override
  String get acct_password_new_helper => '6 أحرف على الأقل';

  @override
  String get acct_password_confirm => 'تأكيد كلمة المرور الجديدة';

  @override
  String get acct_password_change => 'تغيير كلمة المرور';

  @override
  String get acct_password_set => 'تعيين كلمة المرور';

  @override
  String get acct_password_changing => 'جارٍ التغيير…';

  @override
  String get acct_password_setting => 'جارٍ التعيين…';

  @override
  String get acct_password_changed => 'تم تغيير كلمة المرور';

  @override
  String get acct_password_was_set =>
      'تم تعيين كلمة المرور. يمكنك الآن تسجيل الدخول ببريدك وكلمة المرور.';

  @override
  String get acct_password_err_current => 'أدخل كلمة المرور الحالية';

  @override
  String get acct_password_err_new => 'أدخل كلمة مرور جديدة';

  @override
  String get acct_password_err_short => 'يجب ألا تقل كلمة المرور عن 6 أحرف';

  @override
  String get acct_password_err_mismatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get acct_password_err_same =>
      'يجب أن تختلف كلمة المرور الجديدة عن الحالية';

  @override
  String get acct_password_err_incorrect => 'كلمة المرور الحالية غير صحيحة';

  @override
  String acct_password_failed(String error) {
    return 'تعذّر تغيير كلمة المرور: $error';
  }

  @override
  String acct_load_failed(String error) {
    return 'تعذّر تحميل بيانات الحساب: $error';
  }

  @override
  String get acct_export_title => 'صدّر بياناتي';

  @override
  String get acct_export_sub =>
      'اطلب نسخة من بياناتك في دابلر (نقل البيانات وفق PDPL)';

  @override
  String get acct_export_started =>
      'نجهّز تصدير بياناتك. سنخبرك عبر البريد عندما يصبح جاهزًا.';

  @override
  String acct_export_failed(String error) {
    return 'تعذّر طلب تصدير البيانات: $error';
  }

  @override
  String get priv_title => 'الخصوصية';

  @override
  String get priv_preset_header => 'إعداد الخصوصية';

  @override
  String get priv_preset_note => 'اختر إعدادًا مسبقًا لضبط خصوصيتك بسرعة';

  @override
  String get priv_preset_public => 'عام';

  @override
  String get priv_preset_public_desc => 'ملفك ظاهر للجميع لسهولة الاكتشاف';

  @override
  String get priv_preset_friends => 'الأصدقاء فقط';

  @override
  String get priv_preset_friends_desc => 'أصدقاؤك فقط يرون ملفك الكامل';

  @override
  String get priv_preset_private => 'خاص';

  @override
  String get priv_preset_private_desc =>
      'الحد الأدنى من المعلومات يُشارك علنًا';

  @override
  String priv_preset_applied(String preset) {
    return 'تم تطبيق إعداد $preset';
  }

  @override
  String get priv_preset_custom => 'مخصّص';

  @override
  String get priv_preset_custom_desc => 'مزيجك الخاص من الإعدادات أدناه';

  @override
  String get priv_hint =>
      'يمكنك دائمًا تخصيص الإعدادات أدناه. تُحفظ التغييرات تلقائيًا.';

  @override
  String get priv_group_see => 'ما يراه الآخرون';

  @override
  String get priv_profile_title => 'الملف والهوية';

  @override
  String get priv_profile_sub => 'الصورة، الاسم، النبذة، العمر، بيانات الاتصال';

  @override
  String get priv_activity_title => 'النشاط والإحصاءات';

  @override
  String get priv_activity_sub => 'الحالة، تسجيلات الحضور، السجل، الإنجازات';

  @override
  String get priv_discover_title => 'إمكانية الاكتشاف';

  @override
  String get priv_discover_sub => 'فهرسة البحث واللاعبون القريبون';

  @override
  String get priv_group_comm => 'التواصل';

  @override
  String get priv_contact_title => 'من يمكنه التواصل معك';

  @override
  String get priv_contact_sub => 'الرسائل، دعوات المباريات، طلبات الصداقة';

  @override
  String get priv_group_data => 'البيانات';

  @override
  String get priv_data_title => 'البيانات والتحليلات';

  @override
  String get priv_data_sub => 'الموقع، التوصيات، التحليلات';

  @override
  String get priv_notif_title => 'الإشعارات';

  @override
  String get priv_notif_sub => 'الإشعارات والبريد';

  @override
  String get priv_group_safety => 'السلامة';

  @override
  String get priv_blocked_title => 'الحسابات المحظورة';

  @override
  String get priv_blocked_sub => 'الأشخاص الذين حظرتهم من التواصل معك';

  @override
  String priv_count_all(int total) {
    return 'الكل مفعّل ($total)';
  }

  @override
  String get priv_count_none => 'الكل متوقف';

  @override
  String priv_count_some(int on, int total) {
    return '$on من $total مفعّل';
  }

  @override
  String get priv_contact_nav => 'التواصل';

  @override
  String get priv_dm_title => 'الرسائل المباشرة';

  @override
  String get priv_dm_sub => 'من يمكنه مراسلتك';

  @override
  String get priv_invites_title => 'دعوات المباريات';

  @override
  String get priv_invites_sub => 'من يمكنه دعوتك للمباريات';

  @override
  String get priv_requests_title => 'طلبات الصداقة';

  @override
  String get priv_requests_sub => 'من يمكنه إرسال طلبات صداقة';

  @override
  String get priv_audience_anyone => 'أي شخص';

  @override
  String get priv_audience_friends => 'الأصدقاء فقط';

  @override
  String get priv_audience_organizers => 'المنظّمون فقط';

  @override
  String get priv_audience_none => 'لا أحد';

  @override
  String get priv_unblock => 'إلغاء الحظر';

  @override
  String get priv_unblocked => 'تم إلغاء الحظر';

  @override
  String get priv_blocked_empty => 'لم تحظر أحدًا.';

  @override
  String priv_blocked_failed(String error) {
    return 'تعذّر إلغاء الحظر: $error';
  }

  @override
  String priv_blocked_load_failed(String error) {
    return 'تعذّر تحميل الحسابات المحظورة: $error';
  }

  @override
  String get priv_save_failed => 'تعذّر حفظ الإعدادات. حاول مرة أخرى.';

  @override
  String get priv_saved => 'تم الحفظ';

  @override
  String get priv_t_photo => 'صورة الملف';

  @override
  String get priv_t_photo_sub => 'أظهر صورة ملفك';

  @override
  String get priv_t_name => 'الاسم الحقيقي';

  @override
  String get priv_t_name_sub => 'أظهر اسمك الكامل';

  @override
  String get priv_t_bio => 'النبذة';

  @override
  String get priv_t_bio_sub => 'أظهر نبذتك في ملفك';

  @override
  String get priv_t_age => 'العمر';

  @override
  String get priv_t_age_sub => 'أظهر عمرك في ملفك';

  @override
  String get priv_t_email => 'البريد الإلكتروني';

  @override
  String get priv_t_email_sub => 'أظهر بريدك للآخرين';

  @override
  String get priv_t_phone => 'رقم الهاتف';

  @override
  String get priv_t_phone_sub => 'أظهر رقم هاتفك';

  @override
  String get priv_t_location => 'الموقع';

  @override
  String get priv_t_location_sub => 'أظهر موقعك العام';

  @override
  String get priv_t_friends => 'قائمة الأصدقاء';

  @override
  String get priv_t_friends_sub => 'أظهر أصدقاءك علنًا';

  @override
  String get priv_t_online => 'حالة الاتصال';

  @override
  String get priv_t_online_sub => 'أظهر متى تكون متصلًا';

  @override
  String get priv_t_activity => 'حالة النشاط';

  @override
  String get priv_t_activity_sub => 'أظهر نشاطك الأخير';

  @override
  String get priv_t_checkins => 'تسجيلات الحضور';

  @override
  String get priv_t_checkins_sub => 'أظهر تسجيلات حضورك في الملاعب';

  @override
  String get priv_t_posts => 'المنشورات للعامة';

  @override
  String get priv_t_posts_sub => 'اجعل منشوراتك ظاهرة للجميع';

  @override
  String get priv_t_sports => 'ملفات الرياضات';

  @override
  String get priv_t_sports_sub => 'أظهر رياضاتك ومستوياتك';

  @override
  String get priv_t_history => 'سجل المباريات';

  @override
  String get priv_t_history_sub => 'أظهر مبارياتك السابقة';

  @override
  String get priv_t_stats => 'الإحصاءات';

  @override
  String get priv_t_stats_sub => 'أظهر إحصاءات أدائك';

  @override
  String get priv_t_achievements => 'الإنجازات';

  @override
  String get priv_t_achievements_sub => 'أظهر إنجازاتك';

  @override
  String get priv_t_indexing => 'فهرسة محركات البحث';

  @override
  String get priv_t_indexing_sub => 'اسمح للخدمات الخارجية بإيجاد ملفك';

  @override
  String get priv_t_nearby => 'إخفاء من القريبين';

  @override
  String get priv_t_nearby_sub => 'لا تظهر في بحث اللاعبين القريبين';

  @override
  String get priv_t_tracking => 'تتبع الموقع';

  @override
  String get priv_t_tracking_sub => 'اسمح بالميزات المعتمدة على الموقع';

  @override
  String get priv_t_recs => 'توصيات المباريات';

  @override
  String get priv_t_recs_sub => 'اقتراحات مباريات مخصّصة';

  @override
  String get priv_t_analytics => 'تحليلات مجهولة';

  @override
  String get priv_t_analytics_sub => 'ساعد في تحسين التطبيق';

  @override
  String get priv_t_push => 'الإشعارات الفورية';

  @override
  String get priv_t_push_sub => 'تلقَّ إشعارات فورية على جهازك';

  @override
  String get priv_t_mail => 'إشعارات البريد';

  @override
  String get priv_t_mail_sub => 'تلقَّ الإشعارات عبر البريد';

  @override
  String get appr_title => 'المظهر';

  @override
  String get appr_group_theme => 'السمة';

  @override
  String get appr_light => 'فاتح';

  @override
  String get appr_dark => 'داكن';

  @override
  String get appr_system => 'النظام';

  @override
  String appr_theme_applied(String theme) {
    return 'سمة $theme';
  }

  @override
  String get appr_group_color => 'سمة الألوان';

  @override
  String get appr_group_color_note => 'طبّق مجموعة ألوان واحدة على التطبيق كله';

  @override
  String appr_color_use(String name) {
    return 'استخدم ألوان $name في التطبيق كله';
  }

  @override
  String get appr_group_auto => 'السمة التلقائية';

  @override
  String get appr_group_auto_note => 'بدّل تلقائيًا بين السمة الفاتحة والداكنة';

  @override
  String get appr_auto_title => 'سمة حسب الوقت';

  @override
  String get appr_auto_sub => 'بدّل السمة حسب وقت اليوم';

  @override
  String get appr_group_schedule => 'جدول النهار والليل';

  @override
  String get appr_group_schedule_note => 'حدد متى تعمل السمة الفاتحة والداكنة';

  @override
  String get appr_day_title => 'يبدأ النهار عند';

  @override
  String get appr_day_sub => 'تعمل السمة الفاتحة';

  @override
  String get appr_night_title => 'يبدأ الليل عند';

  @override
  String get appr_night_sub => 'تعمل السمة الداكنة';

  @override
  String get region_title => 'اللغة والمنطقة';

  @override
  String get region_language => 'اللغة';

  @override
  String get region_language_sub => 'لغة التطبيق والمحتوى';

  @override
  String get region_language_updated => 'تم تحديث اللغة';

  @override
  String get region_country => 'دولة التطبيق';

  @override
  String get region_country_sub => 'المباريات والملاعب والعملة';

  @override
  String get region_country_updated => 'تم تحديث الدولة';

  @override
  String get region_lang_en => 'الإنجليزية · English';

  @override
  String get region_lang_ar => 'العربية · العربية';

  @override
  String get region_country_Egypt => 'مصر';

  @override
  String get region_country_UAE => 'الإمارات';

  @override
  String get region_country_KSA => 'السعودية';

  @override
  String get region_country_Morocco => 'المغرب';

  @override
  String region_error(String error) {
    return 'خطأ: $error';
  }

  @override
  String get listing_set_location => 'حدد الموقع';

  @override
  String get listing_search => 'بحث';

  @override
  String get listing_filters => 'الفلاتر';

  @override
  String get listing_reset => 'إعادة ضبط';

  @override
  String get listing_clear_all => 'مسح الكل';

  @override
  String get listing_all_sports => 'كل الرياضات';

  @override
  String get listing_upcoming => 'القادمة';

  @override
  String get listing_open_spots => 'أماكن متاحة';

  @override
  String get listing_sort_nearest => 'الأقرب';

  @override
  String get listing_sort_soonest => 'الأقرب موعدًا';

  @override
  String get listing_group_distance => 'المسافة';

  @override
  String get listing_group_date => 'التاريخ';

  @override
  String get listing_group_skill => 'المستوى';

  @override
  String get listing_group_availability => 'التوفر';

  @override
  String get listing_group_sort => 'ترتيب حسب';

  @override
  String listing_within_km(int km) {
    return 'ضمن $km كم';
  }

  @override
  String get listing_any_distance => 'أي مسافة';

  @override
  String get listing_date_any => 'أي تاريخ';

  @override
  String get listing_today => 'اليوم';

  @override
  String get listing_tomorrow => 'غدًا';

  @override
  String get listing_this_week => 'هذا الأسبوع';

  @override
  String listing_distance_km(String km) {
    return '$km كم';
  }

  @override
  String listing_distance_m(int meters) {
    return '$meters م';
  }

  @override
  String get listing_no_charge => 'بدون رسوم';

  @override
  String get listing_share_game => 'مشاركة المباراة';

  @override
  String get listing_favourite_add => 'أضف إلى المفضلة';

  @override
  String get listing_favourite_remove => 'أزل من المفضلة';

  @override
  String get listing_verified_host => 'منظّم موثّق';

  @override
  String listing_duration_min(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get listing_skill_all_levels => 'كل المستويات';

  @override
  String get listing_starts_soon => 'يبدأ قريبًا';

  @override
  String get listing_filters_open => 'فتح الفلاتر';

  @override
  String listing_games_empty_radius_window(int km, String window) {
    return 'لا توجد مباريات ضمن $km كم $window. وسّع نطاق التاريخ أو الرياضة.';
  }

  @override
  String listing_games_empty_radius(int km) {
    return 'لا توجد مباريات ضمن $km كم. وسّع المسافة أو الرياضة.';
  }

  @override
  String listing_games_empty_window(String window) {
    return 'لا توجد مباريات $window. وسّع نطاق التاريخ أو الرياضة.';
  }

  @override
  String get listing_games_empty_fallback =>
      'لا توجد مباريات تطابق هذه الفلاتر. وسّع نطاق التاريخ أو الرياضة.';

  @override
  String get listing_window_today => 'اليوم';

  @override
  String get listing_window_tomorrow => 'غدًا';

  @override
  String listing_window_days(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'خلال الأيام الـ$days القادمة',
      many: 'خلال الـ$days يومًا القادمة',
      few: 'خلال الأيام الـ$days القادمة',
      two: 'خلال اليومين القادمين',
      one: 'خلال اليوم القادم',
    );
    return '$_temp0';
  }

  @override
  String get listing_window_weekend => 'في نهاية الأسبوع';

  @override
  String get listing_skill_beginner => 'مبتدئ';

  @override
  String get listing_skill_intermediate => 'متوسط';

  @override
  String get listing_skill_advanced => 'متقدم';

  @override
  String get listing_load_sports_failed => 'تعذّر تحميل الرياضات';

  @override
  String get listing_load_games_failed => 'تعذّر تحميل المباريات';

  @override
  String get listing_load_venues_failed => 'تعذّر تحميل الملاعب';

  @override
  String get listing_games_filtered_title => 'لا توجد مباريات تطابق الفلاتر';

  @override
  String get listing_games_filtered_text => 'عدّل الفلاتر أو امسحها.';

  @override
  String get listing_games_nearby_title => 'لا توجد مباريات قريبة.';

  @override
  String get listing_games_nearby_text => 'جرّب توسيع نطاق البحث في الفلاتر.';

  @override
  String get listing_games_none_title => 'لا توجد مباريات بعد';

  @override
  String get listing_games_none_text => 'كن أول من ينشئ مباراة في منطقتك!';

  @override
  String get listing_change_filters => 'غيّر الفلاتر';

  @override
  String get listing_created => 'أنشأتها';

  @override
  String get listing_joined => 'منضم';

  @override
  String get listing_full => 'ممتلئة';

  @override
  String get listing_join_game => 'انضم إلى المباراة';

  @override
  String get listing_on_waitlist => 'في قائمة الانتظار';

  @override
  String get listing_request_sent => 'تم إرسال الطلب';

  @override
  String listing_spots_left(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count مكان',
      many: 'بقي $count مكانًا',
      few: 'بقيت $count أماكن',
      zero: 'لا أماكن متبقية',
      two: 'بقي مكانان',
      one: 'بقي مكان واحد',
    );
    return '$_temp0';
  }

  @override
  String listing_spots_almost_full(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقي $count مكان · اقتربت من الامتلاء',
      many: 'بقي $count مكانًا · اقتربت من الامتلاء',
      few: 'بقيت $count أماكن · اقتربت من الامتلاء',
      zero: 'لا أماكن متبقية · ممتلئة تقريبًا',
      two: 'بقي مكانان · اقتربت من الامتلاء',
      one: 'بقي مكان واحد · اقتربت من الامتلاء',
    );
    return '$_temp0';
  }

  @override
  String listing_players_in(int joined, int total) {
    return 'اللاعبون: $joined من $total';
  }

  @override
  String listing_show_games(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض $count مباراة',
      many: 'عرض $count مباراة',
      few: 'عرض $count مباريات',
      two: 'عرض مباراتين',
      one: 'عرض مباراة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get listing_show_games_plain => 'عرض المباريات';

  @override
  String get listing_show_venues => 'عرض الملاعب';

  @override
  String get listing_unit_day => 'يوم';

  @override
  String get listing_unit_days => 'أيام';

  @override
  String get listing_unit_hour => 'ساعة';

  @override
  String get listing_unit_hours => 'ساعات';

  @override
  String get listing_unit_min => 'د';

  @override
  String get listing_saved_venues => 'الملاعب المحفوظة';

  @override
  String get listing_add_venue => 'أضف ملعبًا';

  @override
  String get listing_venues_none_title => 'لا توجد ملاعب';

  @override
  String get listing_venues_none_text => 'جرّب رياضة أخرى.';

  @override
  String listing_venues_radius_text(int km) {
    return 'لا توجد ملاعب ضمن $km كم — جرّب توسيع نطاق البحث.';
  }

  @override
  String get listing_starting_from => 'يبدأ من';

  @override
  String get listing_view_venue => 'عرض الملعب';

  @override
  String get listing_save_venue => 'احفظ الملعب';

  @override
  String get listing_remove_saved => 'أزل من المحفوظ';

  @override
  String get listing_indoor => 'داخلي';

  @override
  String get listing_outdoor => 'خارجي';

  @override
  String get listing_distance_unavailable => 'المسافة غير متاحة';

  @override
  String listing_km_away(String distance) {
    return 'على بعد $distance';
  }

  @override
  String get listing_free => 'مجاني';

  @override
  String listing_price_per_hour(String amount) {
    return '$amount د.إ / ساعة';
  }

  @override
  String get location_change_title => 'تغيير الموقع';

  @override
  String get location_search_areas => 'ابحث عن المناطق…';

  @override
  String get location_use_current => 'استخدم الموقع الحالي';

  @override
  String get location_detecting => 'جارٍ التحديد…';

  @override
  String get location_saved => 'المحفوظة';

  @override
  String get location_add => 'إضافة موقع';

  @override
  String location_no_areas(String query) {
    return 'لا توجد مناطق تطابق \"$query\"';
  }

  @override
  String get location_access_required => 'الوصول إلى الموقع مطلوب';

  @override
  String get location_permission_denied_forever =>
      'تم رفض إذن الموقع نهائيًا. افتح الإعدادات لتفعيله.';

  @override
  String get location_open_settings => 'فتح الإعدادات';

  @override
  String get location_enable_services => 'يرجى تفعيل خدمات الموقع';

  @override
  String get location_permission_denied => 'تم رفض إذن الموقع';

  @override
  String get location_timeout => 'تعذّر تحديد الموقع — حاول مرة أخرى';

  @override
  String location_error(String message) {
    return 'خطأ: $message';
  }

  @override
  String get listing_skill_any => 'أي مستوى';

  @override
  String get home_upcoming_title => 'القادمة';

  @override
  String home_upcoming_title_count(int count) {
    return 'القادمة · $count';
  }

  @override
  String home_upcoming_strip_count(int count) {
    return '$count قادمة';
  }

  @override
  String home_upcoming_more(int count) {
    return '$count أخرى هذا الأسبوع';
  }

  @override
  String get home_upcoming_show_less => 'عرض أقل';

  @override
  String get home_upcoming_hide => 'إخفاء';

  @override
  String home_upcoming_see_all(int count) {
    return 'عرض كل القادمة ($count)';
  }

  @override
  String get home_upcoming_day => 'يوم';

  @override
  String get home_upcoming_days => 'أيام';

  @override
  String get home_upcoming_hour => 'ساعة';

  @override
  String get home_upcoming_hours => 'ساعات';

  @override
  String get home_upcoming_min => 'دقيقة';

  @override
  String home_upcoming_in_days(int days) {
    return 'بعد $days ي';
  }

  @override
  String home_upcoming_in_hours(int hours, int minutes) {
    return 'بعد $hours س $minutes د';
  }

  @override
  String home_upcoming_in_minutes(int minutes) {
    return 'بعد $minutes د';
  }

  @override
  String get home_post_options_title => 'خيارات المنشور';

  @override
  String home_post_options_by(String name) {
    return 'نشره $name';
  }

  @override
  String get home_post_report => 'الإبلاغ عن المنشور';

  @override
  String get home_post_report_note => 'أخبرنا ما المشكلة في هذا المنشور';

  @override
  String get home_post_block => 'حظر المستخدم';

  @override
  String get home_vibe_title => 'ما الأجواء؟';

  @override
  String get home_location_title => 'تغيير الموقع';

  @override
  String get home_location_done => 'تم';

  @override
  String get home_location_search => 'ابحث عن منطقة أو شارع أو مدينة';

  @override
  String get home_location_use_current => 'استخدم موقعي الحالي';

  @override
  String get home_location_add => 'إضافة موقع';

  @override
  String get home_location_cancel => 'إلغاء';

  @override
  String get home_location_search_venues => 'ابحث عن ملاعب ومناطق';

  @override
  String get home_location_recent => 'الأخيرة';

  @override
  String home_location_no_match(String query) {
    return 'لا توجد مناطق مطابقة لـ \"$query\"';
  }

  @override
  String get blocked_accounts_note => 'أدر المستخدمين الذين حظرتهم.';

  @override
  String get blocked_accounts_empty => 'لم تحظر أحدًا.';

  @override
  String get blocked_accounts_load_failed => 'تعذّر تحميل الحسابات المحظورة.';

  @override
  String get blocked_accounts_unknown => 'غير معروف';

  @override
  String get blocked_accounts_unblock => 'إلغاء الحظر';

  @override
  String get blocked_accounts_unblocked => 'تم إلغاء الحظر';

  @override
  String blocked_accounts_unblock_failed(String message) {
    return 'تعذّر إلغاء الحظر: $message';
  }

  @override
  String get notif_settings_push => 'الإشعارات الفورية';

  @override
  String get notif_settings_push_sub => 'تلقَّ إشعارات فورية على جهازك';

  @override
  String get notif_settings_email => 'إشعارات البريد';

  @override
  String get notif_settings_email_sub => 'تلقَّ الإشعارات عبر البريد';

  @override
  String get notif_settings_sms => 'إشعارات الرسائل النصية';

  @override
  String get notif_settings_sms_sub =>
      'تلقَّ التحديثات المهمة عبر الرسائل النصية';

  @override
  String get notif_settings_quiet_header => 'ساعات الهدوء';

  @override
  String get notif_settings_quiet_mute => 'كتم الإشعارات في ساعات الهدوء';

  @override
  String get notif_settings_quiet_mute_off => 'أوقف الإشعارات الفورية ليلًا';

  @override
  String notif_settings_quiet_mute_on(String start, String end) {
    return 'لا إشعارات فورية بين $start و$end';
  }

  @override
  String get notif_settings_quiet_start => 'البداية';

  @override
  String get notif_settings_quiet_end => 'النهاية';

  @override
  String get notif_settings_quiet_urgent => 'السماح بالإشعارات العاجلة';

  @override
  String get notif_settings_quiet_urgent_sub =>
      'تصلك التنبيهات عالية الأولوية حتى في ساعات الهدوء';

  @override
  String get notif_settings_quiet_all => 'السماح بكل الإشعارات';

  @override
  String get notif_settings_quiet_all_sub =>
      'تصلك كل الإشعارات الفورية حتى في ساعات الهدوء';

  @override
  String get notif_settings_group_game => 'إشعارات المباريات';

  @override
  String get notif_settings_group_social => 'الإشعارات الاجتماعية';

  @override
  String get notif_settings_group_connections => 'العلاقات';

  @override
  String get notif_settings_kind_game_invites => 'دعوات المباريات وطلباتها';

  @override
  String get notif_settings_kind_game_invites_sub =>
      'الدعوات وطلبات الانضمام والموافقات';

  @override
  String get notif_settings_kind_game_reminders => 'تذكيرات المباريات';

  @override
  String get notif_settings_kind_game_reminders_sub =>
      'تذكيرات بالمباريات القادمة';

  @override
  String get notif_settings_kind_game_updates => 'تحديثات المباريات';

  @override
  String get notif_settings_kind_game_updates_sub =>
      'التغييرات، وفتح أماكن من قائمة الانتظار، وانضمام اللاعبين';

  @override
  String get notif_settings_kind_booking => 'مدفوعات الحجز';

  @override
  String get notif_settings_kind_booking_sub => 'عندما يحتاج الحجز إلى دفع';

  @override
  String get notif_settings_kind_likes => 'الإعجابات والتفاعلات';

  @override
  String get notif_settings_kind_likes_sub => 'الإعجابات والتفاعلات على محتواك';

  @override
  String get notif_settings_kind_comments => 'التعليقات';

  @override
  String get notif_settings_kind_comments_sub => 'التعليقات على منشوراتك';

  @override
  String get notif_settings_kind_mentions => 'الإشارات';

  @override
  String get notif_settings_kind_mentions_sub => 'عندما يشير إليك أحد';

  @override
  String get notif_settings_kind_followers => 'متابعون جدد';

  @override
  String get notif_settings_kind_followers_sub => 'عندما يتابعك أحد';

  @override
  String get notif_settings_kind_friends => 'طلبات الصداقة';

  @override
  String get notif_settings_kind_friends_sub =>
      'طلبات الصداقة الجديدة والمقبولة';

  @override
  String get notif_settings_kind_squads => 'دعوات الفرق';

  @override
  String get notif_settings_kind_squads_sub => 'دعوات الانضمام إلى فريق';

  @override
  String get notif_settings_kind_meetups => 'دعوات اللقاءات';

  @override
  String get notif_settings_kind_meetups_sub =>
      'الدعوات وانضمام اللاعبين إلى اللقاءات';

  @override
  String get notif_settings_kind_meetup_rsvps => 'الردود على اللقاءات';

  @override
  String get notif_settings_kind_meetup_rsvps_sub =>
      'عندما يرد أحدهم على لقاء تستضيفه';

  @override
  String get notif_settings_kind_meetup_requests =>
      'طلبات الانضمام إلى اللقاءات';

  @override
  String get notif_settings_kind_meetup_requests_sub =>
      'عندما يطلب أحدهم الانضمام إلى لقاء تستضيفه';

  @override
  String get notif_settings_kind_meetup_approved =>
      'قبول طلب الانضمام إلى لقاء';

  @override
  String get notif_settings_kind_meetup_approved_sub =>
      'عندما يقبل المضيف طلب انضمامك';

  @override
  String get notif_settings_kind_meetup_declined => 'رفض طلب الانضمام إلى لقاء';

  @override
  String get notif_settings_kind_meetup_declined_sub =>
      'عندما يرفض المضيف طلب انضمامك';

  @override
  String get notif_settings_kind_meetup_cancelled => 'إلغاء لقاء';

  @override
  String get notif_settings_kind_meetup_cancelled_sub =>
      'عندما يُلغى لقاء انضممت إليه';

  @override
  String notif_settings_update_failed(String error) {
    return 'تعذّر تحديث الإعدادات: $error';
  }

  @override
  String get game_prefs_title => 'تفضيلات المباريات';

  @override
  String get game_prefs_save => 'حفظ';

  @override
  String get game_prefs_saved => 'تم حفظ تفضيلات المباريات';

  @override
  String get game_prefs_types_header => 'أنواع المباريات المفضلة';

  @override
  String get game_prefs_types_note =>
      'اختر أنواع المباريات التي تستمتع بها أكثر';

  @override
  String get game_prefs_type_pickup => 'مباريات سريعة';

  @override
  String get game_prefs_type_pickup_sub => 'مباريات ودية مع لاعبين آخرين';

  @override
  String get game_prefs_type_tournaments => 'بطولات';

  @override
  String get game_prefs_type_tournaments_sub => 'فعاليات تنافسية منظمة';

  @override
  String get game_prefs_type_practice => 'حصص تدريبية';

  @override
  String get game_prefs_type_practice_sub => 'تطوير المهارات والتدريب';

  @override
  String get game_prefs_type_leagues => 'دوريات';

  @override
  String get game_prefs_type_leagues_sub => 'منافسات تمتد طوال الموسم';

  @override
  String get game_prefs_type_friendly => 'مباريات ودية';

  @override
  String get game_prefs_type_friendly_sub => 'مباريات اجتماعية غير تنافسية';

  @override
  String get game_prefs_type_camps => 'معسكرات تدريب';

  @override
  String get game_prefs_type_camps_sub => 'ورش مهارات مكثفة';

  @override
  String get game_prefs_duration_header => 'مدة المباراة';

  @override
  String get game_prefs_duration_note => 'كم تفضل أن تستمر المباريات؟';

  @override
  String get game_prefs_duration_short => 'مباريات قصيرة';

  @override
  String get game_prefs_duration_short_sub => '30-60 دقيقة';

  @override
  String get game_prefs_duration_medium => 'مباريات متوسطة';

  @override
  String get game_prefs_duration_medium_sub => '60-90 دقيقة';

  @override
  String get game_prefs_duration_long => 'مباريات طويلة';

  @override
  String get game_prefs_duration_long_sub => 'أكثر من 90 دقيقة';

  @override
  String get game_prefs_duration_flexible => 'مدة مرنة';

  @override
  String get game_prefs_duration_flexible_sub => 'أي مدة';

  @override
  String get game_prefs_duration_custom => 'نطاق مدة مخصص';

  @override
  String get game_prefs_duration_min => 'أقل مدة';

  @override
  String get game_prefs_duration_max => 'أطول مدة';

  @override
  String game_prefs_minutes_hint(String value) {
    return '$value د';
  }

  @override
  String get game_prefs_minutes_suffix => 'د';

  @override
  String get game_prefs_team_header => 'حجم الفريق';

  @override
  String get game_prefs_team_note => 'ما أحجام الفرق التي تفضلها؟';

  @override
  String get game_prefs_team_flexible => 'حجم فريق مرن';

  @override
  String get game_prefs_team_flexible_sub => 'منفتح على أحجام فرق مختلفة';

  @override
  String game_prefs_team_preferred(String low, String high) {
    return 'عدد اللاعبين المفضل في الفريق: $low - $high';
  }

  @override
  String get game_prefs_team_min_label => 'لاعبان';

  @override
  String get game_prefs_team_max_label => '22 لاعبًا';

  @override
  String get game_prefs_level_header => 'مستوى المنافسة';

  @override
  String get game_prefs_level_note => 'ما مستوى المنافسة الذي تفضله؟';

  @override
  String get game_prefs_level_casual => 'ترفيهي';

  @override
  String get game_prefs_level_casual_sub => 'للمتعة فقط، أجواء مريحة';

  @override
  String get game_prefs_level_recreational => 'هواة';

  @override
  String get game_prefs_level_recreational_sub => 'منافسة ودية بحدة معتدلة';

  @override
  String get game_prefs_level_competitive => 'تنافسي';

  @override
  String get game_prefs_level_competitive_sub => 'منافسة جادة بحدة عالية';

  @override
  String get game_prefs_level_professional => 'محترف';

  @override
  String get game_prefs_level_professional_sub => 'منافسة بمستوى النخبة';

  @override
  String get game_prefs_equipment_header => 'المعدات';

  @override
  String get game_prefs_equipment_note => 'ما احتياجاتك من المعدات؟';

  @override
  String get game_prefs_equipment_own => 'لدي معداتي الخاصة';

  @override
  String get game_prefs_equipment_own_sub => 'يمكنك إحضار معداتك';

  @override
  String get game_prefs_equipment_provide => 'أستطيع توفير معدات للآخرين';

  @override
  String get game_prefs_equipment_provide_sub =>
      'يمكنك مشاركة المعدات مع زملائك';

  @override
  String get game_prefs_equipment_need => 'أحتاج إلى توفير المعدات';

  @override
  String get game_prefs_equipment_need_sub => 'يجب أن تتوفر المعدات في الملعب';

  @override
  String get game_prefs_equipment_types => 'أنواع المعدات';

  @override
  String get game_prefs_equipment_ball => 'كرة';

  @override
  String get game_prefs_equipment_gear => 'معدات الحماية';

  @override
  String get game_prefs_equipment_uniforms => 'أزياء';

  @override
  String get game_prefs_equipment_goals => 'مرامٍ';

  @override
  String get game_prefs_equipment_nets => 'شباك';

  @override
  String get game_prefs_equipment_markers => 'علامات';

  @override
  String get game_prefs_referee_header => 'التحكيم';

  @override
  String get game_prefs_referee_note => 'كيف تفضل أن تُدار المباريات؟';

  @override
  String get game_prefs_referee_prefer => 'أفضّل المباريات بحكم';

  @override
  String get game_prefs_referee_prefer_sub => 'حكم رسمي لضمان اللعب النظيف';

  @override
  String get game_prefs_referee_can => 'أستطيع تحكيم المباريات';

  @override
  String get game_prefs_referee_can_sub => 'أنت مؤهل للتحكيم';

  @override
  String get game_prefs_referee_strict => 'تطبيق صارم للقواعد';

  @override
  String get game_prefs_referee_strict_sub =>
      'يجب أن تتبع المباريات القواعد الرسمية بدقة';

  @override
  String get composer_cancel => 'إلغاء';

  @override
  String get composer_confirm => 'تأكيد';

  @override
  String get composer_clear => 'مسح';

  @override
  String get composer_none => 'لا شيء';

  @override
  String get composer_select => 'اختيار';

  @override
  String get composer_tap_to_change => 'اضغط للتغيير.';

  @override
  String get composer_create_post => 'منشور جديد';

  @override
  String get composer_post_cta => 'نشر';

  @override
  String get composer_you => 'أنت';

  @override
  String get composer_post_as => 'النشر باسم';

  @override
  String get composer_switch_failed => 'تعذّر تبديل الملف الشخصي';

  @override
  String get composer_body_hint => 'ما الذي يدور في بالك؟ استخدم #الوسوم';

  @override
  String get composer_add_media => 'إضافة وسائط';

  @override
  String get composer_add_vibe => 'إضافة أجواء';

  @override
  String get composer_add_sport => 'إضافة رياضة';

  @override
  String get composer_add_location => 'إضافة موقع';

  @override
  String get composer_link_game => 'ربط مباراة';

  @override
  String get composer_add_more_media => 'إضافة المزيد من الوسائط';

  @override
  String get composer_remove_media => 'إزالة الوسائط';

  @override
  String get composer_allow_reposts => 'السماح بإعادة النشر';

  @override
  String get composer_allow_reposts_sub => 'يمكن للآخرين مشاركة هذا المنشور';

  @override
  String get composer_pin => 'تثبيت في الملف الشخصي';

  @override
  String get composer_pin_sub => 'يبقى في أعلى ملفك الشخصي';

  @override
  String get composer_expiry => 'تحديد الانتهاء';

  @override
  String get composer_expiry_sub => 'يُخفى تلقائيًا بعد التاريخ';

  @override
  String get composer_who_can_see => 'من يمكنه رؤية هذا؟';

  @override
  String get composer_which_sport => 'أي رياضة؟';

  @override
  String get composer_kind_of_post => 'أي نوع من المنشورات؟';

  @override
  String get composer_link_a_game => 'ربط مباراة';

  @override
  String get composer_location => 'الموقع';

  @override
  String get composer_add_media_title => 'إضافة وسائط';

  @override
  String get composer_take_photo => 'التقاط صورة';

  @override
  String get composer_choose_gallery => 'اختيار من المعرض';

  @override
  String get composer_search_gifs => 'البحث عن صور GIF';

  @override
  String get composer_powered_giphy => 'بدعم من GIPHY';

  @override
  String get composer_vis_public => 'عام';

  @override
  String get composer_vis_followers => 'المتابعون';

  @override
  String get composer_vis_circle => 'الدائرة';

  @override
  String get composer_vis_squad => 'الفريق';

  @override
  String get composer_vis_private => 'خاص';

  @override
  String get composer_vis_link => 'الرابط فقط';

  @override
  String get composer_vis_public_sub => 'يمكن للجميع رؤية هذا المنشور';

  @override
  String get composer_vis_followers_sub => 'متابعوك فقط يمكنهم رؤيته';

  @override
  String get composer_vis_circle_sub => 'مشارك مع دائرة محددة';

  @override
  String get composer_vis_squad_sub => 'مشارك مع فريقك';

  @override
  String get composer_vis_private_sub => 'أنت فقط يمكنك رؤيته';

  @override
  String get composer_vis_link_sub => 'فقط من لديه الرابط يمكنه رؤيته';

  @override
  String get composer_type_moment => 'لحظة';

  @override
  String get composer_type_dab => 'داب';

  @override
  String get composer_type_kickin => 'انضمام';

  @override
  String get composer_type_moment_sub => 'لقطة سريعة من اللحظة';

  @override
  String get composer_type_dab_sub => 'شارك ما يلهمك الآن';

  @override
  String get composer_type_kickin_sub => 'ادعُ الآخرين للانضمام';

  @override
  String get composer_vibe_search => 'البحث عن أجواء';

  @override
  String get composer_vibe_failed => 'تعذّر تحميل الأجواء';

  @override
  String get composer_vibe_none => 'لا توجد أجواء مطابقة';

  @override
  String get composer_sports_failed => 'تعذّر تحميل الرياضات';

  @override
  String get composer_sports_none => 'لا توجد رياضات متاحة';

  @override
  String get composer_venue_search => 'البحث عن ملاعب…';

  @override
  String get composer_type_location => 'اكتب موقعًا';

  @override
  String get composer_use_location => 'استخدام هذا الموقع';

  @override
  String get composer_search_failed => 'فشل البحث';

  @override
  String get composer_no_venues => 'لا توجد ملاعب';

  @override
  String get composer_venue => 'الملعب';

  @override
  String get composer_venue_hint => 'ابحث عن ملعب أو اكتب موقعًا';

  @override
  String get composer_games_search => 'البحث عن مباراة بالعنوان…';

  @override
  String get composer_no_games => 'لا توجد مباريات';

  @override
  String get composer_untitled_game => 'مباراة بلا عنوان';

  @override
  String get composer_games_hint => 'ابحث عن مباراة لربطها بمنشورك';

  @override
  String get game_create => 'مباراة جديدة';

  @override
  String get game_edit => 'تعديل المباراة';

  @override
  String get game_save_changes => 'حفظ التغييرات';

  @override
  String get game_sport => 'الرياضة';

  @override
  String get game_format => 'الصيغة';

  @override
  String get game_format_sub => 'صيغة المباراة';

  @override
  String get game_select_sport_first => 'اختر الرياضة أولًا';

  @override
  String get game_select_format => 'اختر الصيغة';

  @override
  String get game_venue_sub => 'أين ستُلعب';

  @override
  String get game_date_time => 'التاريخ والوقت';

  @override
  String get game_date_time_sub => 'متى المباراة';

  @override
  String get game_duration => 'المدة';

  @override
  String get game_duration_sub => 'كم تستغرق';

  @override
  String get game_join_policy => 'سياسة الانضمام';

  @override
  String get game_join_open => 'مفتوح';

  @override
  String get game_join_request => 'بطلب';

  @override
  String get game_join_invite => 'بدعوة';

  @override
  String get game_join_link => 'برابط';

  @override
  String get game_visibility => 'الظهور';

  @override
  String get game_skill_level => 'المستوى';

  @override
  String get game_skill_sub => 'خبرة اللاعبين';

  @override
  String get game_any_level => 'أي مستوى';

  @override
  String get game_players => 'اللاعبون';

  @override
  String get game_players_sub => 'الحد الأدنى والأقصى';

  @override
  String get game_fewer_min => 'تقليل الحد الأدنى';

  @override
  String get game_more_min => 'زيادة الحد الأدنى';

  @override
  String get game_fewer_max => 'تقليل الحد الأقصى';

  @override
  String get game_more_max => 'زيادة الحد الأقصى';

  @override
  String get game_waitlist => 'قائمة الانتظار';

  @override
  String get game_waitlist_sub => 'دع اللاعبين ينتظرون عند الامتلاء';

  @override
  String get game_spectators => 'المتفرجون';

  @override
  String get game_spectators_sub => 'السماح للمتفرجين بالمشاهدة';

  @override
  String get game_details => 'التفاصيل (اختياري)';

  @override
  String get game_title_hint => 'عنوان المباراة';

  @override
  String get game_note_hint => 'أضف ملاحظة للاعبين…';

  @override
  String get game_date => 'التاريخ';

  @override
  String get game_time => 'الوقت';

  @override
  String get game_today => 'اليوم';

  @override
  String get game_tomorrow => 'غدًا';

  @override
  String get game_select_venue => 'اختيار الملعب';

  @override
  String get game_select_format_title => 'اختيار الصيغة';

  @override
  String get game_no_formats => 'لا توجد صيغ متاحة';

  @override
  String get game_no_matches => 'لا توجد نتائج';

  @override
  String get game_skill_beginner => 'مبتدئ';

  @override
  String get game_skill_intermediate => 'متوسط';

  @override
  String get game_skill_advanced => 'متقدم';

  @override
  String get game_skill_pro => 'محترف';

  @override
  String get game_skill_beginner_sub => 'بدأ للتو';

  @override
  String get game_skill_intermediate_sub => 'يلعب بانتظام';

  @override
  String get game_skill_advanced_sub => 'مستوى تنافسي';

  @override
  String get game_skill_pro_sub => 'نخبة / احترافي';

  @override
  String get post_detail_title => 'المنشور';

  @override
  String get post_detail_more => 'خيارات إضافية';

  @override
  String get post_detail_follow => 'تابع';

  @override
  String get post_detail_following => 'تتابعه';

  @override
  String get post_detail_anonymous => 'مجهول';

  @override
  String get post_detail_no_replies => 'لا توجد ردود بعد';

  @override
  String get post_detail_first_reply => 'كن أول من يرد.';

  @override
  String get post_detail_reply_hint => 'اكتب ردك…';

  @override
  String get post_detail_reply_to_hint => 'رد…';

  @override
  String get post_detail_add_image => 'إضافة صورة';

  @override
  String get post_detail_add_location => 'إضافة موقع';

  @override
  String get post_detail_send_reply => 'إرسال الرد';

  @override
  String get post_detail_reply => 'رد';

  @override
  String get post_detail_add => 'إضافة';

  @override
  String get post_detail_hide_replies => 'إخفاء الردود';

  @override
  String get post_detail_view_replies => 'عرض الردود';

  @override
  String get post_detail_copy_link => 'نسخ الرابط';

  @override
  String get post_detail_link_copied => 'تم نسخ الرابط';

  @override
  String get post_detail_delete_post => 'حذف المنشور';

  @override
  String get post_detail_delete_reply => 'حذف الرد';

  @override
  String get post_detail_report => 'إبلاغ';

  @override
  String get post_detail_edited => 'معدّل';

  @override
  String get post_detail_failed => 'تعذّر تحميل المنشور';

  @override
  String get post_detail_replies_failed => 'تعذّر تحميل الردود';

  @override
  String get post_detail_retry => 'أعد المحاولة';

  @override
  String get post_detail_remove_image => 'إزالة الصورة';

  @override
  String get post_detail_remove_location => 'إزالة الموقع';

  @override
  String get post_detail_image => 'صورة';

  @override
  String get post_detail_org => 'منظّم';

  @override
  String get post_detail_player => 'لاعب';

  @override
  String post_detail_replies_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رد',
      many: '$count ردًا',
      few: '$count ردود',
      two: 'ردان',
      one: 'رد واحد',
      zero: 'لا ردود',
    );
    return '$_temp0';
  }

  @override
  String post_detail_views(String count) {
    return 'المشاهدات: $count';
  }

  @override
  String get post_detail_replying_to => 'الرد على';

  @override
  String get post_detail_cancel_reply => 'إلغاء الرد';

  @override
  String get help_center_title => 'مركز المساعدة';

  @override
  String get help_center_empty_title => 'مركز المساعدة';

  @override
  String get help_center_empty_text => 'هذه الشاشة قيد التطوير';

  @override
  String get contact_title => 'التواصل مع الدعم';

  @override
  String get contact_intro_title => 'كيف يمكننا مساعدتك؟';

  @override
  String get contact_intro_message =>
      'أرسل لنا رسالة وسنرد عليك في أقرب وقت ممكن.';

  @override
  String get contact_section => 'بيانات التواصل';

  @override
  String get contact_email => 'بريدك الإلكتروني';

  @override
  String get contact_category => 'الفئة';

  @override
  String get contact_subject => 'الموضوع';

  @override
  String get contact_message => 'الرسالة';

  @override
  String get contact_send => 'إرسال الرسالة';

  @override
  String get contact_cat_general => 'عام';

  @override
  String get contact_cat_account => 'مشاكل الحساب';

  @override
  String get contact_cat_technical => 'مشكلة تقنية';

  @override
  String get contact_cat_billing => 'الدفع والفواتير';

  @override
  String get contact_cat_feature => 'طلب ميزة';

  @override
  String get contact_cat_abuse => 'الإبلاغ عن إساءة';

  @override
  String get contact_cat_privacy => 'مخاوف الخصوصية';

  @override
  String get contact_cat_other => 'أخرى';

  @override
  String get contact_err_email_required => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get contact_err_email_invalid => 'يرجى إدخال بريد إلكتروني صالح';

  @override
  String get contact_err_subject_required => 'يرجى إدخال الموضوع';

  @override
  String get contact_err_message_required => 'يرجى إدخال رسالتك';

  @override
  String get contact_err_message_short => 'يجب ألا تقل الرسالة عن 10 أحرف';

  @override
  String get contact_sent => 'تم إرسال الرسالة. سنرد عليك قريبًا.';

  @override
  String contact_send_failed(String error) {
    return 'تعذّر إرسال الرسالة: $error';
  }

  @override
  String get bug_title => 'الإبلاغ عن خطأ';

  @override
  String get bug_intro_title => 'وجدت خطأ؟';

  @override
  String get bug_intro_message =>
      'ساعدنا على التحسّن بالإبلاغ عن أي مشكلة تواجهها. كلما زادت التفاصيل أسرعنا في إصلاحها.';

  @override
  String get bug_details => 'تفاصيل الخطأ';

  @override
  String get bug_category => 'فئة الخطأ';

  @override
  String get bug_severity => 'مستوى الخطورة';

  @override
  String get bug_field_title => 'عنوان الخطأ';

  @override
  String get bug_field_title_hint => 'وصف موجز للمشكلة';

  @override
  String get bug_field_description => 'وصف تفصيلي';

  @override
  String get bug_field_description_hint => 'صف ما حدث وما كنت تتوقع حدوثه';

  @override
  String get bug_field_steps => 'خطوات إعادة إنتاج المشكلة';

  @override
  String get bug_field_steps_hint =>
      '1. اذهب إلى...\n2. اضغط على...\n3. شاهد الخطأ';

  @override
  String get bug_cat_general => 'خطأ عام';

  @override
  String get bug_cat_ui => 'مشكلة في الواجهة';

  @override
  String get bug_cat_performance => 'مشكلة في الأداء';

  @override
  String get bug_cat_crash => 'تعطّل / تجمّد';

  @override
  String get bug_cat_login => 'تسجيل الدخول / التوثيق';

  @override
  String get bug_cat_profile => 'الملف / الإعدادات';

  @override
  String get bug_cat_games => 'المباريات / الأنشطة';

  @override
  String get bug_cat_notifications => 'الإشعارات';

  @override
  String get bug_cat_social => 'الميزات الاجتماعية';

  @override
  String get bug_cat_other => 'أخرى';

  @override
  String get bug_sev_low => 'منخفضة';

  @override
  String get bug_sev_medium => 'متوسطة';

  @override
  String get bug_sev_high => 'عالية';

  @override
  String get bug_sev_critical => 'حرجة';

  @override
  String get bug_additional => 'معلومات إضافية';

  @override
  String get bug_include_device => 'تضمين معلومات الجهاز';

  @override
  String get bug_include_device_sub => 'إصدار النظام، طراز الجهاز، حجم الشاشة';

  @override
  String get bug_include_logs => 'تضمين سجلات التطبيق';

  @override
  String get bug_include_logs_sub => 'نشاط التطبيق الأخير وسجلات الأخطاء';

  @override
  String get bug_device_heading => 'معلومات الجهاز المضمّنة:';

  @override
  String bug_device_platform(String value) {
    return 'المنصة: $value';
  }

  @override
  String bug_device_app_version(String value) {
    return 'إصدار التطبيق: $value';
  }

  @override
  String bug_device_resolution(String value) {
    return 'دقة الشاشة: $value';
  }

  @override
  String get bug_platform_unknown => 'غير معروف';

  @override
  String get bug_platform_web => 'الويب';

  @override
  String get bug_err_email_required => 'يرجى إدخال بريدك الإلكتروني';

  @override
  String get bug_err_title_required => 'يرجى إدخال عنوان الخطأ';

  @override
  String get bug_err_description_required => 'يرجى وصف الخطأ';

  @override
  String get bug_err_description_short =>
      'يرجى تقديم مزيد من التفاصيل (20 حرفًا على الأقل)';

  @override
  String get bug_err_steps_required => 'يرجى ذكر خطوات إعادة إنتاج المشكلة';

  @override
  String get bug_submit => 'إرسال بلاغ الخطأ';

  @override
  String get bug_submitted =>
      'تم إرسال البلاغ. شكرًا لمساعدتك في تحسين التطبيق.';

  @override
  String bug_submit_failed(String error) {
    return 'تعذّر إرسال البلاغ: $error';
  }

  @override
  String get sports_prefs_title => 'تفضيلات الرياضات';

  @override
  String get sports_prefs_save => 'حفظ';

  @override
  String get sports_prefs_create_game => 'إنشاء مباراة';

  @override
  String get sports_prefs_my_sports => 'رياضاتي';

  @override
  String get sports_prefs_my_sports_note =>
      'فعّل الرياضات التي تريد ممارستها وحدد مستواك';

  @override
  String get sports_prefs_general => 'تفضيلات عامة';

  @override
  String get sports_prefs_auto_join => 'الانضمام التلقائي للمباريات المناسبة';

  @override
  String get sports_prefs_auto_join_sub =>
      'انضم تلقائيًا إلى المباريات التي تطابق تفضيلاتك';

  @override
  String get sports_prefs_location => 'استخدام الموقع للتوصيات';

  @override
  String get sports_prefs_location_sub =>
      'اعثر على مباريات قريبة من موقعك الحالي';

  @override
  String get sports_prefs_flexible => 'توقيت مرن';

  @override
  String get sports_prefs_flexible_sub =>
      'أظهر المباريات ذات أوقات البدء المرنة';

  @override
  String get sports_prefs_disabled => 'معطّل';

  @override
  String get sports_prefs_skill_level => 'المستوى';

  @override
  String get sports_prefs_position => 'المركز المفضل';

  @override
  String get sports_prefs_level_beginner => 'مبتدئ';

  @override
  String get sports_prefs_level_intermediate => 'متوسط';

  @override
  String get sports_prefs_level_advanced => 'متقدم';

  @override
  String sports_prefs_load_failed(String error) {
    return 'تعذّر تحميل تفضيلات الرياضات: $error';
  }

  @override
  String get sports_prefs_saved => 'تم حفظ تفضيلات الرياضات';

  @override
  String sports_prefs_save_failed(String error) {
    return 'تعذّر حفظ التفضيلات: $error';
  }

  @override
  String sports_prefs_enable_failed(String error) {
    return 'تعذّر تفعيل الرياضة: $error';
  }

  @override
  String sports_prefs_remove_failed(String error) {
    return 'تعذّرت إزالة الرياضة: $error';
  }

  @override
  String get sports_prefs_need_one => 'يجب تفعيل رياضة واحدة على الأقل';

  @override
  String sports_prefs_remove_title(String sport) {
    return 'إزالة $sport؟';
  }

  @override
  String sports_prefs_remove_body(String sport) {
    return 'هل تريد بالتأكيد إزالة $sport من ملفك؟';
  }

  @override
  String get sports_prefs_cancel => 'إلغاء';

  @override
  String get sports_prefs_remove => 'إزالة';

  @override
  String get sports_pos_goalkeeper => 'حارس مرمى';

  @override
  String get sports_pos_defender => 'مدافع';

  @override
  String get sports_pos_midfielder => 'لاعب وسط';

  @override
  String get sports_pos_forward => 'مهاجم';

  @override
  String get sports_pos_point_guard => 'صانع ألعاب';

  @override
  String get sports_pos_shooting_guard => 'مدافع مسدد';

  @override
  String get sports_pos_small_forward => 'جناح';

  @override
  String get sports_pos_power_forward => 'جناح قوي';

  @override
  String get sports_pos_center => 'ارتكاز';

  @override
  String get sports_pos_setter => 'معدّ';

  @override
  String get sports_pos_outside_hitter => 'مهاجم خارجي';

  @override
  String get sports_pos_middle_blocker => 'حاجز أوسط';

  @override
  String get sports_pos_opposite_hitter => 'مهاجم معاكس';

  @override
  String get sports_pos_libero => 'ليبرو';

  @override
  String get about_terms_intro =>
      'يرجى قراءة هذه الشروط بعناية قبل استخدام خدمتنا.';

  @override
  String get about_privacy_intro =>
      'خصوصيتك مهمة بالنسبة لنا. توضح هذه السياسة كيف نجمع معلوماتك ونستخدمها ونحميها.';

  @override
  String about_last_updated(String date) {
    return 'آخر تحديث: $date';
  }

  @override
  String get about_privacy_settings_tooltip => 'إعدادات الخصوصية';

  @override
  String get licenses_title => 'تراخيص المصادر المفتوحة';

  @override
  String get licenses_about_tooltip => 'حول التراخيص';

  @override
  String get licenses_intro =>
      'بُني هذا التطبيق بمكتبات مفتوحة المصدر رائعة. نشكر جميع المساهمين على عملهم.';

  @override
  String licenses_count(String count) {
    return 'الحزم مفتوحة المصدر: $count';
  }

  @override
  String get licenses_search_hint => 'ابحث في التراخيص...';

  @override
  String get licenses_empty_title => 'لم يتم العثور على تراخيص';

  @override
  String get licenses_empty_text => 'جرّب تعديل عبارة البحث';

  @override
  String get licenses_info_title => 'حول تراخيص المصادر المفتوحة';

  @override
  String get licenses_info_body =>
      'يستخدم هذا التطبيق مكتبات وحزمًا مفتوحة المصدر متعددة. يحدد كل ترخيص شروط استخدام الشيفرة وتعديلها وتوزيعها.\n\nنحن ممتنون لجميع المطورين والمساهمين الذين يتيحون أعمالهم بتراخيص مفتوحة المصدر.';

  @override
  String get licenses_got_it => 'حسنًا';

  @override
  String get licenses_detail_version => 'الإصدار';

  @override
  String get licenses_detail_license => 'الترخيص';

  @override
  String get licenses_detail_copyright => 'حقوق النشر';

  @override
  String get licenses_detail_url => 'الرابط';

  @override
  String get licenses_detail_description => 'الوصف';

  @override
  String get licenses_view_web => 'عرض على الويب';

  @override
  String licenses_opening(String url) {
    return 'جارٍ فتح $url';
  }

  @override
  String get sfx_search_placeholder => 'ابحث عن أشخاص ومباريات ومنشورات…';

  @override
  String get sfx_recent => 'الأخيرة';

  @override
  String get sfx_clear => 'مسح';

  @override
  String sfx_remove_recent(String query) {
    return 'إزالة $query';
  }

  @override
  String get sfx_quick_filters => 'فلاتر سريعة';

  @override
  String get sfx_near_me => 'بالقرب مني';

  @override
  String get sfx_today => 'اليوم';

  @override
  String get sfx_this_week => 'هذا الأسبوع';

  @override
  String get sfx_friends_only => 'الأصدقاء فقط';

  @override
  String get sfx_popular => 'شائع';

  @override
  String get sfx_free_entry => 'دخول مجاني';

  @override
  String get sfx_people_nearby => 'أشخاص بالقرب منك';

  @override
  String get sfx_people_nearby_sub => 'اعثر على لاعبين قريبين منك';

  @override
  String get sfx_popular_games => 'المباريات الشائعة';

  @override
  String get sfx_popular_games_sub => 'أماكن متاحة اليوم';

  @override
  String get sfx_trending_posts => 'المنشورات الرائجة';

  @override
  String get sfx_trending_posts_sub => 'ما يتحدث عنه الجميع';

  @override
  String get sfx_showing_results_for => 'عرض النتائج لـ';

  @override
  String get sfx_view_all => 'عرض الكل';

  @override
  String get sfx_people => 'الأشخاص';

  @override
  String get sfx_hashtags => 'الوسوم';

  @override
  String get sfx_games => 'المباريات';

  @override
  String get sfx_venues => 'الملاعب';

  @override
  String get sfx_posts => 'المنشورات';

  @override
  String get sfx_comments => 'التعليقات';

  @override
  String get sfx_meetups => 'اللقاءات';

  @override
  String get sfx_follow => 'تابع';

  @override
  String get sfx_join => 'انضم';

  @override
  String get sfx_kind_game => 'المباراة';

  @override
  String get sfx_kind_meetup => 'لقاء';

  @override
  String get sfx_spots => 'أماكن';

  @override
  String sfx_spots_meta(int joined, int max) {
    return '$joined/$max أماكن';
  }

  @override
  String sfx_posts_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '‏$count منشور',
      many: '‏$count منشورًا',
      few: '‏$count منشورات',
      two: '‏منشوران',
      one: '‏منشور واحد',
    );
    return '$_temp0';
  }

  @override
  String sfx_on_post(String title) {
    return 'على $title';
  }

  @override
  String sfx_no_results_for(String query) {
    return 'لا نتائج لـ \"$query\"';
  }

  @override
  String sfx_none_found(String label) {
    return 'لم يتم العثور على $label';
  }

  @override
  String sfx_list_header(int count, String label, String query) {
    return '$count $label لـ \"$query\"';
  }

  @override
  String sfx_hashtag_empty(String slug) {
    return 'لا منشورات للوسم #$slug';
  }

  @override
  String get sfx_retry => 'أعد المحاولة';

  @override
  String get sfx_news => 'أخبار';

  @override
  String get sfx_add_comment => 'أضف تعليقًا';

  @override
  String get sfx_discuss => 'ناقش';

  @override
  String get sfx_be_first => 'كن أول من يعلّق.';

  @override
  String get sfx_like => 'إعجاب';

  @override
  String get sfx_send => 'إرسال';

  @override
  String get sfx_share => 'مشاركة';

  @override
  String get sfx_share_article => 'مشاركة المقال';

  @override
  String get sfx_copy_link => 'نسخ الرابط';

  @override
  String get sfx_share_to => 'مشاركة عبر…';

  @override
  String get sfx_link_copied => 'تم نسخ الرابط';

  @override
  String get sfx_events => 'المباريات واللقاءات';

  @override
  String get composer_place_search => 'ابحث عن ملاعب ومناطق';

  @override
  String get composer_results => 'النتائج';

  @override
  String get composer_places_none => 'لا توجد أماكن تطابق هذا البحث';

  @override
  String get composer_pick_date => 'اختر تاريخًا';

  @override
  String get composer_pick_time => 'اختر وقتًا';

  @override
  String get composer_step_1 => 'الخطوة 1 من 2';

  @override
  String get composer_step_2 => 'الخطوة 2 من 2';

  @override
  String get composer_kickoff_time => 'موعد البداية';

  @override
  String get composer_continue_time => 'المتابعة إلى الوقت';

  @override
  String get composer_done => 'تم';

  @override
  String composer_use_typed(String query) {
    return 'استخدام «$query»';
  }

  @override
  String composer_format_title(String sport) {
    return 'صيغة $sport';
  }

  @override
  String composer_players_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count لاعب',
      many: '$count لاعبًا',
      few: '$count لاعبين',
      zero: '$count لاعب',
      two: 'لاعبان',
      one: 'لاعب واحد',
    );
    return '$_temp0';
  }

  @override
  String sfx_comments_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعليق',
      many: '$count تعليقًا',
      few: '$count تعليقات',
      two: 'تعليقان',
      one: 'تعليق واحد',
      zero: 'لا تعليقات',
    );
    return '$_temp0';
  }

  @override
  String get profile_section_my_sports => 'رياضاتي';

  @override
  String get profile_section_their_sports => 'رياضاتهم';

  @override
  String get profile_btn_manage => 'إدارة';

  @override
  String get profile_sport_picker_all => 'كل الرياضات';

  @override
  String get profile_stat_rated => 'تقييم اللاعبين';

  @override
  String get profile_stat_primary_sports => 'الرياضات الأساسية';

  @override
  String profile_stat_sport_matches(String sport) {
    return 'مباريات $sport';
  }

  @override
  String get profile_create_another_profile => 'إنشاء ملف شخصي آخر';

  @override
  String profile_create_persona_profile(String persona) {
    return 'إنشاء ملف $persona';
  }

  @override
  String sport_profile_overall_level(String sport, String level) {
    return '$sport · المستوى العام $level';
  }

  @override
  String get profile_sports_followed_note =>
      'الرياضات المتابَعة — للأخبار والنتائج فقط';

  @override
  String get profile_stat_sports_followed => 'الرياضات المتابَعة';

  @override
  String get profile_stat_minutes_played => 'دقائق اللعب';

  @override
  String get meetups_tab_all => 'الكل';

  @override
  String get meetups_none_title => 'لا توجد لقاءات متاحة.';

  @override
  String get meetups_explore_another => 'استكشف نشاطًا آخر';

  @override
  String get meetups_load_failed => 'تعذّر تحميل اللقاءات';

  @override
  String get meetups_join => 'انضم للقاء';

  @override
  String get meetups_request => 'اطلب الانضمام';

  @override
  String meetups_going_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مشارك',
      many: '$count مشاركًا',
      few: '$count مشاركين',
      two: 'مشاركان',
      one: 'مشارك واحد',
    );
    return '$_temp0';
  }

  @override
  String meetups_max(int count) {
    return 'حتى $count';
  }

  @override
  String get meetups_free_note => 'بدون رسوم';

  @override
  String meetups_distance_km(String km) {
    return '$km كم';
  }

  @override
  String get meetups_cta_going => 'مشارك';

  @override
  String get meetups_cta_interested => 'ربما أشارك';

  @override
  String get meetups_cta_full => 'مكتمل - أنت مهتم';

  @override
  String get meetups_cta_closed => 'التسجيل مغلق';

  @override
  String get meetups_cta_cancelled => 'ملغى';

  @override
  String get meetups_cta_started => 'بدأ بالفعل';

  @override
  String get meetups_cta_unavailable => 'غير متاح';

  @override
  String get meetups_cta_not_allowed => 'بدّل الملف الشخصي للانضمام';

  @override
  String get meetups_sheet_title => 'هل ستشارك في هذا اللقاء؟';

  @override
  String get meetups_sheet_cancel => 'إلغاء';

  @override
  String get meetups_sheet_yes => 'نعم، سأشارك';

  @override
  String get meetups_sheet_maybe => 'ربما';

  @override
  String get meetups_sheet_no => 'لا، ليس هذه المرة';

  @override
  String get meetups_sheet_confirm => 'تأكيد';

  @override
  String get meetups_error_generic => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get meetups_error_cancelled => 'أُلغي هذا اللقاء.';

  @override
  String get meetups_host_caption => 'مضيف مجتمعي';

  @override
  String get meetups_tile_meeting_point => 'نقطة اللقاء';

  @override
  String get meetups_tile_entry => 'الدخول';

  @override
  String get meetups_load_detail_failed => 'تعذّر تحميل هذا اللقاء';

  @override
  String get meetups_back => 'رجوع';

  @override
  String meetups_names_and_others(String names, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$names و$count شخص آخر',
      many: '$names و$count شخصًا آخر',
      few: '$names و$count أشخاص آخرين',
      two: '$names وشخصان آخران',
      one: '$names وشخص آخر',
    );
    return '$_temp0';
  }

  @override
  String meetups_show_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض $count لقاء',
      many: 'عرض $count لقاءً',
      few: 'عرض $count لقاءات',
      two: 'عرض لقاءين',
      one: 'عرض لقاء واحد',
    );
    return '$_temp0';
  }

  @override
  String meetups_km_away(String km) {
    return 'على بعد $km كم';
  }

  @override
  String get meetups_create_title => 'لقاء جديد';

  @override
  String get meetups_create_title_hint => 'عنوان اللقاء';

  @override
  String get meetups_create_note_hint => 'أضف وصفًا موجزًا للمشاركين...';

  @override
  String get meetups_create_name_section => 'اختر الاسم والوصف';

  @override
  String get meetups_when => 'الموعد';

  @override
  String get meetups_when_sub => 'التاريخ والوقت';

  @override
  String get meetups_end => 'النهاية';

  @override
  String get meetups_location => 'الموقع';

  @override
  String get meetups_location_sub => 'أضف موقعًا أو ملعبًا';

  @override
  String get meetups_capacity => 'السعة';

  @override
  String get meetups_capacity_sub => 'الحد الأقصى للمشاركين';

  @override
  String get meetups_advanced => 'خيارات متقدمة';

  @override
  String get meetups_policy => 'طريقة الانضمام';

  @override
  String get meetups_policy_sub => 'إعدادات الانضمام';

  @override
  String get meetups_policy_closed => 'مغلق';

  @override
  String get meetups_skill => 'نطاق المهارة';

  @override
  String get meetups_skill_sub => 'مستوى الخبرة';

  @override
  String get meetups_skill_any => 'أي مستوى';

  @override
  String get meetups_vibe => 'الأجواء';

  @override
  String get meetups_vibe_sub => 'حدّد الأجواء';

  @override
  String get meetups_vibe_choose => 'اختر';

  @override
  String get meetups_create_failed => 'تعذّر إنشاء اللقاء';

  @override
  String get meetups_visibility => 'من يمكنه رؤيته';

  @override
  String get meetups_visibility_sub => 'إعدادات الظهور';

  @override
  String get meetups_cost => 'التكلفة';

  @override
  String get meetups_cost_sub => 'رسوم الدخول';

  @override
  String get meetups_err_location_required => 'أضف موقعًا للقاء.';

  @override
  String get meetups_sports_failed =>
      'تعذّر تحميل الرياضات. حاول مرة أخرى لاحقًا.';

  @override
  String get game_err_create_refused =>
      'لا يمكنك إنشاء مباراة الآن. حاول مرة أخرى لاحقًا.';

  @override
  String get meetups_err_create_refused =>
      'لا يمكنك إنشاء هذا اللقاء الآن. حاول مرة أخرى لاحقًا.';

  @override
  String get meetups_err_title_invalid =>
      'يجب أن يتراوح العنوان بين 3 و80 حرفًا.';

  @override
  String get meetups_err_invalid_time_range =>
      'يجب أن يكون وقت النهاية بعد وقت البداية.';

  @override
  String get meetups_err_invalid_capacity => 'يجب ألا تقل السعة عن 1.';

  @override
  String get meetups_err_auth_required => 'سجّل الدخول للمتابعة.';

  @override
  String get meetups_err_unsupported => 'هذا الخيار غير متاح بعد.';

  @override
  String get meetups_manage => 'إدارة اللقاء';

  @override
  String get meetups_manage_title => 'إدارة اللقاء';

  @override
  String get meetups_section_going => 'المشاركون';

  @override
  String get meetups_section_interested => 'المهتمون';

  @override
  String get meetups_section_pending => 'الطلبات';

  @override
  String get meetups_manage_empty => 'لم يرد أحد بعد.';

  @override
  String get meetups_approve => 'قبول';

  @override
  String get meetups_decline => 'رفض';

  @override
  String get meetups_remove => 'إزالة';

  @override
  String meetups_remove_title(String name) {
    return 'إزالة $name؟';
  }

  @override
  String get meetups_remove_body => 'سيفقد مكانه وسيتلقى إشعارًا بذلك.';

  @override
  String get meetups_edit => 'تعديل اللقاء';

  @override
  String get meetups_save => 'حفظ التغييرات';

  @override
  String get meetups_cancel_meetup => 'إلغاء اللقاء';

  @override
  String get meetups_cancel_title => 'هل تريد إلغاء هذا اللقاء؟';

  @override
  String get meetups_cancel_body =>
      'سيُبلَّغ جميع من ردّوا. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get meetups_cancel_confirm => 'إلغاء اللقاء';

  @override
  String get meetups_keep => 'إبقاء اللقاء';

  @override
  String get meetups_err_capacity_below_going =>
      'السعة أقل من عدد المشاركين الحاليين.';

  @override
  String get meetups_err_not_host => 'هذا الإجراء للمضيف فقط.';

  @override
  String get meetups_err_attendee_not_found => 'هذا الشخص لم يعد ضمن اللقاء.';

  @override
  String get meetups_err_no_pending => 'لم يعد هذا الطلب قيد الانتظار.';

  @override
  String get meetups_save_failed => 'تعذّر حفظ التغييرات';

  @override
  String get meetups_action_failed => 'لم تكتمل العملية. حاول مرة أخرى.';

  @override
  String get meetups_share => 'مشاركة';

  @override
  String meetups_share_headline(String title) {
    return 'انضم إليّ في $title على Dabbler!';
  }

  @override
  String get meetups_more => 'المزيد';

  @override
  String get meetups_report => 'الإبلاغ عن اللقاء';

  @override
  String get meetups_report_note => 'أخبرنا ما المشكلة في هذا اللقاء';

  @override
  String get venue_amenity_outdoor => 'ملعب مكشوف';

  @override
  String get venue_amenity_indoor => 'ملعب مغطى';

  @override
  String get venue_amenity_parking => 'مواقف سيارات';

  @override
  String get venue_amenity_washrooms => 'دورات مياه';

  @override
  String get venue_amenity_changing_rooms => 'غرف تبديل الملابس';

  @override
  String get venue_amenity_showers => 'أماكن الاستحمام';

  @override
  String get venue_amenity_lighting => 'الإضاءة';

  @override
  String get venue_amenity_cafeteria => 'كافتيريا';

  @override
  String get venue_amenity_wifi => 'واي فاي';

  @override
  String get venue_amenity_first_aid => 'الإسعافات الأولية';

  @override
  String get venue_amenity_accessibility => 'تسهيلات لذوي الإعاقة';

  @override
  String get venue_amenity_gym => 'صالة رياضية';

  @override
  String get venue_amenity_locker_room => 'غرفة الخزائن';

  @override
  String get venue_amenity_equipment_rental => 'تأجير المعدات';

  @override
  String get venue_amenity_air_conditioning => 'تكييف الهواء';

  @override
  String get venue_amenity_spectator_seating => 'مقاعد المشاهدين';

  @override
  String get venue_amenity_vending => 'آلات البيع';

  @override
  String get feedback_dismiss => 'إغلاق';

  @override
  String get feedback_joining => 'جارٍ الانضمام…';

  @override
  String get feedback_join_failed => 'تعذّر الانضمام إلى المباراة.';

  @override
  String checkin_done_day(int day, int total) {
    return 'تم تسجيل حضورك! اليوم $day من $total';
  }

  @override
  String get checkin_badge_earned => 'تهانينا! حصلت على شارة الطائر المبكر!';

  @override
  String get checkin_already => 'سجّلت حضورك اليوم بالفعل!';

  @override
  String get listing_badge_top_rated => 'الأعلى تقييمًا';

  @override
  String get listing_badge_verified => 'موثّق';

  @override
  String get listing_badge_open_now => 'مفتوح الآن';

  @override
  String get listing_group_setting => 'داخلي / خارجي';

  @override
  String get listing_group_price_hour => 'السعر في الساعة';

  @override
  String get listing_group_rating => 'التقييم';

  @override
  String listing_price_up_to(String amount) {
    return 'حتى $amount د.إ';
  }

  @override
  String get listing_any_price => 'أي سعر';

  @override
  String listing_rating_and_up(String rating) {
    return '$rating فأكثر';
  }

  @override
  String get listing_venue_sort_distance => 'المسافة';

  @override
  String get listing_venue_sort_rating => 'التقييم';

  @override
  String get listing_venue_sort_price => 'الأقل سعرًا';

  @override
  String get listing_expand_search => 'وسّع نطاق البحث';

  @override
  String get listing_venues_none_filters_text =>
      'جرّب تخفيف أحد الفلاتر أو توسيع نطاق البحث.';

  @override
  String listing_reviews_count(String count) {
    return '($count تقييم)';
  }

  @override
  String get listing_this_weekend => 'نهاية هذا الأسبوع';

  @override
  String get listing_sort_popular => 'الأكثر شعبية';

  @override
  String get meetups_favourite => 'أضف إلى المفضلة';

  @override
  String get meetups_unfavourite => 'إزالة من المفضلة';

  @override
  String meetups_empty_text(String activity, String others) {
    return 'لا توجد لقاءات في $activity الآن. توجد جلسات قادمة في $others.';
  }

  @override
  String listing_share_venue_headline(String name) {
    return 'تعرّف على $name في Dabbler!';
  }

  @override
  String get skill_sub_beginner => 'في بداية الطريق';

  @override
  String get skill_sub_intermediate => 'يلعب بانتظام';

  @override
  String get skill_sub_advanced => 'مستوى تنافسي';

  @override
  String get listing_price_ask => 'اسأل';

  @override
  String listing_price_aed(String amount) {
    return '$amount د.إ';
  }

  @override
  String get game_price => 'السعر';

  @override
  String get game_price_hint => 'السعر لكل لاعب بالدرهم';

  @override
  String get game_price_sub => 'أدخل 0 للمباراة المجانية';

  @override
  String get game_price_required => 'أدخل السعر — 0 يعني مجاني';

  @override
  String get game_price_unit => 'د.إ';

  @override
  String get listing_popular => 'رائج';

  @override
  String get meetup_setting => 'المكان';

  @override
  String get meetup_setting_sub => 'داخلي أم خارجي عند عدم وجود ملعب';

  @override
  String get meetup_setting_required => 'اختر داخلي أو خارجي';

  @override
  String get fav_toast_game_added => 'تمت إضافة اللعبة إلى المفضلة';

  @override
  String get fav_toast_game_removed => 'تمت إزالة اللعبة من المفضلة';

  @override
  String get fav_toast_venue_added => 'تمت إضافة المكان إلى المفضلة';

  @override
  String get fav_toast_venue_removed => 'تمت إزالة المكان من المفضلة';

  @override
  String get fav_toast_meetup_added => 'تمت إضافة اللقاء إلى المفضلة';

  @override
  String get fav_toast_meetup_removed => 'تمت إزالة اللقاء من المفضلة';

  @override
  String get fav_toast_error => 'تعذّر تحديث المفضلة. حاول مرة أخرى.';

  @override
  String listing_following_joined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ممّن تتابعهم',
      many: '$count ممّن تتابعهم',
      few: '$count ممّن تتابعهم',
      zero: '$count ممّن تتابعهم',
      two: '2 ممّن تتابعهم',
      one: '1 ممّن تتابعهم',
    );
    return '$_temp0';
  }

  @override
  String listing_note_join(String first, String second) {
    return '$first · $second';
  }
}
