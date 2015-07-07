// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'theme.dart';

class MenuDivider extends Component {
  MenuDivider({ String key }) : super(key: key);

  Color get color {
    switch(Theme.of(this).brightness) {
      case ThemeBrightness.light:
        return const Color.fromARGB(31, 0, 0, 0);
      case ThemeBrightness.dark:
        return const Color.fromARGB(31, 255, 255, 255);
    }
  }

  Widget build() {
    return new Container(
      height: 0.0,
      decoration: new BoxDecoration(
        border: new Border(
          bottom: new BorderSide(
            color: color
          )
        )
      ),
      margin: const EdgeDims.symmetric(vertical: 8.0)
    );
  }
}
