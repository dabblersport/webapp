// Route-inventory golden test (KAN-121, P0-1).
//
// `lib/app/app_router.dart` is about to be split into several modules. Nothing
// in the suite touches the router today, so a green `flutter test` would prove
// nothing at all about that split. This test freezes the shape of the route
// table — every full path, every route name, every route type, in declaration
// order — into a golden fixture beside it. Any route dropped, renamed, moved
// between parents, or reordered during the split fails here.
//
// The router config is read statically; no widget is ever built, so this does
// not need Supabase, Firebase or a ProviderScope.
//
// To regenerate the fixture after an INTENDED route change:
//
//     UPDATE_ROUTE_GOLDEN=true flutter test test/app/route_inventory_test.dart
//
// Then read the fixture diff before committing it — the diff IS the review.

import 'dart:io';

import 'package:dabbler/app/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Path of the checked-in golden, relative to the package root (which is the
/// working directory `flutter test` runs in).
const _goldenPath = 'test/app/route_inventory.golden.txt';

/// One row of the inventory: a route's full path, its name, and its type.
class _RouteEntry {
  const _RouteEntry(this.fullPath, this.name, this.type);

  final String fullPath;
  final String? name;
  final String type;

  /// Serialised form used in the golden. `-` stands for an unnamed route and
  /// for a route with no path of its own (shells and branches).
  String toLine() => '${fullPath.isEmpty ? '-' : fullPath}\t${name ?? '-'}\t$type';
}

/// Joins a parent full path with a child's (relative or absolute) path.
String _join(String parent, String child) {
  if (child.startsWith('/')) return child;
  if (parent.isEmpty || parent == '/') return '/$child';
  return '$parent/$child';
}

/// Walks the route tree depth-first, in declaration order, flattening it to an
/// ordered list of (fullPath, name, runtimeType).
///
/// `GoRoute` contributes its resolved full path. `StatefulShellRoute`,
/// `StatefulShellBranch` and `ShellRoute` carry no path of their own, so they
/// are recorded with an empty path and pass the parent's path down to their
/// children — that is exactly how go_router resolves them.
List<_RouteEntry> _flatten(List<RouteBase> routes, [String parentPath = '']) {
  final out = <_RouteEntry>[];
  for (final route in routes) {
    if (route is GoRoute) {
      final fullPath = _join(parentPath, route.path);
      out.add(_RouteEntry(fullPath, route.name, route.runtimeType.toString()));
      out.addAll(_flatten(route.routes, fullPath));
    } else if (route is StatefulShellRoute) {
      out.add(_RouteEntry('', null, route.runtimeType.toString()));
      for (final branch in route.branches) {
        out.add(_RouteEntry('', null, branch.runtimeType.toString()));
        out.addAll(_flatten(branch.routes, parentPath));
      }
    } else {
      // ShellRoute and any other RouteBase: no path, children inherit ours.
      out.add(_RouteEntry('', null, route.runtimeType.toString()));
      out.addAll(_flatten(route.routes, parentPath));
    }
  }
  return out;
}

void main() {
  final inventory = _flatten(AppRouter.router.configuration.routes);
  final actual = inventory.map((e) => e.toLine()).toList();

  setUpAll(() {
    if (Platform.environment['UPDATE_ROUTE_GOLDEN'] == 'true') {
      File(_goldenPath).writeAsStringSync('${actual.join('\n')}\n');
      // ignore: avoid_print
      print('Wrote ${actual.length} entries to $_goldenPath');
    }
  });

  group('route inventory', () {
    test('flattened route table matches the golden', () {
      final file = File(_goldenPath);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'Golden fixture missing at $_goldenPath. Regenerate with '
            'UPDATE_ROUTE_GOLDEN=true flutter test test/app/route_inventory_test.dart',
      );

      final expected = file
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .toList();

      expect(
        actual,
        orderedEquals(expected),
        reason: 'The route table changed. If the change is intended, '
            'regenerate the golden and review its diff.',
      );
    });

    test('GoRoute count is 85', () {
      final goRoutes =
          inventory.where((e) => e.type == 'GoRoute').length;
      expect(goRoutes, 85);
    });

    test('exactly one StatefulShellRoute.indexedStack, with 4 branches', () {
      final shells = AppRouter.router.configuration.routes
          .whereType<StatefulShellRoute>()
          .toList();
      expect(shells, hasLength(1),
          reason: 'expected exactly one StatefulShellRoute at the top level');
      expect(shells.single.branches, hasLength(4));

      final branchEntries = inventory
          .where((e) => e.type.contains('StatefulShellBranch'))
          .length;
      expect(branchEntries, 4);
    });
  });
}
