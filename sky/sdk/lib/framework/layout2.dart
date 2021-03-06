library layout;

// This version of layout.dart is an update to the other one, this one using new APIs.
// It will not work in a stock Sky setup currently.

import 'node.dart';

import 'dart:sky' as sky;

// ABSTRACT LAYOUT

class ParentData {
  void detach() {
    detachSiblings();
  }
  void detachSiblings() { } // workaround for lack of inter-class mixins in Dart
  void merge(ParentData other) {
    // override this in subclasses to merge in data from other into this
    assert(other.runtimeType == this.runtimeType);
  }
}

const kLayoutDirections = 4;

double clamp({double min: 0.0, double value: 0.0, double max: double.INFINITY}) {
  assert(min != null);
  assert(value != null);
  assert(max != null);

  if (value > max)
    value = max;
  if (value < min)
    value = min;
  return value;
}

class RenderNodeDisplayList extends sky.PictureRecorder {
  RenderNodeDisplayList(double width, double height) : super(width, height);
  void paintChild(RenderNode child, double x, double y) {
    save();
    translate(x, y);
    child.paint(this);
    restore();
  }
}

abstract class RenderNode extends AbstractNode {

  // LAYOUT

  // parentData is only for use by the RenderNode that actually lays this
  // node out, and any other nodes who happen to know exactly what
  // kind of node that is.
  ParentData parentData;
  void setParentData(RenderNode child) {
    // override this to setup .parentData correctly for your class
    if (child.parentData is! ParentData)
      child.parentData = new ParentData();
  }

  void adoptChild(RenderNode child) { // only for use by subclasses
    // call this whenever you decide a node is a child
    assert(child != null);
    setParentData(child);
    super.adoptChild(child);
  }
  void dropChild(RenderNode child) { // only for use by subclasses
    assert(child != null);
    assert(child.parentData != null);
    child.parentData.detach();
    super.dropChild(child);
  }

  static List<RenderNode> _nodesNeedingLayout = new List<RenderNode>();
  static bool _debugDoingLayout = false;
  bool _needsLayout = true;
  bool get needsLayout => _needsLayout;
  RenderNode _relayoutSubtreeRoot;
  void saveRelayoutSubtreeRoot(RenderNode relayoutSubtreeRoot) {
    _relayoutSubtreeRoot = relayoutSubtreeRoot;
    assert(_relayoutSubtreeRoot == null || _relayoutSubtreeRoot._relayoutSubtreeRoot == null);
    assert(_relayoutSubtreeRoot == null || _relayoutSubtreeRoot == parent || _relayoutSubtreeRoot == parent._relayoutSubtreeRoot);
  }
  bool debugAncestorsAlreadyMarkedNeedsLayout() {
    if (_relayoutSubtreeRoot == null)
      return true;
    RenderNode node = this;
    while (node != _relayoutSubtreeRoot) {
      assert(node._relayoutSubtreeRoot == _relayoutSubtreeRoot);
      assert(node.parent != null);
      node = node.parent as RenderNode;
      if (!node._needsLayout)
        return false;
    }
    assert(node._relayoutSubtreeRoot == null);
    return true;
  }
  void markNeedsLayout() {
    assert(!_debugDoingLayout);
    assert(!_debugDoingPaint);
    if (_needsLayout) {
      assert(debugAncestorsAlreadyMarkedNeedsLayout());
      return;
    }
    _needsLayout = true;
    if (_relayoutSubtreeRoot != null)
      parent.markNeedsLayout();
    else
      _nodesNeedingLayout.add(this);
  }
  static void flushLayout() {
    _debugDoingLayout = true;
    List<RenderNode> dirtyNodes = _nodesNeedingLayout;
    _nodesNeedingLayout = new List<RenderNode>();
    dirtyNodes..sort((a, b) => a.depth - b.depth)..forEach((node) {
      if (node._needsLayout && node.attached)
        node._doLayout();
    });
    _debugDoingLayout = false;
  }
  void _doLayout() {
    try {
      assert(_relayoutSubtreeRoot == null);
      relayout();
    } catch (e, stack) {
      print('Exception raised during layout of ${this}: ${e}');
      print(stack);
      return;
    }
    assert(!_needsLayout); // check that the relayout() method marked us "not dirty"
  }
  /* // this method's signature is subclass-specific, but will exist in
     // some form in all subclasses:
     void layout({arguments..., RenderNode relayoutSubtreeRoot}) {
       bool childArgumentsChanged = ...; // true if arguments we're going to pass to the children are different than last time, false otherwise
       if (this node has an opinion about its size, e.g. because it autosizes based on kids, or has an intrinsic dimension) {
         if (relayoutSubtreeRoot != null) {
           saveRelayoutSubtreeRoot(relayoutSubtreeRoot);
           // for each child, if we are going to size ourselves around them:
           if (child.needsLayout || childArgumentsChanged)
             child.layout(... relayoutSubtreeRoot: relayoutSubtreeRoot);
           width = ...;
           height = ...;
         } else {
           saveRelayoutSubtreeRoot(null); // you can skip this if there's no way you would ever have called saveRelayoutSubtreeRoot() before
           // we're the root of the relayout subtree
           // for each child, if we are going to size ourselves around them:
           if (child.needsLayout || childArgumentsChanged)
             child.layout(... relayoutSubtreeRoot: this);
           width = ...;
           height = ...;
         }
       } else {
         // we're sizing ourselves exclusively on input from the parent (arguments to this function)
         // ignore relayoutSubtreeRoot
         saveRelayoutSubtreeRoot(null); // you can skip this if there's no way you would ever have called saveRelayoutSubtreeRoot() before
         width = ...; // based on input from arguments only
         height = ...; // based on input from arguments only
       }
       // for each child whose size we'll ignore when deciding ours:
       if (child.needsLayout || childArgumentsChanged)
         child.layout(... relayoutSubtreeRoot: null); // or just omit relayoutSubtreeRoot
       layoutDone();
       return;
     }
  */
  void relayout() {
    // Override this to perform relayout without your parent's
    // involvement.
    //
    // This is what is called after the first layout(), if you mark
    // yourself dirty and don't have a _relayoutSubtreeRoot set; in
    // other words, either if your parent doesn't care what size you
    // are (and thus didn't pass a relayoutSubtreeRoot to your
    // layout() method) or if you sized yourself entirely based on
    // what your parents told you, and not based on your children (and
    // thus you never called saveRelayoutSubtreeRoot()).
    //
    // In the former case, you can resize yourself here at will. In
    // the latter case, just leave your dimensions unchanged.
    //
    // If _relayoutSubtreeRoot is set (i.e. you called saveRelayout-
    // SubtreeRoot() in your layout(), with a relayoutSubtreeRoot
    // argument that was non-null), then if you mark yourself as dirty
    // then we'll tell that subtree root instead, and the layout will
    // occur via the layout() tree rather than starting from this
    // relayout() method.
    //
    // when calling children's layout() methods, skip any children
    // that have needsLayout == false unless the arguments you are
    // passing in have changed since the last time
    assert(_relayoutSubtreeRoot == null);
    layoutDone();
  }
  void layoutDone({bool needsPaint: true}) {
    // make sure to call this at the end of your layout() or relayout()
    _needsLayout = false;
    if (needsPaint)
      markNeedsPaint();
  }

  // when the parent has rotated (e.g. when the screen has been turned
  // 90 degrees), immediately prior to layout() being called for the
  // new dimensions, rotate() is called with the old and new angles.
  // The next time paint() is called, the coordinate space will have
  // been rotated N quarter-turns clockwise, where:
  //    N = newAngle-oldAngle
  // ...but the rendering is expected to remain the same, pixel for
  // pixel, on the output device. Then, the layout() method or
  // equivalent will be invoked.

  void rotate({
    int oldAngle, // 0..3
    int newAngle, // 0..3
    Duration time
  }) { }


  // HIT TESTING  

  void handlePointer(sky.PointerEvent event) {
    // override this if you have children, to hand it to the appropriate child
    // override this if you want to do anything with the pointer event
  }


  // PAINTING

  static bool _debugDoingPaint = false;
  void markNeedsPaint() {
    assert(!_debugDoingPaint);
  }
  void paint(RenderNodeDisplayList canvas) { }

}


// GENERIC MIXIN FOR RENDER NODES THAT TAKE A LIST OF CHILDREN

abstract class ContainerParentDataMixin<ChildType extends RenderNode> {
  ChildType previousSibling;
  ChildType nextSibling;
  void detachSiblings() {
    if (previousSibling != null) {
      assert(previousSibling.parentData is ContainerParentDataMixin<ChildType>);
      assert(previousSibling != this);
      assert(previousSibling.parentData.nextSibling == this);
      previousSibling.parentData.nextSibling = nextSibling;
    }
    if (nextSibling != null) {
      assert(nextSibling.parentData is ContainerParentDataMixin<ChildType>);
      assert(nextSibling != this);
      assert(nextSibling.parentData.previousSibling == this);
      nextSibling.parentData.previousSibling = previousSibling;
    }
    previousSibling = null;
    nextSibling = null;
  }
}

abstract class ContainerRenderNodeMixin<ChildType extends RenderNode, ParentDataType extends ContainerParentDataMixin<ChildType>> implements RenderNode {
  // abstract class that has only InlineNode children

  bool _debugUltimatePreviousSiblingOf(ChildType child, { ChildType equals }) {
    assert(child.parentData is ParentDataType);
    while (child.parentData.previousSibling != null) {
      assert(child.parentData.previousSibling != child);
      child = child.parentData.previousSibling;
      assert(child.parentData is ParentDataType);
    }
    return child == equals;
  }
  bool _debugUltimateNextSiblingOf(ChildType child, { ChildType equals }) {
    assert(child.parentData is ParentDataType);
    while (child.parentData.nextSibling != null) {
      assert(child.parentData.nextSibling != child);
      child = child.parentData.nextSibling;
      assert(child.parentData is ParentDataType);
    }
    return child == equals;
  }

  ChildType _firstChild;
  ChildType _lastChild;
  void add(ChildType child, { ChildType before }) {
    assert(child != this);
    assert(before != this);
    assert(child != before);
    assert(child != _firstChild);
    assert(child != _lastChild);
    adoptChild(child);
    assert(child.parentData is ParentDataType);
    assert(child.parentData.nextSibling == null);
    assert(child.parentData.previousSibling == null);
    if (before == null) {
      // append at the end (_lastChild)
      child.parentData.previousSibling = _lastChild;
      if (_lastChild != null) {
        assert(_lastChild.parentData is ParentDataType);
        _lastChild.parentData.nextSibling = child;
      }
      _lastChild = child;
      if (_firstChild == null)
        _firstChild = child;
    } else {
      assert(_firstChild != null);
      assert(_lastChild != null);
      assert(_debugUltimatePreviousSiblingOf(before, equals: _firstChild));
      assert(_debugUltimateNextSiblingOf(before, equals: _lastChild));
      assert(before.parentData is ParentDataType);
      if (before.parentData.previousSibling == null) {
        // insert at the start (_firstChild); we'll end up with two or more children
        assert(before == _firstChild);
        child.parentData.nextSibling = before;
        before.parentData.previousSibling = child;
        _firstChild = child;
      } else {
        // insert in the middle; we'll end up with three or more children
        // set up links from child to siblings
        child.parentData.previousSibling = before.parentData.previousSibling;
        child.parentData.nextSibling = before;
        // set up links from siblings to child
        assert(child.parentData.previousSibling.parentData is ParentDataType);
        assert(child.parentData.nextSibling.parentData is ParentDataType);
        child.parentData.previousSibling.parentData.nextSibling = child;
        child.parentData.nextSibling.parentData.previousSibling = child;
        assert(before.parentData.previousSibling == child);
      }
    }
    markNeedsLayout();
  }
  void remove(ChildType child) {
    assert(child.parentData is ParentDataType);
    assert(_debugUltimatePreviousSiblingOf(child, equals: _firstChild));
    assert(_debugUltimateNextSiblingOf(child, equals: _lastChild));
    if (child.parentData.previousSibling == null) {
      assert(_firstChild == child);
      _firstChild = child.parentData.nextSibling;
    } else {
      assert(child.parentData.previousSibling.parentData is ParentDataType);
      child.parentData.previousSibling.parentData.nextSibling = child.parentData.nextSibling;
    }
    if (child.parentData.nextSibling == null) {
      assert(_lastChild == child);
      _lastChild = child.parentData.previousSibling;
    } else {
      assert(child.parentData.nextSibling.parentData is ParentDataType);
      child.parentData.nextSibling.parentData.previousSibling = child.parentData.previousSibling;
    }
    child.parentData.previousSibling = null;
    child.parentData.nextSibling = null;
    dropChild(child);
    markNeedsLayout();
  }
  void redepthChildren() {
    ChildType child = _firstChild;
    while (child != null) {
      redepthChild(child);
      assert(child.parentData is ParentDataType);
      child = child.parentData.nextSibling;
    }
  }
  void attachChildren() {
    ChildType child = _firstChild;
    while (child != null) {
      child.attach();
      assert(child.parentData is ParentDataType);
      child = child.parentData.nextSibling;
    }
  }
  void detachChildren() {
    ChildType child = _firstChild;
    while (child != null) {
      child.detach();
      assert(child.parentData is ParentDataType);
      child = child.parentData.nextSibling;
    }
  }

  ChildType get firstChild => _firstChild;
  ChildType get lastChild => _lastChild;
  ChildType childAfter(ChildType child) {
    assert(child.parentData is ParentDataType);
    return child.parentData.nextSibling;
  }

}


// GENERIC BOX RENDERING
// Anything that has a concept of x, y, width, height is going to derive from this

class BoxConstraints {
  const BoxConstraints({
    this.minWidth: 0.0,
    this.maxWidth: double.INFINITY,
    this.minHeight: 0.0,
    this.maxHeight: double.INFINITY});

  final double minWidth;
  final double maxWidth;
  final double minHeight;
  final double maxHeight;
}

class BoxDimensions {
  const BoxDimensions({this.width, this.height});

  BoxDimensions.withConstraints(
      BoxConstraints constraints, {double width: 0.0, double height: 0.0}) {
    this.width = clamp(min: minWidth, max: maxWidth, value: width);
    this.height = clamp(min: minHeight, max: maxHeight, value: height);
  }

  final double width;
  final double height;
}

class BoxParentData extends ParentData {
  double x = 0.0;
  double y = 0.0;
}

abstract class RenderBox extends RenderNode {

  void setParentData(RenderNode child) {
    if (child.parentData is! BoxParentData)
      child.parentData = new BoxParentData();
  }

  // override this to report what dimensions you would have if you
  // were laid out with the given constraints this can walk the tree
  // if it must, but it should be as cheap as possible; just get the
  // dimensions and nothing else (e.g. don't calculate hypothetical
  // child positions if they're not needed to determine dimensions)
  BoxDimensions getIntrinsicDimensions(BoxConstraints constraints) {
    return new BoxDimensions.withConstraints(constraints);
  }

  void layout(BoxConstraints constraints, { RenderNode relayoutSubtreeRoot }) {
    setWidth(constraints, 0.0);
    setHeight(constraints, 0.0);
    layoutDone();
  }

  double width;
  double height;

  void setWidth(BoxConstraints constraints, double newWidth) {
    width = clamp(min: constraints.minWidth,
                  max: constraints.maxWidth,
                  value: newWidth);
  }

  void setHeight(BoxConstraints constraints, double newHeight) {
    height = clamp(min: constraints.minHeight,
                   max: constraints.maxHeight,
                   value: newHeight);
  }
}

class BoxDecoration {
  BoxDecoration({
    this.backgroundColor
  });

  final int backgroundColor;
}

class RenderDecoratedBox extends RenderBox {
  BoxDecoration decoration;

  RenderDecoratedBox(this.decoration);

  void paint(RenderNodeDisplayList canvas) {
    assert(width != null);
    assert(height != null);

    if (decoration == null)
      return;

    if (decoration.backgroundColor != null) {
      sky.Paint paint = new sky.Paint()..color = decoration.backgroundColor;
      canvas.drawRect(new sky.Rect()..setLTRB(0.0, 0.0, width, height), paint);
    }
  }
}


// RENDER VIEW LAYOUT MANAGER

class RenderView extends RenderNode {

  RenderView({
    RenderBox root,
    this.timeForRotation: const Duration(microseconds: 83333)
  }) {
    assert(root != null);
    this.root = root;
  }

  double _width;
  double get width => _width;
  double _height;
  double get height => _height;

  int _orientation; // 0..3
  int get orientation => _orientation;
  Duration timeForRotation;

  RenderBox _root;
  RenderBox get root => _root;
  void set root (RenderBox value) {
    assert(value != null);
    _root = value;
    adoptChild(_root);
    markNeedsLayout();
  }

  void layout({
    double newWidth,
    double newHeight,
    int newOrientation
  }) {
    assert(root != null);
    if (newOrientation != orientation) {
      if (orientation != null)
        root.rotate(oldAngle: orientation, newAngle: newOrientation, time: timeForRotation);
      _orientation = newOrientation;
    }
    if ((newWidth != width) || (newHeight != height)) {
      _width = newWidth;
      _height = newHeight;
      relayout();
    }
  }

  void relayout() {
    assert(root != null);
    root.layout(new BoxConstraints(
        minWidth: width, maxWidth: width, minHeight: height, maxHeight: height));
    assert(root.width == width);
    assert(root.height == height);
  }

  void rotate({ int oldAngle, int newAngle, Duration time }) {
    assert(false); // nobody tells the screen to rotate, the whole rotate() dance is started from our layout()
  }

  void paint(RenderNodeDisplayList canvas) {
    canvas.paintChild(root, 0.0, 0.0);
  }

  void paintFrame() {
    RenderNode._debugDoingPaint = true;
    var canvas = new RenderNodeDisplayList(sky.view.width, sky.view.height);
    paint(canvas);
    sky.view.picture = canvas.endRecording();
    sky.view.schedulePaint();
    RenderNode._debugDoingPaint = false;
  }

}


// BLOCK LAYOUT MANAGER

class EdgeDims {
  // used for e.g. padding
  const EdgeDims(this.top, this.right, this.bottom, this.left);
  final double top;
  final double right;
  final double bottom;
  final double left;
  operator ==(EdgeDims other) => (top == other.top) ||
                                 (right == other.right) ||
                                 (bottom == other.bottom) ||
                                 (left == other.left);
}

class BlockParentData extends BoxParentData with ContainerParentDataMixin<RenderBox> { }

class RenderBlock extends RenderDecoratedBox with ContainerRenderNodeMixin<RenderBox, BlockParentData> {
  // lays out RenderBox children in a vertical stack
  // uses the maximum width provided by the parent
  // sizes itself to the height of its child stack

  RenderBlock({
    BoxDecoration decoration,
    EdgeDims padding: const EdgeDims(0.0, 0.0, 0.0, 0.0)
  }) : super(decoration), _padding = padding;

  EdgeDims _padding;
  EdgeDims get padding => _padding;
  void set padding(EdgeDims value) {
    assert(value != null);
    if (_padding != value) {
      _padding = value;
      markNeedsLayout();
    }
  }

  void setParentData(RenderBox child) {
    if (child.parentData is! BlockParentData)
      child.parentData = new BlockParentData();
  }

  // override this to report what dimensions you would have if you
  // were laid out with the given constraints this can walk the tree
  // if it must, but it should be as cheap as possible; just get the
  // dimensions and nothing else (e.g. don't calculate hypothetical
  // child positions if they're not needed to determine dimensions)
  BoxDimensions getIntrinsicDimensions(BoxConstraints constraints) {
    double outerHeight = _padding.top + _padding.bottom;
    // TODO(abarth): Shouldn't this have a value: maxWidth?
    double outerWidth = clamp(min: constraints.minWidth,
                              max: constraints.maxWidth);
    double innerWidth = outerWidth - (_padding.left + _padding.right);
    RenderBox child = _firstChild;
    BoxConstraints constraints = new BoxConstraints(minWidth: innerWidth,
                                                    maxWidth: innerWidth);
    while (child != null) {
      outerHeight += child.getIntrinsicDimensions(constraints).height;
      assert(child.parentData is BlockParentData);
      child = child.parentData.nextSibling;
    }

    return new BoxDimensions(
      width: outerWidth,
      height: clamp(min: constraints.minHeight,
                    max: constraints.maxHeight,
                    value: outerHeight)
    );
  }

  double _minHeight; // value cached from parent for relayout call
  double _maxHeight; // value cached from parent for relayout call
  void layout(BoxConstraints constraints, { RenderNode relayoutSubtreeRoot }) {
    if (relayoutSubtreeRoot != null)
      saveRelayoutSubtreeRoot(relayoutSubtreeRoot);
    relayoutSubtreeRoot = relayoutSubtreeRoot == null ? this : relayoutSubtreeRoot;
    // TODO(abarth): Shouldn't this be setWidth(constaints, constraints.maxWidth)?
    width = clamp(min: constraints.minWidth, max: constraints.maxWidth);
    _minHeight = constraints.minHeight;
    _maxHeight = constraints.maxHeight;
    internalLayout(relayoutSubtreeRoot);
  }

  void relayout() {
    internalLayout(this);
  }

  void internalLayout(RenderNode relayoutSubtreeRoot) {
    assert(_minHeight != null);
    assert(_maxHeight != null);
    double y = _padding.top;
    double innerWidth = width - (_padding.left + _padding.right);
    RenderBox child = _firstChild;
    while (child != null) {
      child.layout(new BoxConstraints(minWidth: innerWidth, maxWidth: innerWidth),
                   relayoutSubtreeRoot: relayoutSubtreeRoot);
      assert(child.parentData is BlockParentData);
      child.parentData.x = 0.0; // TODO(abarth): Shouldn't this be _padding.left?
      child.parentData.y = y;
      y += child.height;
      child = child.parentData.nextSibling;
    }
    height = clamp(min: _minHeight, value: y + _padding.bottom, max: _maxHeight);
    layoutDone();
  }

  void handlePointer(sky.PointerEvent event, { double x: 0.0, double y: 0.0 }) {
    // the x, y parameters have the top left of the node's box as the origin
    RenderBox child = _lastChild;
    while (child != null) {
      assert(child.parentData is BlockParentData);
      if ((x >= child.parentData.x) && (x < child.parentData.x + child.width) &&
          (y >= child.parentData.y) && (y < child.parentData.y + child.height)) {
        child.handlePointer(event, x: x-child.parentData.x, y: y-child.parentData.y);
        break;
      }
      child = child.parentData.previousSibling;
    }
    super.handlePointer(event);
  }

  void paint(RenderNodeDisplayList canvas) {
    super.paint(canvas);
    RenderBox child = _firstChild;
    while (child != null) {
      assert(child.parentData is BlockParentData);
      canvas.paintChild(child, child.parentData.x, child.parentData.y);
      child = child.parentData.nextSibling;
    }
  }

}

class FlexBoxParentData extends BoxParentData {
  int flex;
  void merge(FlexBoxParentData other) {
    if (other.flex != null)
      flex = other.flex;
    super.merge(other);
  }
}

enum FlexDirection { Row, Column }

// TODO(ianh): FlexBox


// SCAFFOLD LAYOUT MANAGER

// a sample special-purpose layout manager

class ScaffoldBox extends RenderBox {

  ScaffoldBox(this.toolbar, this.body, this.statusbar, this.drawer) {
    assert(body != null);
  }

  final RenderBox toolbar;
  final RenderBox body;
  final RenderBox statusbar;
  final RenderBox drawer;

  void layout(BoxConstraints constraints, { RenderNode relayoutSubtreeRoot }) {
    setHeight(constraints, 0.0);
    setWidth(constraints, 0.0);
    relayout();
  }

  static const kToolbarHeight = 100.0;
  static const kStatusbarHeight = 50.0;

  void relayout() {
    double bodyHeight = height;
    if (toolbar != null) {
      toolbar.layout(new BoxConstraints(minWidth: width, maxWidth: width, minHeight: kToolbarHeight, maxHeight: kToolbarHeight));
      assert(toolbar.parentData is BoxParentData);
      toolbar.parentData.x = 0.0;
      toolbar.parentData.y = 0.0;
      bodyHeight -= kToolbarHeight;
    }
    if (statusbar != null) {
      statusbar.layout(new BoxConstraints(minWidth: width, maxWidth: width, minHeight: kStatusbarHeight, maxHeight: kStatusbarHeight));
      assert(statusbar.parentData is BoxParentData);
      statusbar.parentData.x = 0.0;
      statusbar.parentData.y = height - kStatusbarHeight;
      bodyHeight -= kStatusbarHeight;
    }
    body.layout(new BoxConstraints(minWidth: width, maxWidth: width, minHeight: bodyHeight, maxHeight: bodyHeight));
    if (drawer != null)
      drawer.layout(new BoxConstraints(minWidth: 0.0, maxWidth: width, minHeight: height, maxHeight: height));
    layoutDone();
  }

  void handlePointer(sky.PointerEvent event, { double x: 0.0, double y: 0.0 }) {
    if ((drawer != null) && (x < drawer.width)) {
      drawer.handlePointer(event, x: x, y: y);
    } else if ((toolbar != null) && (y < toolbar.height)) {
      toolbar.handlePointer(event, x: x, y: y);
    } else if ((statusbar != null) && (y > (statusbar.parentData as BoxParentData).y)) {
      statusbar.handlePointer(event, x: x, y: y-(statusbar.parentData as BoxParentData).y);
    } else {
      body.handlePointer(event, x: x, y: y-(body.parentData as BoxParentData).y);
    }
    super.handlePointer(event, x: x, y: y);
  }

  void paint(RenderNodeDisplayList canvas) {
    canvas.paintChild(body, (body.parentData as BoxParentData).x, (body.parentData as BoxParentData).y);
    if (statusbar != null)
      canvas.paintChild(statusbar, (statusbar.parentData as BoxParentData).x, (statusbar.parentData as BoxParentData).y);
    if (toolbar != null)
      canvas.paintChild(toolbar, (toolbar.parentData as BoxParentData).x, (toolbar.parentData as BoxParentData).y);
    if (drawer != null)
      canvas.paintChild(drawer, (drawer.parentData as BoxParentData).x, (drawer.parentData as BoxParentData).y);
  }

}
