import 'package:flutter/material.dart';

import 'package:dabbler/data/models/social/post_enums.dart';

class PostThemeConfig {
  const PostThemeConfig({
    this.backgroundColor,
    this.gradient,
    required this.textStyle,
  });

  final Color? backgroundColor;
  final Gradient? gradient;
  final TextStyle textStyle;
}

PostThemeConfig getThemeConfig(PostKind kind) {
  switch (kind) {
    case PostKind.news:
      return const PostThemeConfig(
        gradient: LinearGradient(
          colors: [Color(0xFF2193B0), Color(0xFF6DD5ED)],
        ),
        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      );
    case PostKind.announcement:
      return const PostThemeConfig(
        gradient: LinearGradient(
          colors: [Color(0xFFFF7A18), Color(0xFFFFB347)],
        ),
        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    case PostKind.alert:
      return const PostThemeConfig(
        gradient: LinearGradient(
          colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        ),
        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      );
    case PostKind.highlight:
      return const PostThemeConfig(
        gradient: LinearGradient(
          colors: [Color(0xFF834D9B), Color(0xFFD04ED6)],
        ),
        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      );
    case PostKind.original:
    case PostKind.general:
      return const PostThemeConfig(
        backgroundColor: Color(0xFF1E1E1E),
        textStyle: TextStyle(color: Colors.white),
      );
    case PostKind.feature:
      return const PostThemeConfig(
        gradient: LinearGradient(
          colors: [Color(0xFF00B09B), Color(0xFF96C93D)],
        ),
        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      );
  }
}
