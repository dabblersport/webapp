import Flutter
import GooglePlacesSwift
import SwiftUI
import UIKit

// KAN-629 experiment. Development builds only: nothing here runs unless the
// Dart side (default-off flag PLACES_UI_KIT_EXPERIMENT) calls `configure`.
// To retire the experiment: delete this file, its three references in
// project.pbxproj, the Swift package reference, and the one registration call
// in AppDelegate.swift.

/// Counters and the persisted daily guard. Google's hard daily quotas for the
/// experiment project are 200 UI Kit queries and 20 Text Search requests; the
/// guard is set below both. The day rolls over at midnight Pacific time, the
/// same boundary Google uses for daily quotas.
final class PlacesExperimentState {
  static let shared = PlacesExperimentState()

  static let dailyLoadCeiling = 150
  static let dailySearchCeiling = 12

  private let defaults = UserDefaults.standard
  private var configured = false

  var creates = 0
  var disposes = 0
  var loadsSucceeded = 0
  var loadsFailed = 0
  var latenciesMs: [Double] = []

  private var dayKey: String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = TimeZone(identifier: "America/Los_Angeles")
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
  }

  private func used(_ name: String) -> Int {
    defaults.integer(forKey: "places_poc.\(name).\(dayKey)")
  }

  private func bump(_ name: String) {
    defaults.set(used(name) + 1, forKey: "places_poc.\(name).\(dayKey)")
  }

  func configure(apiKey: String) {
    guard !configured, !apiKey.isEmpty else { return }
    MainActor.assumeIsolated { PlacesClient.provideAPIKey(apiKey) }
    configured = true
  }

  var isConfigured: Bool { configured }

  /// Reserves one UI Kit load. A native component creation is one billable load.
  func reserveLoad() -> Bool {
    guard configured, used("loads") < PlacesExperimentState.dailyLoadCeiling else { return false }
    bump("loads")
    creates += 1
    return true
  }

  func reserveSearch() -> Bool {
    guard configured, used("searches") < PlacesExperimentState.dailySearchCeiling else { return false }
    bump("searches")
    return true
  }

  func snapshot() -> [String: Any] {
    let sorted = latenciesMs.sorted()
    func pct(_ p: Double) -> Double {
      guard !sorted.isEmpty else { return 0 }
      let i = min(sorted.count - 1, Int((Double(sorted.count) * p).rounded(.up)) - 1)
      return sorted[max(0, i)]
    }
    return [
      "day": dayKey,
      "loadsToday": used("loads"),
      "searchesToday": used("searches"),
      "loadCeiling": PlacesExperimentState.dailyLoadCeiling,
      "searchCeiling": PlacesExperimentState.dailySearchCeiling,
      "creates": creates,
      "disposes": disposes,
      "active": creates - disposes,
      "succeeded": loadsSucceeded,
      "failed": loadsFailed,
      "latencyP50Ms": pct(0.5),
      "latencyP95Ms": pct(0.95),
    ]
  }

  func resetSession() {
    creates = 0
    disposes = 0
    loadsSucceeded = 0
    loadsFailed = 0
    latenciesMs = []
  }
}

/// The SwiftUI side: one official Place Details Compact view for one Place ID.
struct PlacesCompactCover: View {
  let placeId: String
  let horizontal: Bool
  let started: Date

  @State private var query: PlaceDetailsQuery

  init(placeId: String, horizontal: Bool) {
    self.placeId = placeId
    self.horizontal = horizontal
    self.started = Date()
    _query = State(initialValue: PlaceDetailsQuery(identifier: .placeID(placeId)))
  }

  var body: some View {
    PlaceDetailsCompactView(
      orientation: horizontal ? .horizontal : .vertical,
      query: $query,
      configuration: PlaceDetailsCompactConfiguration(
        content: PlaceDetailsCompactView.standardContent,
        theme: PlacesMaterialTheme()),
      placeDetailsCallback: { result in
        let ms = Date().timeIntervalSince(started) * 1000
        let state = PlacesExperimentState.shared
        if result.place != nil {
          state.loadsSucceeded += 1
          state.latenciesMs.append(ms)
        } else {
          state.loadsFailed += 1
        }
      })
  }
}

/// Hosts the SwiftUI view and reports its intrinsic size (the compact view
/// sizes itself; Google publishes no minimum height).
final class PlacesSizingContainer: UIView {
  var hosted: UIView?
  var placeId = ""
  private var lastReported = CGSize.zero

  override func layoutSubviews() {
    super.layoutSubviews()
    guard let hosted = hosted else { return }
    hosted.frame = bounds
    let fit = hosted.sizeThatFits(CGSize(width: bounds.width, height: 10000))
    if abs(fit.height - lastReported.height) > 0.5 || abs(bounds.width - lastReported.width) > 0.5 {
      lastReported = CGSize(width: bounds.width, height: fit.height)
      PlacesExperimentBridge.channel?.invokeMethod(
        "intrinsic",
        arguments: ["placeId": placeId, "width": bounds.width, "height": fit.height,
                    "frameHeight": bounds.height])
    }
  }
}

final class PlacesCoverView: NSObject, FlutterPlatformView {
  private let host: UIHostingController<PlacesCompactCover>
  private let container = PlacesSizingContainer()

  init(frame: CGRect, placeId: String, horizontal: Bool) {
    host = UIHostingController(rootView: PlacesCompactCover(placeId: placeId, horizontal: horizontal))
    host.view.backgroundColor = .clear
    container.frame = frame
    container.placeId = placeId
    container.hosted = host.view
    container.addSubview(host.view)
    super.init()
  }

  func view() -> UIView { container }

  deinit { PlacesExperimentState.shared.disposes += 1 }
}

final class PlacesCoverFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    let p = args as? [String: Any]
    return PlacesCoverView(
      frame: frame,
      placeId: p?["placeId"] as? String ?? "",
      horizontal: p?["horizontal"] as? Bool ?? false)
  }
}

enum PlacesExperimentBridge {
  static var channel: FlutterMethodChannel?
  static func register(with registrar: FlutterPluginRegistrar) {
    registrar.register(PlacesCoverFactory(), withId: "dabbler/places_ui_kit")
    let channel = FlutterMethodChannel(
      name: "dabbler/places_experiment", binaryMessenger: registrar.messenger())
    PlacesExperimentBridge.channel = channel
    channel.setMethodCallHandler { call, result in
      let state = PlacesExperimentState.shared
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "configure":
        state.configure(apiKey: args["apiKey"] as? String ?? "")
        result(state.snapshot().merging(["configured": state.isConfigured]) { a, _ in a })
      case "reserveLoad":
        result(state.reserveLoad())
      case "counters":
        result(state.snapshot())
      case "resetSession":
        state.resetSession()
        result(state.snapshot())
      case "match":
        guard state.reserveSearch() else { result(["error": "search-budget-spent"]); return }
        let query = args["query"] as? String ?? ""
        let lat = args["lat"] as? Double ?? 0
        let lng = args["lng"] as? Double ?? 0
        let radius = args["radius"] as? Double ?? 500
        let max = args["max"] as? Int ?? 1
        Task {
          // ID only: the Text Search Essentials IDs Only SKU.
          let request = SearchByTextRequest(
            textQuery: query,
            placeProperties: [.placeID],
            locationBias: CircularCoordinateRegion(
              center: CLLocationCoordinate2D(latitude: lat, longitude: lng), radius: radius),
            maxResultCount: max,
            isOpenNow: false)
          switch await PlacesClient.shared.searchByText(with: request) {
          case .success(let places):
            result(["ids": places.map { $0.placeID }])
          case .failure(let error):
            result(["error": String(describing: error)])
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
