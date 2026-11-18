import Flutter
import UIKit
import UserNotifications
import Firebase
import Lottie

/// The native launch animation. The iOS launch storyboard cannot run any code,
/// so this overlay window (a lottie-ios view on the LaunchGround colour) is shown
/// as soon as the scene connects and plays the same `assets/Splash.lottie` the
/// Flutter splash plays, looping its draw-in (frames 0 to 89 of 132). When the
/// Flutter splash has painted its own first frame it calls the `handoff` method
/// on the `dabbler/startup` channel: this replies with the loop phase (0..1) so
/// Flutter continues from it with no restart, and removes the overlay.
final class NativeSplash {
  static let shared = NativeSplash()

  /// The last frame of the looped draw-in (`StartupSplash.stillFrame` = 89/132).
  private static let loopEnd: AnimationFrameTime = 89
  private static let totalFrames: AnimationFrameTime = 132
  /// The composition is 400 x 198; the Flutter splash draws it at up to 400 pt
  /// wide, centred, aspect-fit.
  private static let artWidth: CGFloat = 400
  private static let artHeight: CGFloat = 198
  /// A safety net if Flutter never calls `handoff`.
  private static let failsafeSeconds: TimeInterval = 12

  private var window: UIWindow?
  private var animationView: LottieAnimationView?
  private var dotLottie: DotLottieFile?
  private var observer: NSObjectProtocol?
  private var removed = false

  /// Starts loading the animation and waits for the scene to show it in.
  func install() {
    guard observer == nil else { return }
    let key = FlutterDartProject.lookupKey(forAsset: "assets/Splash.lottie")
    if let path = Bundle.main.path(forResource: key, ofType: nil) {
      DotLottieFile.loadedFrom(filepath: path) { [weak self] result in
        guard let self = self, !self.removed else { return }
        if case .success(let file) = result {
          self.dotLottie = file
          self.animationView?.loadAnimation(from: file)
          self.startPlaying()
        }
      }
    }
    observer = NotificationCenter.default.addObserver(
      forName: UIScene.willConnectNotification, object: nil, queue: .main
    ) { [weak self] note in
      if let scene = note.object as? UIWindowScene { self?.show(in: scene) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + NativeSplash.failsafeSeconds) { [weak self] in
      self?.remove()
    }
  }

  private func show(in scene: UIWindowScene) {
    guard window == nil, !removed else { return }
    let w = UIWindow(windowScene: scene)
    w.windowLevel = UIWindow.Level.alert + 100
    let controller = UIViewController()
    // The same ground as LaunchScreen.storyboard (light #F5F0E6 / dark #141414).
    controller.view.backgroundColor = UIColor(named: "LaunchGround")
    let view = LottieAnimationView()
    view.contentMode = .scaleAspectFit
    view.translatesAutoresizingMaskIntoConstraints = false
    controller.view.addSubview(view)
    let fill = view.widthAnchor.constraint(equalTo: controller.view.widthAnchor)
    fill.priority = .defaultHigh
    NSLayoutConstraint.activate([
      view.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
      view.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
      view.widthAnchor.constraint(lessThanOrEqualToConstant: NativeSplash.artWidth),
      fill,
      view.heightAnchor.constraint(
        equalTo: view.widthAnchor, multiplier: NativeSplash.artHeight / NativeSplash.artWidth),
    ])
    w.rootViewController = controller
    w.isHidden = false
    window = w
    animationView = view
    if let file = dotLottie {
      view.loadAnimation(from: file)
      startPlaying()
    }
  }

  private func startPlaying() {
    guard let view = animationView else { return }
    if UIAccessibility.isReduceMotionEnabled {
      // The mark fully drawn, still (the same still frame as Flutter).
      view.currentProgress = NativeSplash.loopEnd / NativeSplash.totalFrames
    } else {
      view.play(fromFrame: 0, toFrame: NativeSplash.loopEnd, loopMode: .loop)
    }
  }

  /// The loop phase (0..1) of the draw-in right now, or 0.
  func phase() -> Double {
    guard let view = animationView, view.animation != nil else { return 0 }
    return Double(min(max(view.realtimeAnimationFrame / NativeSplash.loopEnd, 0), 1))
  }

  func remove() {
    guard !removed else { return }
    removed = true
    animationView?.stop()
    window?.isHidden = true
    window = nil
    animationView = nil
    if let o = observer { NotificationCenter.default.removeObserver(o) }
    observer = nil
  }
}

/// KAN-992 (W1-F6): the notification categories KAN-979 sends (`aps.category`),
/// their actions, the chat open on screen (no foreground alert for it), the
/// app-icon badge, and the actions handed to Dart on `dabbler/push`.
final class PushBridge {
  static let shared = PushBridge()

  static let message = "DABBLER_MESSAGE"
  static let rsvp = "DABBLER_RSVP"
  static let waitlist = "DABBLER_WAITLIST"
  static let security = "DABBLER_SECURITY"
  static let fallback = "DABBLER_DEFAULT"

  private var channel: FlutterMethodChannel?
  /// Actions tapped before Dart was listening (a cold start from an action).
  private var pending: [[String: Any]] = []
  /// The chat open on screen: conversation_id, game_id, meetup_id.
  private var openChat: [String: String] = [:]
  /// KAN-993: the in-app pop-up presents foreground notifications.
  var bannerShows = false

  /// Registers the categories; [titles] are the action titles in the app's
  /// language (English until Dart sends them).
  func registerCategories(titles: [String: String] = [:]) {
    func t(_ id: String, _ fallback: String) -> String { titles[id] ?? fallback }
    let reply = UNTextInputNotificationAction(
      identifier: "REPLY", title: t("REPLY", "Reply"), options: [],
      textInputButtonTitle: t("REPLY", "Reply"), textInputPlaceholder: "")
    let markRead = UNNotificationAction(
      identifier: "MARK_READ", title: t("MARK_READ", "Mark as read"), options: [])
    let going = UNNotificationAction(
      identifier: "GOING", title: t("GOING", "Going"), options: [])
    let notGoing = UNNotificationAction(
      identifier: "NOT_GOING", title: t("NOT_GOING", "Not going"), options: [.destructive])
    // Giving up a place asks for confirmation in the app (G-14).
    let cancelPlace = UNNotificationAction(
      identifier: "CANCEL_PLACE", title: t("CANCEL_PLACE", "Cancel my place"),
      options: [.foreground, .destructive])
    let categories: Set<UNNotificationCategory> = [
      UNNotificationCategory(
        identifier: PushBridge.message, actions: [reply, markRead], intentIdentifiers: [],
        options: []),
      UNNotificationCategory(
        identifier: PushBridge.rsvp, actions: [going, notGoing], intentIdentifiers: [],
        options: []),
      UNNotificationCategory(
        identifier: PushBridge.waitlist, actions: [cancelPlace], intentIdentifiers: [],
        options: []),
      // G-08: no actions, and the preview stays hidden on the lock screen.
      UNNotificationCategory(
        identifier: PushBridge.security, actions: [], intentIdentifiers: [],
        hiddenPreviewsBodyPlaceholder: "", options: [.hiddenPreviewsShowTitle]),
      UNNotificationCategory(
        identifier: PushBridge.fallback, actions: [markRead], intentIdentifiers: [],
        options: []),
    ]
    UNUserNotificationCenter.current().setNotificationCategories(categories)
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let c = FlutterMethodChannel(name: "dabbler/push", binaryMessenger: messenger)
    c.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "setBadge":
        let n = (call.arguments as? Int) ?? 0
        if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(n) { _ in }
        } else {
          UIApplication.shared.applicationIconBadgeNumber = n
        }
        result(nil)
      case "setOpenChat":
        var chat: [String: String] = [:]
        for (k, v) in (call.arguments as? [String: Any]) ?? [:] {
          if let s = v as? String, !s.isEmpty { chat[k] = s }
        }
        self.openChat = chat
        result(nil)
      case "setBannerShows":
        self.bannerShows = (call.arguments as? Bool) ?? false
        result(nil)
      case "setCategories":
        self.registerCategories(titles: (call.arguments as? [String: String]) ?? [:])
        result(nil)
      case "pendingActions":
        let out = self.pending
        self.pending.removeAll()
        result(out)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    channel = c
  }

  /// Whether a foreground push is a message for the chat open on screen.
  func isForOpenChat(_ userInfo: [AnyHashable: Any]) -> Bool {
    guard (userInfo["category"] as? String) == PushBridge.message
      || ((userInfo["kind_key"] as? String)?.hasPrefix("message.") ?? false)
    else { return false }
    for key in ["conversation_id", "game_id", "meetup_id"] {
      if let mine = openChat[key], let theirs = userInfo[key] as? String, mine == theirs {
        return true
      }
    }
    return false
  }

  /// A tapped action: handed to Dart, or kept until it listens.
  func forward(action: String, userInfo: [AnyHashable: Any], text: String?) {
    var data: [String: Any] = [:]
    for (k, v) in userInfo {
      if let key = k as? String, key != "aps" { data[key] = v }
    }
    var event: [String: Any] = ["action": action, "data": data]
    if let text = text { event["text"] = text }
    if let c = channel {
      c.invokeMethod("action", arguments: event)
    } else {
      pending.append(event)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // KAN-992: no alert for a message of the chat open on screen; every other
  // push keeps the presentation firebase_messaging asks for.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler:
      @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if PushBridge.shared.isForOpenChat(notification.request.content.userInfo) {
      completionHandler([])
      return
    }
    // KAN-993: the in-app pop-up shows it; keep it in the list and the badge,
    // without a second banner or sound.
    if PushBridge.shared.bannerShows {
      completionHandler([.list, .badge])
      return
    }
    super.userNotificationCenter(
      center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  // KAN-992: a notification action (not the plain tap) goes to Dart, which
  // runs it; the plain tap stays firebase_messaging's (onMessageOpenedApp).
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let id = response.actionIdentifier
    if id != UNNotificationDefaultActionIdentifier && id != UNNotificationDismissActionIdentifier {
      let text = (response as? UNTextInputNotificationResponse)?.userText
      PushBridge.shared.forward(
        action: id, userInfo: response.notification.request.content.userInfo, text: text)
      completionHandler()
      return
    }
    super.userNotificationCenter(
      center, didReceive: response, withCompletionHandler: completionHandler)
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // The native launch animation starts before anything else.
    NativeSplash.shared.install()

    // Configure Firebase before anything else
    FirebaseApp.configure()

    // Register for remote notifications (required for APNs token on iOS)
    application.registerForRemoteNotifications()

    // KAN-992: the categories exist before the first push arrives.
    PushBridge.shared.registerCategories()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Forward the APNs device token to Firebase Messaging
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // KAN-629 experiment: registers the platform view and channel only. The
    // Places SDK is not initialised and nothing is requested until Dart calls
    // `configure`, which only the default-off PLACES_UI_KIT_EXPERIMENT does.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlacesExperiment") {
      PlacesExperimentBridge.register(with: registrar)
    }

    // KAN-1006: the Live Activity channel (pro.dabbler/live_activity).
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveActivityPlugin") {
      LiveActivityPlugin.register(with: registrar)
    }

    // KAN-992: the push channel (badge, open chat, action titles, actions).
    PushBridge.shared.attach(messenger: engineBridge.applicationRegistrar.messenger())

    // Flutter's splash calls `handoff` once it has painted its first animation
    // frame: reply with the loop phase, then drop the native overlay.
    let channel = FlutterMethodChannel(
      name: "dabbler/startup",
      binaryMessenger: engineBridge.applicationRegistrar.messenger())
    channel.setMethodCallHandler { call, result in
      if call.method == "handoff" {
        let phase = NativeSplash.shared.phase()
        result(phase)
        DispatchQueue.main.async { NativeSplash.shared.remove() }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
