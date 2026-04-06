import 'package:flutter/material.dart';

import 'package:dabbler/core/feed/post_theme_model.dart';
import 'package:dabbler/data/models/social/post.dart';
import 'package:dabbler/data/models/social/post_enums.dart';

PostThemeModel resolvePostTheme(Post post) {
  switch (post.kind) {
    case PostKind.news:
      return PostThemeModel(
        backgroundColor: Colors.blue.shade50,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      );

    case PostKind.announcement:
      return PostThemeModel(
        backgroundColor: Colors.orange.shade50,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      );

    case PostKind.alert:
      return PostThemeModel(
        backgroundColor: Colors.red.shade50,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      );

    case PostKind.highlight:
      return PostThemeModel(
        backgroundColor: Colors.purple.shade50,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      );

    case PostKind.general:
      return PostThemeModel(
        backgroundColor: Colors.grey.shade100,
        textStyle: const TextStyle(),
      );

    case PostKind.feature:
      return PostThemeModel(
        backgroundColor: Colors.teal.shade50,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      );

    case PostKind.original:
      return const PostThemeModel(
        backgroundColor: Colors.white,
        textStyle: TextStyle(),
      );
  }
}
