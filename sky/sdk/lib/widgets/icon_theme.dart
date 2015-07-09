// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'widget.dart';
import '../theme/icon_theme_data.dart';

export '../theme/icon_theme_data.dart' show IconThemeData, IconThemeColor;

class IconTheme extends Inherited {

  IconTheme({
    String key,
    this.data,
    Widget child
  }) : super(key: key, child: child) {
    assert(data != null);
    assert(child != null);
  }

  final IconThemeData data;

  static IconThemeData of(Component component) {
    IconTheme result = component.inheritedOfType(IconTheme);
    return result == null ? const IconThemeData.fallback() : result.data;
  }

  bool syncShouldNotify(IconTheme old) => data != old.data;

}
