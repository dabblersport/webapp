import Flutter
import UIKit
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

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
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
