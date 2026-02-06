#!/usr/bin/env python3
"""Generate missing design token JSON files from Dart token sources.

Why:
- Flutter web `rootBundle.loadString()` fetches assets over HTTP.
- `DynamicColorSchemeLoader` expects `lib/design_system/tokens/*-light-theme.json`.
- The repo currently contains only the generated Dart tokens (`*_light.dart`, `*_dark.dart`).

This script converts `Color(0xFFRRGGBB)` entries into `#RRGGBB` JSON strings.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

TOKENS_DIR = Path(__file__).resolve().parents[1] / "lib" / "design_system" / "tokens"

FILES: list[tuple[str, str]] = [
    ("main", "light"),
    ("main", "dark"),
    ("social", "light"),
    ("social", "dark"),
    ("sports", "light"),
    ("sports", "dark"),
    ("activity", "light"),
    ("activity", "dark"),
    ("profile", "light"),
    ("profile", "dark"),
]

PAIR_RE = re.compile(
    r"^\s*(?P<key>[A-Za-z0-9_]+):\s*Color\(0xFF(?P<hex>[0-9A-Fa-f]{6})\),\s*$"
)


def main() -> int:
    if not TOKENS_DIR.exists():
        raise SystemExit(f"Tokens dir not found: {TOKENS_DIR}")

    for context, mode in FILES:
        dart_path = TOKENS_DIR / f"{context}_{mode}.dart"
        if not dart_path.exists():
            raise SystemExit(f"Missing token Dart file: {dart_path}")

        mapping: dict[str, str] = {}
        for line in dart_path.read_text(encoding="utf-8").splitlines():
            m = PAIR_RE.match(line)
            if not m:
                continue
            key = m.group("key")
            hexv = m.group("hex").upper()
            mapping[key] = f"#{hexv}"

        if not mapping:
            raise SystemExit(f"No tokens parsed from: {dart_path}")

        root_key = f"{context}{mode.title()}"
        out = {root_key: mapping}

        json_path = TOKENS_DIR / f"{context}-{mode}-theme.json"
        json_path.write_text(
            json.dumps(out, indent=2, sort_keys=False) + "\n", encoding="utf-8"
        )
        print(f"Wrote {json_path.relative_to(TOKENS_DIR.parent.parent.parent)} ({len(mapping)} tokens)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
