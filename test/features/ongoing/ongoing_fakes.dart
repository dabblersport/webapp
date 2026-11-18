// KAN-1008 (W3-F1): shared fakes and helpers for the ongoing card tests.

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/features/lifecycle/presentation/lifecycle_controller.dart';
import 'package:dabbler/features/notifications/data/models/notification_model.dart';
import 'package:dabbler/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:dabbler/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:dabbler/features/ongoing/data/ongoing_repository.dart';
import 'package:dabbler/features/ongoing/domain/ongoing_models.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_card.dart';
import 'package:dabbler/features/ongoing/presentation/ongoing_controller.dart';
import 'package:dabbler/l10n/app_localizations.dart';
import 'package:dabbler/themes/dabbler_design_system_theme.dart';
import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

DateTime ocClock = DateTime(2026, 11, 18, 20, 5);
final ocStart = DateTime(2026, 11, 18, 20, 30);
final ocEnd = DateTime(2026, 11, 18, 21, 30);

String ocWire(DateTime t) => t.toUtc().toIso8601String();

Map<String, dynamic> ocRow({
  String id = 'e1',
  String kind = 'game',
  String title = 'Padel Night',
  DateTime? start,
  DateTime? end,
  String state = 'scheduled',
  String checkIn = 'before_window',
  bool organiser = false,
  bool cancelled = false,
  DateTime? startedAt,
  DateTime? previousStart,
  DateTime? previousEnd,
}) => {
  'event_id': id,
  'kind': kind,
  'title': title,
  'start_at': ocWire(start ?? ocStart),
  'scheduled_end_at': ocWire(end ?? ocEnd),
  'actual_started_at': startedAt == null ? null : ocWire(startedAt),
  'auto_close_at': null,
  'state': state,
  'is_cancelled': cancelled,
  'is_organiser': organiser,
  'check_in_state': organiser ? 'not_eligible' : checkIn,
  'schedule_revision': previousStart == null && previousEnd == null ? 0 : 1,
  'previous_start_at': previousStart == null ? null : ocWire(previousStart),
  'previous_end_at': previousEnd == null ? null : ocWire(previousEnd),
};

class OcRepo implements OngoingRepository {
  OcRepo(this.rows);
  List<Map<String, dynamic>> rows;
  int reads = 0;
  bool fail = false;

  @override
  Future<Result<List<OngoingEvent>, Failure>> read() async {
    reads++;
    if (fail) return Err(Failure.from(Exception('offline')));
    return Ok([for (final r in rows) OngoingEvent.tryParse(r)!]);
  }
}

const ocUid = 'u1';

class OcInbox extends StateNotifier<NotificationsState>
    implements NotificationsController {
  OcInbox() : super(const NotificationsState(hasMore: false));
  void add(String id, String kind) => state = NotificationsState(
    hasMore: false,
    notifications: [
      AppNotification(
        id: id,
        toUserId: ocUid,
        kindKey: kind,
        title: id,
        createdAt: DateTime(2026, 11, 18, 20),
      ),
      ...state.notifications,
    ],
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final ocSignal = StateProvider<String?>((_) => null);

Future<(OcRepo, ProviderContainer)> ocPump(
  WidgetTester t,
  List<Map<String, dynamic>> rows, {
  String locale = 'en',
  bool h24 = false,
  bool fail = false,
  StateNotifier<NotificationsState>? inbox,
}) async {
  final repo = OcRepo(rows)..fail = fail;
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          body: SingleChildScrollView(child: OngoingCardSlot()),
        ),
      ),
      for (final p in ['/sports/games/:id', '/meetups/:id', '/check-in/:id'])
        GoRoute(
          path: p,
          builder: (_, s) => Scaffold(
            body: Text('route:${p.split('/')[1]}:${s.pathParameters['id']}'),
          ),
        ),
    ],
  );
  final scope = ProviderScope(
    key: UniqueKey(),
    overrides: [
      ongoingRepositoryProvider.overrideWithValue(repo),
      lifecycleClockProvider.overrideWithValue(() => ocClock),
      if (inbox == null)
        ongoingNoticeSignalProvider.overrideWith((ref) => ref.watch(ocSignal))
      else ...[
        notificationUserIdProvider.overrideWithValue(ocUid),
        notificationsControllerProvider(
          ocUid,
        ).overrideWith((ref) => inbox as NotificationsController),
      ],
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: DabblerDesignSystemTheme.withTokens(ThemeData.light()),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: h24),
        child: child!,
      ),
    ),
  );
  await t.pumpWidget(scope);
  await t.pump();
  await t.pump();
  final container = ProviderScope.containerOf(
    t.element(find.byType(OngoingCardSlot)),
  );
  return (repo, container);
}

String ocNorm(String s) => s.replaceAll(RegExp(r'\s'), ' ');

/// Text whose content (spaces normalised, bidi isolates kept) contains [want].
Finder ocHas(String want) => find.byWidgetPredicate((w) {
  final d = w is Text ? (w.data ?? w.textSpan?.toPlainText()) : null;
  return d != null && ocNorm(d).contains(ocNorm(want));
}, description: 'text containing "$want"');

Finder ocKey(String k) => find.byKey(ValueKey<String>(k));

String ocClk(String lang, DateTime t, {bool h24 = false}) =>
    DabblerType.toWesternDigits(
      (h24 ? DateFormat.Hm(lang) : DateFormat.jm(lang)).format(t),
    );
