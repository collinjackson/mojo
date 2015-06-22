// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky';

import 'typography.dart';
import 'colors.dart';

class ThemeData {

  ThemeData.light({
    this.primary,
    this.accent,
    bool darkToolbar: false })
    : toolbarText = darkToolbar ? white : black,
      text = black,
      backgroundColor = const Color(0xFFFAFAFA),
      dialogColor = const Color(0xFFFFFFFF);

  ThemeData.dark({ this.primary, this.accent })
    : toolbarText = white,
      text = white,
      backgroundColor = const Color(0xFF303030),
      dialogColor = const Color(0xFF424242);

  ThemeData.fallback()
    : primary = Indigo,
      accent = PinkAccent,
      toolbarText = white,
      text = black,
      backgroundColor = const Color(0xFFFAFAFA),
      dialogColor = const Color(0xFFFFFFFF);

  final Map<int, Color> primary;
  final Map<int, Color> accent;
  final TextTheme text;
  final TextTheme toolbarText;
  final Color backgroundColor;
  final Color dialogColor;
}
