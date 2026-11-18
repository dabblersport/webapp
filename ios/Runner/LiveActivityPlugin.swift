// KAN-1006: the iOS half of the KAN-1005 channel
// (lib/services/live_activity/CHANNEL_CONTRACT.md).
//
//   MethodChannel pro.dabbler/live_activity: getCapabilities, start, update, end, listActive
//   EventChannel  pro.dabbler/live_activity/events: push_to_start_token, activity_token,
//                 activity_ended, tap (each carries event_id and activity_id where it has them)
//
// The version rule: content whose state_version is not strictly higher than the
// one held for that activity is ignored. The version held, and the session an
// activity belongs to, persist in UserDefaults (the Runner is the only reader;
// no App Group is needed).

import ActivityKit
import Flutter
import UIKit

final class LiveActivityPlugin: NSObject, FlutterPlugin, FlutterStreamHandler,
  FlutterSceneLifeCycleDelegate
{
  typealias Attrs = DabblerActivityAttributes

  private static let storeKey = "pro.dabbler.live_activity.sessions"

  private var sink: FlutterEventSink?
  /// Events sent before Dart listened (a cold start, an early token).
  private var pending: [[String: Any]] = []
  /// Activities whose token and state updates are being observed.
  private var observed: Set<String> = []
  /// Activities this app ended itself (their end is not a dismissal).
  private var endedByApp: Set<String> = []
  /// How each activity ended, once it has (see `endedEvent`).
  private var endOutcome: [String: EndOutcome] = [:]
  private var started = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LiveActivityPlugin()
    let methods = FlutterMethodChannel(
      name: "pro.dabbler/live_activity", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(
      name: "pro.dabbler/live_activity/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
    registrar.addSceneDelegate(instance)
    instance.observeAll()
    #if DEBUG
      // `xcrun simctl launch booted app.dabbler.pro -laDebug "op=start&state=checkin_open&v=1"`
      if let q = UserDefaults.standard.string(forKey: "laDebug"),
        let u = URL(string: "dabbler://debug-live-activity?" + q)
      {
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { instance.debugDrive(u) }
      }
    #endif
  }

  // MARK: - Store (activity_id -> {session_id?, version})

  private func store() -> [String: [String: Any]] {
    (UserDefaults.standard.dictionary(forKey: LiveActivityPlugin.storeKey) as? [String: [String: Any]])
      ?? [:]
  }

  private func save(_ s: [String: [String: Any]]) {
    UserDefaults.standard.set(s, forKey: LiveActivityPlugin.storeKey)
  }

  private func heldVersion(_ activityId: String) -> Int? { store()[activityId]?["version"] as? Int }

  private func sessionId(_ activityId: String) -> String? {
    store()[activityId]?["session_id"] as? String
  }

  private func remember(_ activityId: String, session: String?, version: Int) {
    var s = store()
    var row = s[activityId] ?? [:]
    if let session = session { row["session_id"] = session }
    row["version"] = max(version, (row["version"] as? Int) ?? Int.min)
    s[activityId] = row
    save(s)
  }

  private func forget(_ activityId: String) {
    var s = store()
    s[activityId] = nil
    save(s)
  }

  /// The rule (CHANNEL_CONTRACT.md "Version rule"): apply only a strictly higher version.
  static func shouldApply(held: Int?, incoming: Int) -> Bool { held == nil || incoming > held! }

  // MARK: - activity_ended mapping (pure, unit-tested in RunnerTests)

  enum Lifecycle { case ended, dismissed }
  enum EndOutcome: Equatable { case byApp, external }

  /// The `activity_ended` reason to emit for a lifecycle change, and the end
  /// outcome to remember. [prior] is nil while the activity is still active.
  ///   first .ended:  app ended it -> nothing (remember byApp); else "system".
  ///   .dismissed after an external end -> "expired"; after an app end -> nothing.
  ///   .dismissed while still active -> "user_dismissed" (unless the app is ending it).
  static func endedEvent(_ change: Lifecycle, prior: EndOutcome?, endedByApp: Bool)
    -> (reason: String?, outcome: EndOutcome?)
  {
    switch (change, prior) {
    case (.ended, nil): return endedByApp ? (nil, .byApp) : ("system", .external)
    case (.ended, let p?): return (nil, p)
    case (.dismissed, .external?): return ("expired", .external)
    case (.dismissed, .byApp?): return (nil, .byApp)
    case (.dismissed, nil): return endedByApp ? (nil, .byApp) : ("user_dismissed", .external)
    }
  }

  // MARK: - Methods

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "getCapabilities": result(capabilities())
    case "start": Task { await self.start(args, result) }
    case "update": Task { await self.update(args, result) }
    case "end": Task { await self.end(args, result) }
    case "listActive": result(listActive())
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func capabilities() -> [String: Any] {
    let supported = UIDevice.current.userInterfaceIdiom == .phone
    var pushToStart = false
    if #available(iOS 17.2, *) { pushToStart = supported }
    let permission: String =
      !supported ? "unsupported" : (ActivityAuthorizationInfo().areActivitiesEnabled ? "granted" : "denied")
    return ["supported": supported, "permission": permission, "push_to_start": pushToStart]
  }

  private func fail(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }

  private func decodeContent(_ raw: Any?) -> Attrs.ContentState? {
    guard let map = raw as? [String: Any], JSONSerialization.isValidJSONObject(map),
      let data = try? JSONSerialization.data(withJSONObject: map)
    else { return nil }
    return try? JSONDecoder().decode(Attrs.ContentState.self, from: data)
  }

  private func activity(_ id: String?) -> Activity<Attrs>? {
    guard let id = id else { return nil }
    return Activity<Attrs>.activities.first { $0.id == id }
  }

  /// An alert makes the update a banner on an iPhone without an Island (and
  /// expands the Island): check-in open, change, cancel. Never at ended (G-15).
  private func alert(for s: Attrs.ContentState, previous: Attrs.ContentState?) -> AlertConfiguration? {
    let significant: Bool
    switch s.phase {
    case .cancelled: significant = previous?.phase != .cancelled
    case .checkInOpen: significant = previous != nil && previous?.phase != .checkInOpen
    default: significant = s.change != nil && s.change != previous?.change
    }
    guard significant else { return nil }
    let title = s.title ?? ""
    let key: String
    switch s.phase {
    case .cancelled: key = "la.status.cancelled"
    case .checkInOpen: key = "la.status.checkin_open"
    default: key = s.change == "time" ? "la.change.time" : "la.change.venue"
    }
    return AlertConfiguration(
      title: LocalizedStringResource(stringLiteral: title),
      body: LocalizedStringResource(stringLiteral: LiveActivityPlugin.alertText(key, arabic: s.isArabic())),
      sound: .default)
  }

  /// The Runner carries no Live Activity strings of its own; the alert text
  /// follows the same keys as the extension, in the app's language.
  static func alertText(_ key: String, arabic ar: Bool) -> String {
    let en: [String: String] = [
      "la.status.cancelled": "It was cancelled", "la.status.checkin_open": "Check-in open",
      "la.change.time": "Time changed", "la.change.venue": "Venue changed",
    ]
    let arabic: [String: String] = [
      "la.status.cancelled": "أُلغي", "la.status.checkin_open": "تسجيل الحضور مفتوح",
      "la.change.time": "تغيّر الوقت", "la.change.venue": "تغيّر المكان",
    ]
    return (ar ? arabic : en)[key] ?? ""
  }

  private func start(_ args: [String: Any], _ result: @escaping FlutterResult) async {
    guard UIDevice.current.userInterfaceIdiom == .phone else {
      return reply(result, fail("unsupported", "Live Activities need an iPhone"))
    }
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      return reply(result, fail("permission_denied", "Live Activities are off"))
    }
    guard let session = args["session_id"] as? String,
      let attrs = args["attributes"] as? [String: Any],
      let eventId = attrs["event_id"] as? String,
      let eventType = attrs["event_type"] as? String,
      let content = decodeContent(args["content"])
    else { return reply(result, fail("invalid_payload", "start: a key is missing or of the wrong type")) }

    // Idempotent: the session (or the same event) already shown is returned.
    if let existing = Activity<Attrs>.activities.first(where: {
      sessionId($0.id) == session || $0.attributes.eventId == eventId
    }), existing.activityState == .active || existing.activityState == .stale {
      remember(existing.id, session: session, version: content.stateVersion)
      observe(existing)
      var out: [String: Any] = ["activity_id": existing.id]
      if let t = existing.pushToken { out["push_token"] = LiveActivityPlugin.hex(t) }
      return reply(result, out)
    }

    let attributes = Attrs(eventId: eventId, eventType: eventType, title: attrs["title"] as? String)
    do {
      let initial = ActivityContent(state: content, staleDate: nil)
      var requested: Activity<Attrs>
      do {
        requested = try Activity<Attrs>.request(
          attributes: attributes, content: initial, pushType: .token)
      } catch {
        #if DEBUG
          // An unsigned simulator build has no aps-environment: a local-only
          // activity (no push token) is enough to check the views.
          requested = try Activity<Attrs>.request(
            attributes: attributes, content: initial, pushType: nil)
        #else
          throw error
        #endif
      }
      let a = requested
      remember(a.id, session: session, version: content.stateVersion)
      observe(a)
      var out: [String: Any] = ["activity_id": a.id]
      if let t = a.pushToken { out["push_token"] = LiveActivityPlugin.hex(t) }
      reply(result, out)
    } catch {
      reply(result, mapError(error))
    }
  }

  private func update(_ args: [String: Any], _ result: @escaping FlutterResult) async {
    guard let content = decodeContent(args["content"]) else {
      return reply(result, fail("invalid_payload", "update: content is missing or invalid"))
    }
    guard let a = activity(args["activity_id"] as? String) else {
      return reply(result, fail("not_found", "no activity with that activity_id"))
    }
    let held = max(heldVersion(a.id) ?? Int.min, a.content.state.stateVersion)
    guard LiveActivityPlugin.shouldApply(held: held == Int.min ? nil : held, incoming: content.stateVersion)
    else { return reply(result, nil) }  // older or equal: ignored, not an error
    let previous = a.content.state
    await a.update(
      ActivityContent(state: content, staleDate: nil),
      alertConfiguration: alert(for: content, previous: previous))
    remember(a.id, session: args["session_id"] as? String, version: content.stateVersion)
    reply(result, nil)
  }

  private func end(_ args: [String: Any], _ result: @escaping FlutterResult) async {
    guard let a = activity(args["activity_id"] as? String) else {
      return reply(result, fail("not_found", "no activity with that activity_id"))
    }
    var final: ActivityContent<Attrs.ContentState>? = nil
    if args["content"] != nil {
      guard let c = decodeContent(args["content"]) else {
        return reply(result, fail("invalid_payload", "end: content is invalid"))
      }
      let held = max(heldVersion(a.id) ?? Int.min, a.content.state.stateVersion)
      if LiveActivityPlugin.shouldApply(held: held == Int.min ? nil : held, incoming: c.stateVersion) {
        final = ActivityContent(state: c, staleDate: nil)
      }
    }
    let policy: ActivityUIDismissalPolicy
    if let d = (args["dismissal_date"] as? NSNumber)?.doubleValue {
      policy = .after(Date(timeIntervalSince1970: d))
    } else {
      policy = .immediate
    }
    endedByApp.insert(a.id)
    await a.end(final, dismissalPolicy: policy)
    forget(a.id)
    reply(result, nil)
  }

  private func listActive() -> [[String: Any]] {
    Activity<Attrs>.activities.compactMap { a in
      guard a.activityState == .active || a.activityState == .stale,
        let session = sessionId(a.id)
      else { return nil }
      let version = max(heldVersion(a.id) ?? Int.min, a.content.state.stateVersion)
      return ["session_id": session, "activity_id": a.id, "state_version": version]
    }
  }

  private func mapError(_ error: Error) -> FlutterError {
    if let e = error as? ActivityAuthorizationError {
      switch e {
      case .denied: return fail("permission_denied", "\(e)")
      case .unsupported, .unentitled, .unsupportedTarget: return fail("unsupported", "\(e)")
      case .targetMaximumExceeded, .globalMaximumExceeded: return fail("limit_reached", "\(e)")
      case .attributesTooLarge, .malformedActivityIdentifier:
        return fail("invalid_payload", "\(e)")
      default: return fail("internal", "\(e)")
      }
    }
    return fail("internal", "\(error)")
  }

  private func reply(_ result: @escaping FlutterResult, _ value: Any?) {
    DispatchQueue.main.async { result(value) }
  }

  // MARK: - Observing tokens and state

  private func observeAll() {
    guard !started else { return }
    started = true
    for a in Activity<Attrs>.activities { observe(a) }
    // Activities started by push-to-start appear here.
    Task {
      for await a in Activity<Attrs>.activityUpdates { self.observe(a) }
    }
    if #available(iOS 17.2, *) {
      Task {
        for await data in Activity<Attrs>.pushToStartTokenUpdates {
          self.emit(["type": "push_to_start_token", "token": LiveActivityPlugin.hex(data)])
        }
      }
    }
  }

  private func observe(_ a: Activity<Attrs>) {
    DispatchQueue.main.async {
      guard !self.observed.contains(a.id) else { return }
      self.observed.insert(a.id)
      // Every value and every rotation.
      Task {
        for await data in a.pushTokenUpdates {
          var e: [String: Any] = [
            "type": "activity_token", "event_id": a.attributes.eventId, "activity_id": a.id,
            "token": LiveActivityPlugin.hex(data),
          ]
          if let s = self.sessionId(a.id) { e["session_id"] = s }
          self.emit(e)
        }
      }
      Task {
        for await state in a.activityStateUpdates {
          let change: Lifecycle
          switch state {
          case .ended: change = .ended
          case .dismissed: change = .dismissed
          default: continue
          }
          let (reason, outcome) = LiveActivityPlugin.endedEvent(
            change, prior: self.endOutcome[a.id], endedByApp: self.endedByApp.contains(a.id))
          self.endOutcome[a.id] = outcome
          if let reason = reason {
            var e: [String: Any] = [
              "type": "activity_ended", "event_id": a.attributes.eventId, "activity_id": a.id,
              "reason": reason,
            ]
            if let s = self.sessionId(a.id) { e["session_id"] = s }
            self.emit(e)
          }
          // Stop once nothing more can be reported: dismissed, or ended by the
          // app. After a server or system end, wait for the dismissal (expired).
          if change == .dismissed || outcome == .byApp {
            DispatchQueue.main.async {
              self.forget(a.id)
              self.observed.remove(a.id)
              self.endedByApp.remove(a.id)
              self.endOutcome[a.id] = nil
            }
            break
          }
        }
      }
    }
  }

  private func emit(_ event: [String: Any]) {
    DispatchQueue.main.async {
      if let sink = self.sink { sink(event) } else { self.pending.append(event) }
    }
  }

  static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    let out = pending
    pending.removeAll()
    out.forEach { events($0) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  // MARK: - Taps (deep links from the Live Activity)

  /// A tap opens `dabbler://app/...?la_action=...`. Dart hears `tap`; the link
  /// itself is still routed by Flutter (returning false leaves it to Flutter).
  private func handleTap(_ url: URL) {
    guard url.scheme == "dabbler",
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
      let action = items.first(where: { $0.name == "la_action" })?.value
    else { return }
    let eventId = url.pathComponents.last ?? ""
    guard !eventId.isEmpty else { return }
    var e: [String: Any] = ["type": "tap", "event_id": eventId, "action": action]
    if let a = Activity<Attrs>.activities.first(where: { $0.attributes.eventId == eventId }) {
      e["activity_id"] = a.id
      if let s = sessionId(a.id) { e["session_id"] = s }
    }
    emit(e)
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    connectionOptions?.urlContexts.forEach { handleTap($0.url) }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    #if DEBUG
      if let u = URLContexts.first?.url, u.host == "debug-live-activity" {
        debugDrive(u)
        return true
      }
    #endif
    URLContexts.forEach { handleTap($0.url) }
    return false
  }

  #if DEBUG
    /// Debug-only check path (simulator, Debug builds only):
    /// `xcrun simctl openurl booted "dabbler://debug-live-activity?op=start&state=checkin_open&v=1"`
    /// then `op=update&state=started&v=2` (or `change=time`, `state=cancelled`), then `op=end`.
    /// `lang=en|ar` sets the content-state language.
    /// It runs the same start/update/end as the channel and logs the result.
    private func debugDrive(_ url: URL) {
      var q: [String: String] = [:]
      URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.forEach {
        q[$0.name] = $0.value
      }
      let now = Int(Date().timeIntervalSince1970)
      var content: [String: Any] = [
        "state": q["state"] ?? "checkin_open", "state_version": Int(q["v"] ?? "1") ?? 1,
        "event_id": "00000000-0000-0000-0000-00000000d0b1", "event_type": q["type"] ?? "game",
        "title": q["title"] ?? "خماسي الخميس", "start_at": now + 25 * 60,
        "scheduled_end_at": now + 85 * 60, "checked_in": q["checked_in"] == "1",
        "role": q["role"] ?? "participant",
      ]
      if let c = q["change"] { content["change"] = c }
      if q["state"] == "started" { content["actual_started_at"] = now }
      if let r = q["end_reason"] { content["end_reason"] = r }
      if let l = q["lang"] { content["lang"] = l }
      let log: FlutterResult = { value in
        let text = (value as? FlutterError).map { "error \($0.code): \($0.message ?? "")" }
          ?? String(describing: value)
        NSLog("[LiveActivityDebug] \(q["op"] ?? "?") -> \(text)")
      }
      let current = Activity<Attrs>.activities.first?.id
      Task {
        switch q["op"] {
        case "start":
          await self.start(
            ["session_id": "debug-session", "attributes": [
              "event_id": content["event_id"]!, "event_type": content["event_type"]!,
              "title": content["title"]!,
            ], "content": content], log)
        case "update": await self.update(["activity_id": current as Any, "content": content], log)
        case "end": await self.end(["activity_id": current as Any, "content": content], log)
        case "list": log(self.listActive())
        default: log(self.capabilities())
        }
      }
    }
  #endif
}
