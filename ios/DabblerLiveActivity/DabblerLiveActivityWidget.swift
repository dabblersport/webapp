// KAN-1006 (W3-N2): the Dynamic Island (compact, minimal, expanded) and the
// Lock Screen card. On an iPhone without an Island the system shows the Lock
// Screen card, and the same card as the banner for an update that carries an
// alert (start, check-in open, change, cancel; never at ended, G-15).
//
// Text comes from Localizable.strings (en, ar) by the state keys, in the
// content-state's `lang` (the app's language) through that .lproj, else the
// device language. The layout direction is set from `lang` too. The title and
// any venue or user name are shown as entered (H.3-e). Times use the device's
// 12/24-hour setting (`Text(_:style: .time)`). No score, ETA or location.

import ActivityKit
import SwiftUI
import WidgetKit

private typealias LaState = DabblerActivityAttributes.State

/// The `ar` / `en` string tables of this extension, loaded once.
private enum LaStrings {
  static let ar = Bundle.main.path(forResource: "ar", ofType: "lproj").flatMap(Bundle.init(path:))
  static let en = Bundle.main.path(forResource: "en", ofType: "lproj").flatMap(Bundle.init(path:))

  static func text(_ key: String, arabic: Bool) -> String {
    let b = (arabic ? ar : en) ?? Bundle.main
    return b.localizedString(forKey: key, value: nil, table: nil)
  }
}

/// The device's own direction. ActivityKit lays the Island regions out in the
/// system's direction (`.leading` is on the right on an Arabic device), so the
/// region slots swap only when the app language and the device disagree.
private var deviceIsRTL: Bool {
  guard let code = Locale.preferredLanguages.first else { return false }
  return Locale.Language(identifier: code).characterDirection == .rightToLeft
}

private func direction(_ arabic: Bool) -> LayoutDirection { arabic ? .rightToLeft : .leftToRight }

private extension LaState {
  var arabic: Bool { isArabic() }
  func L(_ key: String) -> String { LaStrings.text(key, arabic: arabic) }

  var displayTitle: String {
    if let t = title, !t.isEmpty { return t }
    return L(eventType == "meetup" ? "la.title.meetup" : "la.title.game")
  }

  var symbol: String { eventType == "meetup" ? "person.3.fill" : "sportscourt.fill" }

  var tint: Color {
    switch phase {
    case .cancelled: return .red
    case .ended, .scheduledEnded: return .gray
    case .running: return .green
    default: return change != nil ? .orange : .mint
    }
  }

  /// The status line, e.g. "Check-in open · Starts 8:00 PM".
  var statusText: Text {
    let sep = Text(verbatim: " · ")
    let starts = Text(L("la.starts") + " ") + Text(startDate, style: .time)
    switch phase {
    case .checkInOpen: return Text(L("la.status.checkin_open")) + sep + starts
    case .checkedIn: return Text(L("la.status.checked_in")) + sep + starts
    case .startingSoon: return Text(L("la.status.starting_soon")) + sep + starts
    case .running:
      // G.9 LIVE-04: "Started 8:05 PM" once pressed, else "Scheduled until …".
      if let s = actualStartedDate {
        return Text(L("la.status.started") + " ") + Text(s, style: .time)
      }
      if let e = scheduledEndDate {
        return Text(L("la.status.scheduled_until") + " ") + Text(e, style: .time)
      }
      return Text(L("la.status.under_way"))
    case .scheduledEnded: return Text(L("la.status.scheduled_ended"))
    case .ended: return Text(L("la.status.ended"))
    case .cancelled: return Text(L("la.status.cancelled"))
    case .neutral: return starts
    }
  }

  /// "Time changed → 8:30 PM" / "Venue changed" while the event is still ahead.
  var changeText: Text? {
    guard let c = change, !isFinal else { return nil }
    if c == "time" {
      return Text(L("la.change.time") + " → ") + Text(startDate, style: .time)
    }
    return Text(L("la.change.venue"))
  }

  /// The very short chip of the compact Island (G-17 short forms).
  @ViewBuilder func chip(now: Date) -> some View {
    switch phase {
    case .cancelled: Text(L("la.chip.cancelled"))
    case .ended, .scheduledEnded: Text(L("la.chip.ended"))
    case .running: Text(L("la.chip.live"))
    default:
      if change != nil {
        Text(L("la.chip.changed"))
      } else if startDate > now {
        // Relative time, counting down to the start.
        Text(timerInterval: now...startDate, countsDown: true, showsHours: false)
          .monospacedDigit()
      } else if phase == .neutral {
        EmptyView()
      } else if phase == .checkInOpen {
        Text(L("la.chip.check_in"))
      } else {
        Text(L("la.chip.checked_in"))
      }
    }
  }
}

/// Open activity, plus Check in (participant) or the organiser's control.
private struct LaActions: View {
  let state: LaState

  var body: some View {
    HStack(spacing: 8) {
      Link(destination: state.openURL) {
        pill(state.L("la.action.open"), filled: !state.offersCheckIn)
      }
      if state.offersCheckIn {
        Link(destination: state.checkInURL) { pill(state.L("la.action.check_in"), filled: true) }
      } else if let url = state.organiserURL {
        let key = state.organiserAction == "start" ? "la.action.start" : "la.action.confirm_end"
        Link(destination: url) { pill(state.L(key), filled: true) }
      }
    }
  }

  private func pill(_ label: String, filled: Bool) -> some View {
    Text(label)
      .font(.caption.weight(.semibold))
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity)
      .foregroundStyle(filled ? Color.black : Color.white)
      .background(filled ? state.tint : Color.white.opacity(0.18), in: Capsule())
  }
}

/// The Lock Screen card (and the banner on an iPhone without an Island). The
/// Arabic card is this card mirrored by its layout direction (H.1).
struct DabblerLockScreenCard: View {
  let attributes: DabblerActivityAttributes
  let state: DabblerActivityAttributes.State

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: state.symbol).foregroundStyle(state.tint)
        Text(state.displayTitle).font(.headline).lineLimit(1)
        Spacer(minLength: 4)
        state.chip(now: Date()).font(.caption.weight(.semibold)).foregroundStyle(state.tint)
          .lineLimit(1)
      }
      state.statusText.font(.subheadline).lineLimit(1)
      if let c = state.changeText {
        c.font(.caption.weight(.semibold)).foregroundStyle(.orange).lineLimit(1)
      }
      if !state.isFinal || state.organiserURL != nil {
        LaActions(state: state)
      }
    }
    .padding(14)
    .environment(\.layoutDirection, direction(state.arabic))
  }
}

struct DabblerLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: DabblerActivityAttributes.self) { context in
      DabblerLockScreenCard(attributes: context.attributes, state: context.state)
        .activityBackgroundTint(Color.black.opacity(0.75))
        .activitySystemActionForegroundColor(.white)
        .widgetURL(context.state.openURL)
    } dynamicIsland: { context in
      let s = context.state
      let now = Date()
      let rtl = s.arabic
      // The regions are placed in the device's direction; swap them only when
      // the app language runs the other way, so the title sits at the start
      // of the app's reading direction in both device-language cases.
      let swap = rtl != deviceIsRTL
      let dir = direction(rtl)
      return DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Group { if swap { expandedChip(s, now) } else { expandedTitle(s) } }
            .environment(\.layoutDirection, dir)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Group { if swap { expandedTitle(s) } else { expandedChip(s, now) } }
            .environment(\.layoutDirection, dir)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            s.statusText.font(.subheadline).lineLimit(1)
            if let c = s.changeText {
              c.font(.caption.weight(.semibold)).foregroundStyle(.orange).lineLimit(1)
            }
            if !s.isFinal || s.organiserURL != nil { LaActions(state: s) }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .environment(\.layoutDirection, dir)
        }
      } compactLeading: {
        Group { if swap { compactChip(s, now) } else { compactIcon(s) } }
          .environment(\.layoutDirection, dir)
      } compactTrailing: {
        Group { if swap { compactIcon(s) } else { compactChip(s, now) } }
          .environment(\.layoutDirection, dir)
      } minimal: {
        compactIcon(s)
      }
      .widgetURL(s.openURL)
      .keylineTint(s.tint)
    }
  }

  private func expandedTitle(_ s: LaState) -> some View {
    HStack(spacing: 6) {
      Image(systemName: s.symbol).foregroundStyle(s.tint)
      Text(s.displayTitle).font(.headline).lineLimit(1).truncationMode(.tail)
    }
  }

  private func expandedChip(_ s: LaState, _ now: Date) -> some View {
    s.chip(now: now).font(.callout.weight(.semibold)).foregroundStyle(s.tint).lineLimit(1)
  }

  private func compactIcon(_ s: LaState) -> some View {
    Image(systemName: s.symbol).foregroundStyle(s.tint)
  }

  /// Fixed, very short width: one line, truncated, scaled down a little.
  private func compactChip(_ s: LaState, _ now: Date) -> some View {
    s.chip(now: now)
      .font(.caption2.weight(.semibold))
      .foregroundStyle(s.tint)
      .lineLimit(1)
      .truncationMode(.tail)
      .minimumScaleFactor(0.7)
      .frame(maxWidth: 64)
  }
}

@main
struct DabblerLiveActivityBundle: WidgetBundle {
  var body: some Widget { DabblerLiveActivityWidget() }
}
