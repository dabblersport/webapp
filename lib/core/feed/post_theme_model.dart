import 'package:flutter/material.dart';

class PostThemeModel {
  const PostThemeModel({
    required this.backgroundColor,
    this.gradient,
    required this.textStyle,
  });

  final Color backgroundColor;
  final Gradient? gradient;
  final TextStyle textStyle;
}
