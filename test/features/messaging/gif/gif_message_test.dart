import 'package:dabbler/features/messaging/domain/gif_message.dart';
import 'package:flutter_test/flutter_test.dart';

/// KAN-582: which message bodies are GIFs. Anything else must stay text.
void main() {
  const good =
      'https://media2.giphy.com/media/v1.Y2lkPTc5/abc123/giphy.gif?cid=1&ep=v1_gifs_trending&rid=giphy.gif&ct=g';

  group('a GIPHY media URL is a GIF', () {
    test('the url the picker returns', () => expect(gifUrlOfBody(good), good));

    test('surrounding whitespace is ignored, the url is returned trimmed', () {
      expect(gifUrlOfBody('  $good\n'), good);
    });

    test('giphy.com itself, a webp, an upper-case host', () {
      expect(gifUrlOfBody('https://giphy.com/media/x/giphy.gif'), isNotNull);
      expect(gifUrlOfBody('https://i.giphy.com/x/giphy.webp'), isNotNull);
      expect(
        gifUrlOfBody('https://MEDIA.GIPHY.COM/media/x/giphy.GIF'),
        isNotNull,
      );
    });
  });

  group('everything else stays text', () {
    for (final entry in <String, String>{
      'empty': '',
      'plain text': 'look at this',
      'text around the url': 'look $good',
      'two urls': '$good $good',
      'http not https': 'http://media.giphy.com/media/x/giphy.gif',
      'another host': 'https://example.com/media/x/giphy.gif',
      'a look-alike host': 'https://media.giphy.com.evil.example/x/giphy.gif',
      'a host that only ends the same': 'https://notgiphy.com/x/giphy.gif',
      'credentials in the url': 'https://u:p@media.giphy.com/x/giphy.gif',
      'a odd port': 'https://media.giphy.com:8443/x/giphy.gif',
      'a page, not media': 'https://giphy.com/gifs/funny-cats-abc123',
      'a script scheme': 'javascript:alert(1)//media.giphy.com/x.gif',
      'a data uri': 'data:image/gif;base64,R0lGODlhAQABAAAAACw=',
      'too long': 'https://media.giphy.com/${'a' * 700}/giphy.gif',
    }.entries) {
      test(entry.key, () => expect(gifUrlOfBody(entry.value), isNull));
    }
  });
}
