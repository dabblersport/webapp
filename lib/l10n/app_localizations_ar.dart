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
      'كروت الأخبار مش هتبان في لك. تقدر تقراهم كلهم في تبويب الأخبار.';

  @override
  String get news_hide_confirm => 'خبّي الأخبار';

  @override
  String get news_hide_cancel => 'إلغاء';

  @override
  String get news_hidden_snack => 'الأخبار اتخبت من لك';

  @override
  String get news_resubscribed_snack => 'الأخبار هتبان تاني في لك';

  @override
  String get news_resubscribe_banner => 'الأخبار متخبية من لك.';

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
  String get auth_already_have_account => 'عندك حساب بالفعل؟';

  @override
  String get auth_log_in => 'سجّل دخولك';

  @override
  String get auth_new_here => 'جديد هنا؟';

  @override
  String get auth_create_account => 'اعمل حساب';

  @override
  String get auth_sheet_done => 'تمام';

  @override
  String get auth_sheet_got_it => 'تمام';

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
  String get auth_legal_prefix => 'بالمتابعة أنت توافق على ';

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
  String get auth_otp_title => 'تحقق من بريدك';

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
  String get persona_organiser_principle => 'المباريات الجيدة تبدأ بتنظيم جيد.';

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
      'تابع ما تحب، قابل ناسك، وانضم حين يناسبك.';

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
      'كن ودودًا — كل من هنا هو زميل فريق لشخص ما.';

  @override
  String get persona_socialiser_cta => 'ابدأ الاستكشاف';

  @override
  String get auth_or => 'أو';

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
  String get onb_persona_socialiser_hook => 'اعرف ناسك';

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
  String get onb_persona_player_hook => 'انزل الملعب';

  @override
  String get onb_persona_player_body =>
      'انضم للمباريات، ارفع مستواك، والعب أكثر.';

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
      'اعرض مساحاتك، اوصل للاعبين، وأدر الحجوزات.';

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
    return 'تم اختيار $count رياضات';
  }

  @override
  String get onb_primary_more => 'أضف المزيد من الرياضات';

  @override
  String get onb_identity_title => 'بماذا يناديك الناس؟';

  @override
  String get onb_identity_subtitle =>
      'اضبط الاسم والمعرّف الذي سيظهر لك في دابلر.';

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
  String get nav_feeds => 'الرئيسية';

  @override
  String get nav_community => 'المجتمع';

  @override
  String get nav_venues => 'ملاعب';

  @override
  String get nav_games => 'مباريات';

  @override
  String get nav_meetups => 'اللمّات';

  @override
  String get nav_create_post => 'منشور جديد';

  @override
  String get nav_create_game => 'مباراة جديدة';

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
  String get account_delete_dialog_warning =>
      'الخطوة دي مفيش رجوع فيها. بنمسح بياناتك الشخصية وملفك الشخصي. سجلات الدفع والحجز بنحتفظ بيها لأغراض محاسبية، ومدة الاحتفاظ لسه بتتحدد.';

  @override
  String get account_delete_success_snack => 'تم حذف حسابك وبياناتك الشخصية.';

  @override
  String get danger_zone_delete_confirmation_message =>
      'الخطوة دي هتمسح حسابك وبياناتك الشخصية ومفيش رجوع فيها. سجلات الدفع والحجز بنحتفظ بيها لأغراض محاسبية، ومدة الاحتفاظ لسه بتتحدد.';

  @override
  String get settings_version_app_name => 'Dabbler';

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
  String get settings_item_edit_profile_subtitle =>
      'الاسم والصورة والنبذة والرياضات';

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
      few: '$count نتائج',
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
      other: '$count عنصرًا',
      few: '$count عناصر',
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
  String get notif_pref_payments_title => 'المدفوعات والمشاركة';

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
  String get notif_quiet_hours_off => 'مغلق';

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
  String get acct_delete_type_error => 'اكتب \"DELETE\" للتأكيد';

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
  String get priv_count_none => 'الكل مغلق';

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
  String get region_lang_en => 'English · English';

  @override
  String get region_lang_ar => 'Arabic · العربية';

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
  String get listing_filters => 'التصفية';

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
  String get listing_skill_beginner => 'مبتدئ';

  @override
  String get listing_skill_intermediate => 'متوسط';

  @override
  String get listing_skill_advanced => 'متقدم';

  @override
  String get listing_skill_pro => 'محترف';

  @override
  String get listing_load_sports_failed => 'تعذر تحميل الرياضات';

  @override
  String get listing_load_games_failed => 'تعذر تحميل المباريات';

  @override
  String get listing_load_venues_failed => 'تعذر تحميل الملاعب';

  @override
  String get listing_games_filtered_title => 'لا توجد مباريات تطابق التصفية';

  @override
  String get listing_games_filtered_text => 'عدّل التصفية أو امسحها.';

  @override
  String get listing_games_nearby_title => 'لا توجد مباريات قريبة.';

  @override
  String get listing_games_nearby_text => 'جرّب توسيع نطاق البحث في التصفية.';

  @override
  String get listing_games_none_title => 'لا توجد مباريات بعد';

  @override
  String get listing_games_none_text => 'كن أول من ينشئ مباراة في منطقتك!';

  @override
  String get listing_change_filters => 'غيّر التصفية';

  @override
  String get listing_created => 'أنشأتها';

  @override
  String get listing_joined => 'منضم';

  @override
  String get listing_full => 'ممتلئة';

  @override
  String get listing_join_game => 'انضم للمباراة';

  @override
  String get listing_on_waitlist => 'في قائمة الانتظار';

  @override
  String get listing_request_sent => 'تم إرسال الطلب';

  @override
  String listing_spots_left(int count) {
    return 'بقي $count أماكن';
  }

  @override
  String listing_spots_almost_full(int count) {
    return 'بقي $count · شبه ممتلئ';
  }

  @override
  String listing_players_in(int joined, int total) {
    return '$joined من $total لاعبين';
  }

  @override
  String listing_show_games(int count) {
    return 'عرض $count مباراة';
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
  String get location_timeout => 'تعذر تحديد الموقع — حاول مرة أخرى';

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
    return 'عرض كل $count القادمة';
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
  String get notif_settings_group_connections => 'الاتصالات';

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
      'التغييرات وترقيات قائمة الانتظار وانضمام اللاعبين';

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
    return 'حجم الفريق المفضل: $low - $high لاعبًا';
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
  String get composer_none => 'بدون';

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
  String get game_skill_level => 'مستوى المهارة';

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
  String get game_skill_beginner_sub => 'في البداية';

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
  String get post_detail_follow => 'متابعة';

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
  String get post_detail_retry => 'إعادة المحاولة';

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
    return '$count مشاهدة';
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
  String get bug_field_steps => 'خطوات إعادة الحدوث';

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
  String get bug_err_steps_required => 'يرجى ذكر خطوات إعادة حدوث الخطأ';

  @override
  String get bug_submit => 'إرسال بلاغ الخطأ';

  @override
  String get bug_submitted => 'تم إرسال البلاغ. شكرًا لمساعدتك في تحسيننا.';

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
  String get sports_prefs_skill_level => 'مستوى المهارة';

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
  String get sports_pos_center => 'مركز';

  @override
  String get sports_pos_setter => 'ممرر';

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
    return '$count حزمة مفتوحة المصدر';
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
  String get sfx_search_placeholder => 'ابحث عن أشخاص وألعاب ومنشورات…';

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
  String get sfx_popular => 'الأكثر شعبية';

  @override
  String get sfx_free_entry => 'دخول مجاني';

  @override
  String get sfx_people_nearby => 'أشخاص بالقرب منك';

  @override
  String get sfx_people_nearby_sub => 'اعثر على لاعبين قريبين منك';

  @override
  String get sfx_popular_games => 'الألعاب الشائعة';

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
  String get sfx_games => 'الألعاب';

  @override
  String get sfx_venues => 'الملاعب';

  @override
  String get sfx_posts => 'المنشورات';

  @override
  String get sfx_comments => 'التعليقات';

  @override
  String get sfx_meetups => 'اللقاءات';

  @override
  String get sfx_follow => 'متابعة';

  @override
  String get sfx_join => 'انضم';

  @override
  String get sfx_kind_game => 'لعبة';

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
    return '‏$count منشور';
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
  String get sfx_retry => 'إعادة المحاولة';

  @override
  String get sfx_news => 'الأخبار';

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
  String get sfx_events => 'الألعاب واللقاءات';

  @override
  String get composer_place_search => 'Search venues and areas';

  @override
  String get composer_results => 'Results';

  @override
  String get composer_places_none => 'No places match that search';

  @override
  String get composer_pick_date => 'Pick a date';

  @override
  String get composer_pick_time => 'Pick a time';

  @override
  String get composer_step_1 => 'Step 1 of 2';

  @override
  String get composer_step_2 => 'Step 2 of 2';

  @override
  String get composer_kickoff_time => 'Kickoff time';

  @override
  String get composer_continue_time => 'Continue to time';

  @override
  String get composer_done => 'Done';

  @override
  String composer_use_typed(String query) {
    return 'Use “$query”';
  }

  @override
  String composer_format_title(String sport) {
    return '$sport format';
  }

  @override
  String composer_players_count(int count) {
    return '$count players';
  }

  @override
  String sfx_comments_count(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
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
  String get profile_stat_minutes_played => 'Minutes played';

  @override
  String get meetups_tab_all => 'الكل';

  @override
  String get meetups_none_title => 'No meetups available.';

  @override
  String get meetups_explore_another => 'Explore another activity';

  @override
  String get meetups_load_failed => 'Couldn\'t load meetups';

  @override
  String get meetups_join => 'انضم للقاء';

  @override
  String get meetups_request => 'Request to join';

  @override
  String meetups_going_count(int count) {
    return '$count مشاركًا';
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
  String get meetups_cta_going => 'Joining';

  @override
  String get meetups_cta_interested => 'Maybe going';

  @override
  String get meetups_cta_full => 'Full - you\'re interested';

  @override
  String get meetups_cta_closed => 'Registration closed';

  @override
  String get meetups_cta_cancelled => 'Cancelled';

  @override
  String get meetups_cta_started => 'Already started';

  @override
  String get meetups_cta_unavailable => 'Not available';

  @override
  String get meetups_cta_not_allowed => 'Switch profile to join';

  @override
  String get meetups_sheet_title => 'Are you going to this meetup?';

  @override
  String get meetups_sheet_cancel => 'Cancel';

  @override
  String get meetups_sheet_yes => 'Yes, I am going';

  @override
  String get meetups_sheet_maybe => 'Maybe';

  @override
  String get meetups_sheet_no => 'No, not this time';

  @override
  String get meetups_sheet_confirm => 'Confirm';

  @override
  String get meetups_error_generic => 'Something went wrong. Try again.';

  @override
  String get meetups_error_cancelled => 'This meetup was cancelled.';

  @override
  String get meetups_host_caption => 'Community host';

  @override
  String get meetups_tile_meeting_point => 'Meeting point';

  @override
  String get meetups_tile_entry => 'Entry';

  @override
  String get meetups_load_detail_failed => 'Couldn\'t load this meetup';

  @override
  String get meetups_back => 'Back';

  @override
  String meetups_names_and_others(String names, int count) {
    return '$names and $count others';
  }

  @override
  String meetups_show_count(int count) {
    return 'عرض $count لقاءات';
  }

  @override
  String meetups_km_away(String km) {
    return 'على بعد $km كم';
  }

  @override
  String get meetups_create_title => 'Create meet-up';

  @override
  String get meetups_create_title_hint => 'Meet up title';

  @override
  String get meetups_create_note_hint =>
      'Add short description for participations...';

  @override
  String get meetups_create_name_section => 'CHOOSE NAME AND DESCRIPTION';

  @override
  String get meetups_when => 'When';

  @override
  String get meetups_when_sub => 'Date and time';

  @override
  String get meetups_end => 'End';

  @override
  String get meetups_location => 'Location';

  @override
  String get meetups_location_sub => 'Add a location or venue';

  @override
  String get meetups_capacity => 'Capacity';

  @override
  String get meetups_capacity_sub => 'Max participants';

  @override
  String get meetups_advanced => 'Advanced options';

  @override
  String get meetups_policy => 'How people join';

  @override
  String get meetups_policy_sub => 'Join settings';

  @override
  String get meetups_policy_closed => 'Closed';

  @override
  String get meetups_skill => 'Skill range';

  @override
  String get meetups_skill_sub => 'Experience level';

  @override
  String get meetups_skill_any => 'Any';

  @override
  String get meetups_vibe => 'Vibe';

  @override
  String get meetups_vibe_sub => 'Set the mood';

  @override
  String get meetups_vibe_choose => 'Choose';

  @override
  String get meetups_create_failed => 'Failed to create meet-up';

  @override
  String get meetups_err_organiser_required =>
      'Only organisers can create meet-ups.';

  @override
  String get meetups_err_title_invalid =>
      'The title must be 3 to 80 characters.';

  @override
  String get meetups_err_invalid_time_range =>
      'The end time must be after the start time.';

  @override
  String get meetups_err_invalid_capacity => 'The capacity must be at least 1.';

  @override
  String get meetups_err_auth_required => 'Sign in to continue.';

  @override
  String get meetups_err_unsupported => 'This option is not available yet.';

  @override
  String get meetups_manage => 'Manage meetup';

  @override
  String get meetups_manage_title => 'Manage meet-up';

  @override
  String get meetups_section_going => 'Going';

  @override
  String get meetups_section_interested => 'Interested';

  @override
  String get meetups_section_pending => 'Requests';

  @override
  String get meetups_manage_empty => 'Nobody has responded yet.';

  @override
  String get meetups_approve => 'Approve';

  @override
  String get meetups_decline => 'Decline';

  @override
  String get meetups_remove => 'Remove';

  @override
  String meetups_remove_title(String name) {
    return 'Remove $name?';
  }

  @override
  String get meetups_remove_body =>
      'They will lose their spot and be notified.';

  @override
  String get meetups_edit => 'Edit meet-up';

  @override
  String get meetups_save => 'Save changes';

  @override
  String get meetups_cancel_meetup => 'Cancel meetup';

  @override
  String get meetups_cancel_title => 'Cancel this meet-up?';

  @override
  String get meetups_cancel_body =>
      'Everyone who responded will be told. This cannot be undone.';

  @override
  String get meetups_cancel_confirm => 'Cancel meet-up';

  @override
  String get meetups_keep => 'Keep it';

  @override
  String get meetups_err_capacity_below_going =>
      'The capacity is lower than the number already going.';

  @override
  String get meetups_err_not_host => 'Only the host can do this.';

  @override
  String get meetups_err_attendee_not_found =>
      'That person is no longer on this meet-up.';

  @override
  String get meetups_err_no_pending => 'That request is no longer pending.';

  @override
  String get meetups_save_failed => 'Couldn\'t save the changes';

  @override
  String get meetups_action_failed => 'That didn\'t work. Try again.';
}
