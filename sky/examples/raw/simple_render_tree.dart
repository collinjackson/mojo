// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:sky';
import 'package:sky/framework/layout2.dart';

class RenderSolidColor extends RenderDecoratedBox {
  final int backgroundColor;

  RenderSolidColor(int backgroundColor)
      : super(new BoxDecoration(backgroundColor: backgroundColor)),
        backgroundColor = backgroundColor;

  bool handlePointer(PointerEvent event, { double x: 0.0, double y: 0.0 }) {
    if (event.type == 'pointerdown') {
      setBoxDecoration(new BoxDecoration(backgroundColor: 0xFFFF0000));
      return true;
    }

    if (event.type == 'pointerup') {
      setBoxDecoration(new BoxDecoration(backgroundColor: backgroundColor));
      return true;
    }

    return false;
  }
}

class RenderSolidColorBlock extends RenderSolidColor {
  final double desiredHeight;

  RenderSolidColorBlock(int backgroundColor, { double desiredHeight : 100.0 })
      : super(backgroundColor), desiredHeight = desiredHeight;

  BoxDimensions getIntrinsicDimensions(BoxConstraints constraints) {
    return new BoxDimensions.withConstraints(constraints, height: requestedHeight);
  }

  void layout(BoxConstraints constraints, { RenderNode relayoutSubtreeRoot }) {
    width = constraints.constrainWidth(constraints.maxWidth);
    height = constraints.constrainHeight(desiredHeight);
    layoutDone();
  }
}

class RenderSolidColorFlex extends RenderSolidColor {
  RenderSolidColorFlex(int backgroundColor, flex)
      : super(backgroundColor) {
    parentData = new FlexBoxParentData();
    parentData.flex = flex;
  }

  void layout(BoxConstraints constraints, { RenderNode relayoutSubtreeRoot }) {
    width = constraints.constrainWidth(constraints.maxWidth);
    height = constraints.constrainHeight(constraints.maxHeight);
    layoutDone();
  }
}

RenderView renderView;

void beginFrame(double timeStamp) {
  RenderNode.flushLayout();

  renderView.paintFrame();
}

bool handleEvent(Event event) {
  if (event is! PointerEvent)
    return false;
  return renderView.handlePointer(event, x: event.x, y: event.y);
}

void main() {
  view.setEventCallback(handleEvent);
  view.setBeginFrameCallback(beginFrame);

  var root = new RenderFlex(
      direction: FlexDirection.Column,
      decoration: new BoxDecoration(backgroundColor: 0xFFFFFFFF));

  var block = new RenderBlock(
      decoration: new BoxDecoration(backgroundColor: 0x77000000),
      padding: const EdgeDims(10.0, 10.0, 10.0, 10.0));
  block.add(new RenderSolidColorBlock(0xFF00FF00));
  block.add(new RenderSolidColorBlock(0x3300FFFF));

  root.add(new RenderSolidColorFlex(0xFFFFFF00, 1));
  root.add(block);
  root.add(new RenderSolidColorFlex(0xFF0000FF, 1));
  root.add(new RenderSolidColorFlex(0x77FF00FF, 2));

  renderView = new RenderView(root: root);
  renderView.layout(newWidth: view.width, newHeight: view.height);

  view.scheduleFrame();
}
