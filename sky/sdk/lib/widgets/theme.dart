// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sky/theme/theme_info.dart';
import 'basic.dart';
import 'widget.dart';

class Theme extends Inherited {

  Theme({
    String key,
    this.theme,
    Widget child
  }) : super(key: key, child: child);

  final ThemeInfo theme;

  static ThemeInfo of(Widget widget) {
    Theme theme = widget.inheritedForType(Theme);
    return theme.theme;
  }
}
