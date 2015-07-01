// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:sky' as sky;

import '../painting/text_style.dart';
import '../theme/typography.dart' as typography;
import 'flat_button.dart';
import 'basic.dart';
import 'default_text_style.dart';
import 'material.dart';
import 'theme.dart';

class SnackBar extends Component {

  SnackBar({
    String key,
    this.content,
    this.actions
  }) : super(key: key) {
    assert(content != null);
  }

  Widget content;
  List<Widget> actions;
  Color actionsColor;

  void syncFields(SnackBar source) {
    content = source.children;
    actions = source.actions;
    actionsColor = source.actionsColor;
    super.syncFields(source);
  }

  Widget build() {
    List<Widget> children = [
      new Flexible(
        child: new Container(
          child: new DefaultTextStyle(
            style: typography.white.subhead,
            child: content
          )
        )
      )
    ]..addAll(actions);
    return new Material(
      level: 2,
      color: const Color(0xFF323232),
      type: MaterialType.canvas,
      child: new Container(
        margin: const EdgeDims.symmetric(horizontal: 24.0, vertical: 14.0),
        child: new DefaultTextStyle(
          style: new TextStyle(color: Theme.of(this).accentColor),
          child: new Flex(children)
        )
      )
    );
  }
}
