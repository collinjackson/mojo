// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../mojo/asset_bundle.dart';
import 'basic.dart';
import 'icon_theme.dart';
import 'theme.dart';

AssetBundle _initIconBundle() {
  if (rootBundle != null)
    return rootBundle;
  const String _kAssetBase = '/packages/sky/assets/material-design-icons/';
  return new NetworkAssetBundle(Uri.base.resolve(_kAssetBase));
}

final AssetBundle _iconBundle = _initIconBundle();

class Icon extends Component {
  Icon({ String key, this.size, this.type: '', this.color }) : super(key: key);

  final int size;
  final String type;
  final IconThemeColor color;

  String get colorSuffix {
    IconThemeColor iconThemeColor = color;
    if (iconThemeColor == null) {
      IconThemeData iconThemeData = IconTheme.of(this);
      iconThemeColor = iconThemeData == null ? null : iconThemeData.color;
    }
    if (iconThemeColor == null) {
      ThemeBrightness themeBrightness = Theme.of(this).brightness;
      iconThemeColor = themeBrightness == ThemeBrightness.dark ? IconThemeColor.white : IconThemeColor.black;
    }
    switch(iconThemeColor) {
      case IconThemeColor.white:
        return "white";
      case IconThemeColor.black:
        return "black";
    }
  }

  Widget build() {
    String category = '';
    String subtype = '';
    List<String> parts = type.split('/');
    if (parts.length == 2) {
      category = parts[0];
      subtype = parts[1];
    }
    // TODO(eseidel): This clearly isn't correct.  Not sure what would be.
    // Should we use the ios images on ios?
    String density = 'drawable-xxhdpi';
    return new AssetImage(
      bundle: _iconBundle,
      name: '${category}/${density}/ic_${subtype}_${colorSuffix}_${size}dp.png',
      size: new Size(size.toDouble(), size.toDouble())
    );
  }
}
