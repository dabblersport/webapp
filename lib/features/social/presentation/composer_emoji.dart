/// Create Post display emoji (KAN-462) — DISPLAY ONLY.
///
/// CEO ruling 2026-10-09 ("I need everything in the home screen as is in the
/// create post") makes Create Post the documented exception to the design
/// system's no-emoji rule. These strings are only ever handed to the DS emoji
/// slots (`DabblerChip.emoji`, `DabblerBadge.emoji`); they are never written to
/// the post payload, a vibe key, a sport key or any model.
///
/// Source: `Dabbler/alpha-plan/design/full/Home Feed.dc.html` (4 Oct import):
/// `VIBES` (:2649-2768), `SPORT_EMOJI` (:2819-2822), `postTags` (:3264-3269).
/// A vibe or sport the design does not list gets no emoji (nothing invented).
library;

/// Vibe key (kebab-case, as `DabblerVibe.key` and the `vibes` table carry it)
/// -> the design's emoji. All 119 design vibes.
const Map<String, String> composerVibeEmojiByKey = <String, String>{
  'supportive': '🤝', // :2650 Supportive
  'caring': '💞', // :2651 Caring
  'loving': '❤️', // :2652 Loving
  'inspired': '✨', // :2653 Inspired
  'proud': '🏅', // :2654 Proud
  'hopeful': '🌅', // :2655 Hopeful
  'nostalgic': '📸', // :2656 Nostalgic
  'positive': '🌈', // :2657 Positive
  'loved': '💗', // :2658 Loved
  'supported': '🫶', // :2659 Supported
  'amazed': '🤩', // :2660 Amazed
  'happy': '😄', // :2661 Happy
  'calm': '🌊', // :2662 Calm
  'relaxed': '😌', // :2663 Relaxed
  'thankful': '🙏', // :2664 Thankful
  'surprised': '😲', // :2665 Surprised
  'energetic': '⚡️', // :2666 Energetic
  'determined': '💪', // :2667 Determined
  'motivated': '🔥', // :2668 Motivated
  'focused': '🎯', // :2669 Focused
  'excited': '🤸‍♂️', // :2670 Excited
  'empowered': '🦁', // :2671 Empowered
  'heroic': '🦸‍♂️', // :2672 Heroic
  'brave': '🛡️', // :2673 Brave
  'recognized': '🏆', // :2674 Recognized
  'kind': '🌸', // :2675 Kind
  'sympathetic': '🤗', // :2676 Sympathetic
  'together': '👥', // :2677 Together
  'free': '🕊️', // :2678 Free
  'reflective': '🌙', // :2679 Reflective
  'grateful': '🌻', // :2680 Grateful
  'longing': '🪶', // :2681 Longing
  'broken': '💔', // :2682 Broken
  'unique': '🦋', // :2683 Unique
  'heard': '👂', // :2684 Heard
  'grounded': '🌱', // :2685 Grounded
  'awake': '☀️', // :2686 Awake
  'jittery': '🏃‍♂️', // :2687 Jittery
  'exploring': '🧭', // :2688 Exploring
  'orbiting': '🪐', // :2689 Orbiting
  'aligned': '🧘‍♂️', // :2690 Aligned
  'stellar': '🌟', // :2691 Stellar
  'celestial': '🌌', // :2692 Celestial
  'solar': '☀️', // :2693 Solar
  'lunar': '🌕', // :2694 Lunar
  'unearthly': '👽', // :2695 Unearthly
  'blessed': '🙌', // :2696 Blessed
  'fortunate': '🍀', // :2697 Fortunate
  'wishing': '🌠', // :2698 Wishing
  'manifesting': '💫', // :2699 Manifesting
  'resplendent': '💎', // :2700 Resplendent
  'misty-eyed': '🥺', // :2701 Misty-eyed
  'still': '🪞', // :2702 Still
  'muted': '🌫️', // :2703 Muted
  'wilting': '🥀', // :2704 Wilting
  'fading': '🌇', // :2705 Fading
  'restless': '🌀', // :2706 Restless
  'regretful': '😔', // :2707 Regretful
  'rusty': '🧤', // :2708 Rusty
  'layered': '🧩', // :2709 Layered
  'creative': '🎨', // :2710 Creative
  'innovative': '🧠', // :2711 Innovative
  'game-on': '🏁', // :2712 Game On
  'last-call': '📣', // :2713 Last Call
  'kickoff-ready': '⚽️', // :2714 Kickoff Ready
  'almost-full': '👥', // :2715 Almost Full
  'join-fast': '🏃‍♂️', // :2716 Join Fast
  'final-whistle': '⏰', // :2717 Final Whistle
  'warming-up': '🔥', // :2718 Warming Up
  'get-moving': '💨', // :2719 Get Moving
  'lets-rally': '🙌', // :2720 Let's Rally
  'squad-assemble': '🧩', // :2721 Squad Assemble
  'game-time': '⏳', // :2722 Game Time
  'open-slot': '🎯', // :2723 Open Slot
  'late-entry': '🚪', // :2724 Late Entry
  'countdown': '⏱️', // :2725 Countdown
  'hustle-up': '💪', // :2726 Hustle Up
  'lets-go': '🚀', // :2727 Let's Go
  'all-in': '🫡', // :2728 All In
  'bring-it-on': '🦾', // :2729 Bring It On
  'underway': '🕐', // :2730 Underway
  'locking-in': '🔒', // :2731 Locking In
  'drained': '😮‍💨', // :2732 Drained
  'heavy': '🪨', // :2733 Heavy
  'off-day': '🌧️', // :2734 Off Day
  'under-pressure': '🎢', // :2735 Under Pressure
  'tense': '😬', // :2736 Tense
  'shaky': '🪜', // :2737 Shaky
  'disconnected': '📵', // :2738 Disconnected
  'left-out': '🚪', // :2739 Left Out
  'lonely': '🌒', // :2740 Lonely
  'disappointed': '🥲', // :2741 Disappointed
  'uncertain': '❔', // :2742 Uncertain
  'sluggish': '🐌', // :2743 Sluggish
  'flat': '🪫', // :2744 Flat
  'numb': '🧊', // :2745 Numb
  'overthinking': '🤯', // :2746 Overthinking
  'benched': '🪑', // :2747 Benched
  'slipping': '🧗‍♂️', // :2748 Slipping
  'burned-out': '🕯️', // :2749 Burned Out
  'frustrated': '😤', // :2750 Frustrated
  'annoyed': '😒', // :2751 Annoyed
  'angry': '😡', // :2752 Angry
  'irritated': '😑', // :2753 Irritated
  'salty': '🧂', // :2754 Salty
  'rattled': '🌪️', // :2755 Rattled
  'on-edge': '⚠️', // :2756 On Edge
  'heated': '🔥', // :2757 Heated
  'clashing': '⚔️', // :2758 Clashing
  'snappy': '🧨', // :2759 Snappy
  'boiling-over': '🌋', // :2760 Boiling Over
  'resentful': '🧱', // :2761 Resentful
  'tilted': '🎰', // :2762 Tilted
  'short-fused': '⚡️', // :2763 Short-Fused
  'fed-up': '📴', // :2764 Fed Up
  'overloaded': '📦', // :2765 Overloaded
  'stressed': '😰', // :2766 Stressed
  'boomerang-thoughts': '🪃', // :2767 Boomerang Thoughts
  'neutral': '🙂', // :2768 Neutral
};

/// Sport (lower-cased design label, which is also the app's `sport_key`) ->
/// the design's emoji, `SPORT_EMOJI` (`Home Feed.dc.html:2819-2822`).
const Map<String, String> composerSportEmojiByKey = <String, String>{
  'football': '⚽️',
  'padel': '🎾',
  'cricket': '🏏',
  'basketball': '🏀',
  'running': '🏃',
  'gym': '🏋️',
  'swimming': '🏊',
  'tennis': '🎾',
  'volleyball': '🏐',
};

/// The place tag's emoji (`postTags`, `Home Feed.dc.html:3267`).
const String composerPlaceTagEmoji = '📍';

/// The game tag's emoji (`postTags`, `Home Feed.dc.html:3268`).
const String composerGameTagEmoji = '🗓️';

String _normalise(String raw) => raw
    .trim()
    .toLowerCase()
    .replaceAll("'", '')
    .replaceAll(RegExp(r'\s+'), '-');

/// The design emoji for a vibe [keyOrLabel] (a key, or its English label);
/// null when the design lists no such vibe.
String? composerVibeEmoji(String? keyOrLabel) =>
    keyOrLabel == null ? null : composerVibeEmojiByKey[_normalise(keyOrLabel)];

/// The design emoji for a sport [keyOrName] (`sport_key`, or English name);
/// null when the design lists no such sport.
String? composerSportEmoji(String? keyOrName) =>
    keyOrName == null ? null : composerSportEmojiByKey[_normalise(keyOrName)];
