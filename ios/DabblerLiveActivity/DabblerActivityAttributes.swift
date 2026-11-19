// KAN-1006: the Live Activity attributes and content-state. Compiled into both
// the Runner (which starts, updates and ends activities) and the
// DabblerLiveActivity extension (which draws them).
//
// The keys are exactly the payload contract in
// lib/services/live_activity/CHANNEL_CONTRACT.md and the header of
// supabase/migrations/20261118140810_kan1004b_live_activity_fixes.sql.
// Dates are Unix seconds held as Int, never `Date`: ActivityKit's default
// `Date` decoding counts from 2001, the server sends seconds since 1970.

import ActivityKit
import Foundation

struct DabblerActivityAttributes: ActivityAttributes {
  /// The APNs `attributes-type` is the type's name: "DabblerActivityAttributes".
  typealias ContentState = State

  var eventId: String
  var eventType: String
  var title: String?
  /// "en" | "ar" when known (CHANNEL_CONTRACT.md `lang`); the content-state's wins.
  var lang: String? = nil

  enum CodingKeys: String, CodingKey {
    case eventId = "event_id"
    case eventType = "event_type"
    case title
    case lang
  }

  struct State: Codable, Hashable {
    var state: String
    var stateVersion: Int
    var eventId: String
    var eventType: String
    var title: String?
    var startAt: Int
    var endAt: Int?
    var scheduledEndAt: Int?
    var actualStartedAt: Int?
    var checkedIn: Bool
    var role: String
    var organiserAction: String?
    var change: String?
    var endReason: String?
    /// "en" | "ar": the app's chosen language. Absent: the device language.
    var lang: String?
    /// KAN-1024: the server's check-in window flag; nil on an older payload.
    var checkinOpen: Bool?
    /// KAN-1024: Unix seconds the check-in window closes, when known.
    var checkinClosesAt: Int?

    enum CodingKeys: String, CodingKey {
      case state
      case stateVersion = "state_version"
      case eventId = "event_id"
      case eventType = "event_type"
      case title
      case startAt = "start_at"
      case endAt = "end_at"
      case scheduledEndAt = "scheduled_end_at"
      case actualStartedAt = "actual_started_at"
      case checkedIn = "checked_in"
      case role
      case organiserAction = "organiser_action"
      case change
      case endReason = "end_reason"
      case lang
      case checkinOpen = "checkin_open"
      case checkinClosesAt = "checkin_closes_at"
    }

    /// state, state_version, event_id and start_at are required; the rest
    /// default the same way the Android half does. Null keys are omitted.
    init(from decoder: Decoder) throws {
      let c = try decoder.container(keyedBy: CodingKeys.self)
      state = try c.decode(String.self, forKey: .state)
      guard let version = try State.int(c, .stateVersion) else {
        throw DecodingError.keyNotFound(
          CodingKeys.stateVersion, .init(codingPath: c.codingPath, debugDescription: "state_version"))
      }
      stateVersion = version
      eventId = try c.decode(String.self, forKey: .eventId)
      eventType = try c.decodeIfPresent(String.self, forKey: .eventType) ?? "game"
      title = try c.decodeIfPresent(String.self, forKey: .title)
      guard let start = try State.int(c, .startAt) else {
        throw DecodingError.keyNotFound(
          CodingKeys.startAt, .init(codingPath: c.codingPath, debugDescription: "start_at"))
      }
      startAt = start
      endAt = try State.int(c, .endAt)
      scheduledEndAt = try State.int(c, .scheduledEndAt)
      actualStartedAt = try State.int(c, .actualStartedAt)
      checkedIn = (try? c.decodeIfPresent(Bool.self, forKey: .checkedIn)) ?? false
      role = try c.decodeIfPresent(String.self, forKey: .role) ?? "participant"
      organiserAction = try c.decodeIfPresent(String.self, forKey: .organiserAction)
      change = try c.decodeIfPresent(String.self, forKey: .change)
      endReason = try c.decodeIfPresent(String.self, forKey: .endReason)
      let l = try? c.decodeIfPresent(String.self, forKey: .lang)
      lang = (l == "en" || l == "ar") ? l : nil
      checkinOpen = try? c.decodeIfPresent(Bool.self, forKey: .checkinOpen)
      checkinClosesAt = try State.int(c, .checkinClosesAt)
    }

    /// Unix seconds sent as an integer (or, defensively, a whole double).
    private static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) throws -> Int? {
      if let i = try? c.decodeIfPresent(Int.self, forKey: k) { return i }
      if let d = try? c.decodeIfPresent(Double.self, forKey: k) { return Int(d) }
      return nil
    }

    static func date(_ unix: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(unix)) }
    var startDate: Date { State.date(startAt) }
    /// The end of the scheduled window, when known.
    var scheduledEndDate: Date? { (scheduledEndAt ?? endAt).map(State.date) }
    var actualStartedDate: Date? { actualStartedAt.map(State.date) }
    var isOrganiser: Bool { role == "organiser" }
  }
}

/// What the activity shows, from the state keys (never from server strings).
enum DabblerLaPhase: Equatable {
  case checkInOpen      // participant, not checked in yet
  case checkedIn        // participant, checked in, before the start
  case startingSoon     // organiser, before the start
  case running          // started / scheduled_time_running
  case scheduledEnded   // scheduled_time_ended
  case ended
  case cancelled
  case neutral          // a state this build does not know: Open activity only
}

extension DabblerActivityAttributes.State {
  var phase: DabblerLaPhase {
    if state == "cancelled" || endReason == "cancelled" { return .cancelled }
    if state == "ended" || (endReason != nil && endReason != "scheduled_time_ended") { return .ended }
    if state == "scheduled_time_ended" || endReason == "scheduled_time_ended" { return .scheduledEnded }
    if state == "started" || state == "scheduled_time_running" { return .running }
    // Only the known pre-start states reach check-in; anything else is neutral.
    guard state == "checkin_open" || state == "checked_in" else { return .neutral }
    if isOrganiser { return .startingSoon }
    if checkedIn || state == "checked_in" { return .checkedIn }
    return .checkInOpen
  }

  var isFinal: Bool { [.ended, .cancelled, .scheduledEnded].contains(phase) }

  /// True for Arabic. [fallback] is the attributes' `lang`, then the device.
  func isArabic(fallback: String? = nil) -> Bool {
    if let l = lang ?? fallback { return l == "ar" }
    return Locale.preferredLanguages.first?.hasPrefix("ar") == true
  }

  /// The deep links, the same routes as the Android half (LaRoutes) under
  /// the app's `dabbler://app` scheme. `la_action` marks a Live Activity tap.
  private func link(_ path: String, _ action: String) -> URL {
    var c = URLComponents()
    c.scheme = "dabbler"
    c.host = "app"
    c.path = path
    c.queryItems = [URLQueryItem(name: "la_action", value: action)]
    return c.url ?? URL(string: "dabbler://app")!
  }

  var openURL: URL {
    link(eventType == "meetup" ? "/meetups/\(eventId)" : "/game/\(eventId)", "open")
  }

  var checkInURL: URL { link("/check-in/\(eventId)", "open") }

  var organiserURL: URL? {
    guard isOrganiser, phase != .neutral, let a = organiserAction, a == "start" || a == "confirm_end"
    else { return nil }
    return link("/attendance/\(eventId)", a)
  }

  /// Check in is offered only to a participant who has not checked in.
  var offersCheckIn: Bool { offersCheckIn(at: Date()) }

  /// KAN-1024: with `checkin_open` present the server decides (true while the
  /// game runs too), hidden once `now` reaches `checkin_closes_at`. Absent: the
  /// pre-KAN-1024 rule. The organiser never gets Check in.
  func offersCheckIn(at now: Date) -> Bool {
    if isOrganiser || isFinal || phase == .neutral { return false }
    guard let open = checkinOpen else { return phase == .checkInOpen }
    if !open || checkedIn { return false }
    if let closes = checkinClosesAt, now >= DabblerActivityAttributes.State.date(closes) { return false }
    return true
  }
}
