// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../painting/box_painter.dart';
import '../theme/shadows.dart';
import 'basic.dart';
import 'default_text_style.dart';
import 'theme.dart';

enum MaterialType { canvas, card, circle }

const Map<MaterialType, double> edges = const {
  MaterialType.canvas: null,
  MaterialType.card: 2.0,
  MaterialType.circle: null,
};

class Material extends Component {

  Material({
    String key,
    this.child,
    this.type: MaterialType.card,
    this.level: 0,
    this.color
  }) : super(key: key);

  final Widget child;
  final int level;
  final MaterialType type;
  final Color color;

  Color get backgroundColor {
    if (color != null)
      return color;
    switch(type) {
      case MaterialType.canvas:
        return Theme.of(this).canvasColor;
      case MaterialType.card:
        return Theme.of(this).cardColor;
      case MaterialType.circle:
        return Theme.of(this).cardColor;
    }
  }

  // TODO(ianh): we should make this animate level changes and color changes

  Widget build() {
    return new Container(
      decoration: new BoxDecoration(
        boxShadow: shadows[level],
        borderRadius: edges[type],
        backgroundColor: backgroundColor,
        shape: type == MaterialType.circle ? Shape.circle : Shape.rectangle
      ),
      child: new DefaultTextStyle(style: Theme.of(this).text.body1, child: child)
    );
  }

}
