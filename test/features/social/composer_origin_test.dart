import 'package:dabbler/data/models/social/post_enums.dart';
import 'package:dabbler/features/social/providers/post_composer_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KAN-592: a tagged venue keeps a manual post manual', () {
    final o = resolveComposerOrigin(originType: OriginType.manual);
    expect(o.type, OriginType.manual);
    expect(o.id, isNull);
  });

  test('an origin the composer was given is kept as is', () {
    final o = resolveComposerOrigin(
      originType: OriginType.repost,
      originId: 'post-1',
    );
    expect(o.type, OriginType.repost);
    expect(o.id, 'post-1');
  });
}
