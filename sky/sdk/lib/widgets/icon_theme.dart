// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'widget.dart';

enum IconThemeColor { white, black }

class IconThemeData {
  const IconThemeData({ this.color });
  final IconThemeColor color;
}

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
    return result == null ? null : result.data;
  }

  bool syncShouldNotify(IconTheme old) => data != old.data;

}
