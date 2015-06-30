// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../animation/animated_value.dart';
import '../painting/box_painter.dart';
import '../theme/shadows.dart';
import 'animated_component.dart';
import 'basic.dart';
import 'default_text_style.dart';
import 'theme.dart';

enum MaterialType { canvas, card, circle }

const Map<MaterialType, double> edges = const {
  MaterialType.canvas: null,
  MaterialType.card: 2.0,
  MaterialType.circle: null,
};

const double _kAnimateShadowDurationMS = 100.0;

List<BoxShadow> _computeShadow(double level) {
  if (level < 1.0)  // shadows[1] is the first shadow
    return null;

  int level1 = level.floor();
  int level2 = level.ceil();
  double t = level - level1.toDouble();

  List<BoxShadow> shadow = new List<BoxShadow>();
  for (int i = 0; i < shadows[level1].length; ++i)
    shadow.add(lerpBoxShadow(shadows[level1][i], shadows[level2][i], t));
  return shadow;
}

class Material extends AnimatedComponent {

  Material({
    String key,
    this.child,
    this.type: MaterialType.card,
    this.level: 0,
    this.color
  }) : super(key: key) {
    this.level = new AnimatedValue(level == null ? 0.0 : level.toDouble());
    watch(this.level);
  }

  final Widget child;
  final MaterialType type;
  AnimatedValue level;
  final Color color;

  void syncFields(Material source) {
    child = source.child;
    edge = source.edge;
    // TODO(mpcomplete): duration is wrong, because the current level may be
    // anything. We really want |rate|.
    if (level.value != source.level.value)
      level.animateTo(source.level.value.toDouble(), _kAnimateShadowDurationMS);
    color = source.color;
    super.syncFields(source);
  }

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

  // TODO(mpcomplete): make this animate color changes.

  Widget build() {
    return new Container(
      decoration: new BoxDecoration(
        boxShadow: _computeShadow(level.value),
        borderRadius: edges[type],
        backgroundColor: backgroundColor,
        shape: type == MaterialType.circle ? Shape.circle : Shape.rectangle
      ),
      child: new DefaultTextStyle(style: Theme.of(this).text.body1, child: child)
    );
  }

}
