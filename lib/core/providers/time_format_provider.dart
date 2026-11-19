// CEO 2026-11-19: the user picks how clock times read app-wide — the device's
// setting (default), 12-hour or 24-hour. Stored on the device like the
// language (SharedPreferences), and applied in MaterialApp's builder by
// overriding MediaQuery.alwaysUse24HourFormat, so every clock that reads
// MediaQuery.alwaysUse24HourFormatOf follows it.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HourFormat { system, h12, h24 }

const _kHourFormatKey = 'hour_format';

class HourFormatNotifier extends StateNotifier<HourFormat> {
  HourFormatNotifier() : super(HourFormat.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kHourFormatKey);
      final match = HourFormat.values.where((f) => f.name == saved);
      if (match.isNotEmpty && mounted) state = match.first;
    } catch (_) {
      // Stays on the device setting.
    }
  }

  Future<void> set(HourFormat format) async {
    if (state == format) return;
    state = format;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kHourFormatKey, format.name);
    } catch (_) {
      // Best-effort — applied on the device already.
    }
  }
}

final hourFormatProvider =
    StateNotifierProvider<HourFormatNotifier, HourFormat>(
      (ref) => HourFormatNotifier(),
    );

/// [data] with alwaysUse24HourFormat set by [format]; unchanged for system.
MediaQueryData applyHourFormat(MediaQueryData data, HourFormat format) =>
    switch (format) {
      HourFormat.system => data,
      HourFormat.h12 => data.copyWith(alwaysUse24HourFormat: false),
      HourFormat.h24 => data.copyWith(alwaysUse24HourFormat: true),
    };
