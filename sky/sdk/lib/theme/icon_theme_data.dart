// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum IconThemeColor { white, black }

class IconThemeData {

  const IconThemeData({ this.color });

  const IconThemeData.fallback() : color = IconThemeColor.black;

  final IconThemeColor color;
}
