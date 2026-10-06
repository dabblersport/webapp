/// Whether the shell's Action Area can present (APP_ARCHITECTURE.md §5).
///
/// Written only by the shell host (commit 2). Until that host exists the
/// surface is always [absent], so every Information/Result is presented as
/// today's standard toast and Processing is not presented at all.
enum ShellSurface {
  /// The shell route is not current (internal route, sheet or dialog on top),
  /// or no host is mounted.
  absent,

  /// The shell route is current and the create menu is closed.
  current,

  /// The shell route is current but the create menu is open: hold.
  blocked,
}
