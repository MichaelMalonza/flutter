// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'all_elements.dart';
import 'event_simulation.dart';
import 'finders.dart';
import 'test_async_utils.dart';
import 'test_pointer.dart';

/// The default drag touch slop used to break up a large drag into multiple
/// smaller moves.
///
/// This value must be greater than [kTouchSlop].
const double kDragSlopDefault = 20.0;

/// Class that programmatically interacts with widgets.
///
/// For a variant of this class suited specifically for unit tests, see
/// [WidgetTester]. For one suitable for live tests on a device, consider
/// [LiveWidgetController].
///
/// Concrete subclasses must implement the [pump] method.
abstract class WidgetController {
  /// Creates a widget controller that uses the given binding.
  WidgetController(this.binding);

  /// A reference to the current instance of the binding.
  final WidgetsBinding binding;

  // FINDER API

  // TODO(ianh): verify that the return values are of type T and throw
  // a good message otherwise, in all the generic methods below

  /// Checks if `finder` exists in the tree.
  bool any(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().isNotEmpty;
  }

  /// All widgets currently in the widget tree (lazy pre-order traversal).
  ///
  /// Can contain duplicates, since widgets can be used in multiple
  /// places in the widget tree.
  Iterable<Widget> get allWidgets {
    TestAsyncUtils.guardSync();
    return allElements.map<Widget>((Element element) => element.widget);
  }

  /// The matching widget in the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty or matches more than
  /// one widget.
  ///
  /// * Use [firstWidget] if you expect to match several widgets but only want the first.
  /// * Use [widgetList] if you expect to match several widgets and want all of them.
  T widget<T extends Widget>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().single.widget as T;
  }

  /// The first matching widget according to a depth-first pre-order
  /// traversal of the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty.
  ///
  /// * Use [widget] if you only expect to match one widget.
  T firstWidget<T extends Widget>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().first.widget as T;
  }

  /// The matching widgets in the widget tree.
  ///
  /// * Use [widget] if you only expect to match one widget.
  /// * Use [firstWidget] if you expect to match several but only want the first.
  Iterable<T> widgetList<T extends Widget>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().map<T>((Element element) {
      final T result = element.widget as T;
      return result;
    });
  }

  /// All elements currently in the widget tree (lazy pre-order traversal).
  ///
  /// The returned iterable is lazy. It does not walk the entire widget tree
  /// immediately, but rather a chunk at a time as the iteration progresses
  /// using [Iterator.moveNext].
  Iterable<Element> get allElements {
    TestAsyncUtils.guardSync();
    return collectAllElementsFrom(binding.renderViewElement, skipOffstage: false);
  }

  /// The matching element in the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty or matches more than
  /// one element.
  ///
  /// * Use [firstElement] if you expect to match several elements but only want the first.
  /// * Use [elementList] if you expect to match several elements and want all of them.
  T element<T extends Element>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().single as T;
  }

  /// The first matching element according to a depth-first pre-order
  /// traversal of the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty.
  ///
  /// * Use [element] if you only expect to match one element.
  T firstElement<T extends Element>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().first as T;
  }

  /// The matching elements in the widget tree.
  ///
  /// * Use [element] if you only expect to match one element.
  /// * Use [firstElement] if you expect to match several but only want the first.
  Iterable<T> elementList<T extends Element>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().cast<T>();
  }

  /// All states currently in the widget tree (lazy pre-order traversal).
  ///
  /// The returned iterable is lazy. It does not walk the entire widget tree
  /// immediately, but rather a chunk at a time as the iteration progresses
  /// using [Iterator.moveNext].
  Iterable<State> get allStates {
    TestAsyncUtils.guardSync();
    return allElements.whereType<StatefulElement>().map<State>((StatefulElement element) => element.state);
  }

  /// The matching state in the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty, matches more than
  /// one state, or matches a widget that has no state.
  ///
  /// * Use [firstState] if you expect to match several states but only want the first.
  /// * Use [stateList] if you expect to match several states and want all of them.
  T state<T extends State>(Finder finder) {
    TestAsyncUtils.guardSync();
    return _stateOf<T>(finder.evaluate().single, finder);
  }

  /// The first matching state according to a depth-first pre-order
  /// traversal of the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty or if the first
  /// matching widget has no state.
  ///
  /// * Use [state] if you only expect to match one state.
  T firstState<T extends State>(Finder finder) {
    TestAsyncUtils.guardSync();
    return _stateOf<T>(finder.evaluate().first, finder);
  }

  /// The matching states in the widget tree.
  ///
  /// Throws a [StateError] if any of the elements in `finder` match a widget
  /// that has no state.
  ///
  /// * Use [state] if you only expect to match one state.
  /// * Use [firstState] if you expect to match several but only want the first.
  Iterable<T> stateList<T extends State>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().map<T>((Element element) => _stateOf<T>(element, finder));
  }

  T _stateOf<T extends State>(Element element, Finder finder) {
    TestAsyncUtils.guardSync();
    if (element is StatefulElement)
      return element.state as T;
    throw StateError('Widget of type ${element.widget.runtimeType}, with ${finder.description}, is not a StatefulWidget.');
  }

  /// Render objects of all the widgets currently in the widget tree
  /// (lazy pre-order traversal).
  ///
  /// This will almost certainly include many duplicates since the
  /// render object of a [StatelessWidget] or [StatefulWidget] is the
  /// render object of its child; only [RenderObjectWidget]s have
  /// their own render object.
  Iterable<RenderObject> get allRenderObjects {
    TestAsyncUtils.guardSync();
    return allElements.map<RenderObject>((Element element) => element.renderObject);
  }

  /// The render object of the matching widget in the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty or matches more than
  /// one widget (even if they all have the same render object).
  ///
  /// * Use [firstRenderObject] if you expect to match several render objects but only want the first.
  /// * Use [renderObjectList] if you expect to match several render objects and want all of them.
  T renderObject<T extends RenderObject>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().single.renderObject as T;
  }

  /// The render object of the first matching widget according to a
  /// depth-first pre-order traversal of the widget tree.
  ///
  /// Throws a [StateError] if `finder` is empty.
  ///
  /// * Use [renderObject] if you only expect to match one render object.
  T firstRenderObject<T extends RenderObject>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().first.renderObject as T;
  }

  /// The render objects of the matching widgets in the widget tree.
  ///
  /// * Use [renderObject] if you only expect to match one render object.
  /// * Use [firstRenderObject] if you expect to match several but only want the first.
  Iterable<T> renderObjectList<T extends RenderObject>(Finder finder) {
    TestAsyncUtils.guardSync();
    return finder.evaluate().map<T>((Element element) {
      final T result = element.renderObject as T;
      return result;
    });
  }

  /// Returns a list of all the [Layer] objects in the rendering.
  List<Layer> get layers => _walkLayers(binding.renderView.debugLayer).toList();
  Iterable<Layer> _walkLayers(Layer layer) sync* {
    TestAsyncUtils.guardSync();
    yield layer;
    if (layer is ContainerLayer) {
      final ContainerLayer root = layer;
      Layer child = root.firstChild;
      while (child != null) {
        yield* _walkLayers(child);
        child = child.nextSibling;
      }
    }
  }

  // INTERACTION

  /// Dispatch a pointer down / pointer up sequence at the center of
  /// the given widget, assuming it is exposed.
  ///
  /// If the center of the widget is not exposed, this might send events to
  /// another object.
  Future<void> tap(Finder finder, {int pointer, int buttons = kPrimaryButton}) {
    return tapAt(getCenter(finder), pointer: pointer, buttons: buttons);
  }

  /// Dispatch a pointer down / pointer up sequence at the given location.
  Future<void> tapAt(Offset location, {int pointer, int buttons = kPrimaryButton}) {
    return TestAsyncUtils.guard<void>(() async {
      final TestGesture gesture = await startGesture(location, pointer: pointer, buttons: buttons);
      await gesture.up();
    });
  }

  /// Dispatch a pointer down at the center of the given widget, assuming it is
  /// exposed.
  ///
  /// If the center of the widget is not exposed, this might send events to
  /// another object.
  Future<TestGesture> press(Finder finder, {int pointer, int buttons = kPrimaryButton}) {
    return TestAsyncUtils.guard<TestGesture>(() {
      return startGesture(getCenter(finder), pointer: pointer, buttons: buttons);
    });
  }

  /// Dispatch a pointer down / pointer up sequence (with a delay of
  /// [kLongPressTimeout] + [kPressTimeout] between the two events) at the
  /// center of the given widget, assuming it is exposed.
  ///
  /// If the center of the widget is not exposed, this might send events to
  /// another object.
  Future<void> longPress(Finder finder, {int pointer, int buttons = kPrimaryButton}) {
    return longPressAt(getCenter(finder), pointer: pointer, buttons: buttons);
  }

  /// Dispatch a pointer down / pointer up sequence at the given location with
  /// a delay of [kLongPressTimeout] + [kPressTimeout] between the two events.
  Future<void> longPressAt(Offset location, {int pointer, int buttons = kPrimaryButton}) {
    return TestAsyncUtils.guard<void>(() async {
      final TestGesture gesture = await startGesture(location, pointer: pointer, buttons: buttons);
      await pump(kLongPressTimeout + kPressTimeout);
      await gesture.up();
    });
  }

  /// Attempts a fling gesture starting from the center of the given
  /// widget, moving the given distance, reaching the given speed.
  ///
  /// If the middle of the widget is not exposed, this might send
  /// events to another object.
  ///
  /// This can pump frames. See [flingFrom] for a discussion of how the
  /// `offset`, `velocity` and `frameInterval` arguments affect this.
  ///
  /// The `speed` is in pixels per second in the direction given by `offset`.
  ///
  /// A fling is essentially a drag that ends at a particular speed. If you
  /// just want to drag and end without a fling, use [drag].
  ///
  /// The `initialOffset` argument, if non-zero, causes the pointer to first
  /// apply that offset, then pump a delay of `initialOffsetDelay`. This can be
  /// used to simulate a drag followed by a fling, including dragging in the
  /// opposite direction of the fling (e.g. dragging 200 pixels to the right,
  /// then fling to the left over 200 pixels, ending at the exact point that the
  /// drag started).
  Future<void> fling(
    Finder finder,
    Offset offset,
    double speed, {
    int pointer,
    int buttons = kPrimaryButton,
    Duration frameInterval = const Duration(milliseconds: 16),
    Offset initialOffset = Offset.zero,
    Duration initialOffsetDelay = const Duration(seconds: 1),
  }) {
    return flingFrom(
      getCenter(finder),
      offset,
      speed,
      pointer: pointer,
      buttons: buttons,
      frameInterval: frameInterval,
      initialOffset: initialOffset,
      initialOffsetDelay: initialOffsetDelay,
    );
  }

  /// Attempts a fling gesture starting from the given location, moving the
  /// given distance, reaching the given speed.
  ///
  /// Exactly 50 pointer events are synthesized.
  ///
  /// The offset and speed control the interval between each pointer event. For
  /// example, if the offset is 200 pixels down, and the speed is 800 pixels per
  /// second, the pointer events will be sent for each increment of 4 pixels
  /// (200/50), over 250ms (200/800), meaning events will be sent every 1.25ms
  /// (250/200).
  ///
  /// To make tests more realistic, frames may be pumped during this time (using
  /// calls to [pump]). If the total duration is longer than `frameInterval`,
  /// then one frame is pumped each time that amount of time elapses while
  /// sending events, or each time an event is synthesized, whichever is rarer.
  ///
  /// A fling is essentially a drag that ends at a particular speed. If you
  /// just want to drag and end without a fling, use [dragFrom].
  ///
  /// The `initialOffset` argument, if non-zero, causes the pointer to first
  /// apply that offset, then pump a delay of `initialOffsetDelay`. This can be
  /// used to simulate a drag followed by a fling, including dragging in the
  /// opposite direction of the fling (e.g. dragging 200 pixels to the right,
  /// then fling to the left over 200 pixels, ending at the exact point that the
  /// drag started).
  Future<void> flingFrom(
    Offset startLocation,
    Offset offset,
    double speed, {
    int pointer,
    int buttons = kPrimaryButton,
    Duration frameInterval = const Duration(milliseconds: 16),
    Offset initialOffset = Offset.zero,
    Duration initialOffsetDelay = const Duration(seconds: 1),
  }) {
    assert(offset.distance > 0.0);
    assert(speed > 0.0); // speed is pixels/second
    return TestAsyncUtils.guard<void>(() async {
      final TestPointer testPointer = TestPointer(pointer ?? _getNextPointer(), PointerDeviceKind.touch, null, buttons);
      final HitTestResult result = hitTestOnBinding(startLocation);
      const int kMoveCount = 50; // Needs to be >= kHistorySize, see _LeastSquaresVelocityTrackerStrategy
      final double timeStampDelta = 1000.0 * offset.distance / (kMoveCount * speed);
      double timeStamp = 0.0;
      double lastTimeStamp = timeStamp;
      await sendEventToBinding(testPointer.down(startLocation, timeStamp: Duration(milliseconds: timeStamp.round())), result);
      if (initialOffset.distance > 0.0) {
        await sendEventToBinding(testPointer.move(startLocation + initialOffset, timeStamp: Duration(milliseconds: timeStamp.round())), result);
        timeStamp += initialOffsetDelay.inMilliseconds;
        await pump(initialOffsetDelay);
      }
      for (int i = 0; i <= kMoveCount; i += 1) {
        final Offset location = startLocation + initialOffset + Offset.lerp(Offset.zero, offset, i / kMoveCount);
        await sendEventToBinding(testPointer.move(location, timeStamp: Duration(milliseconds: timeStamp.round())), result);
        timeStamp += timeStampDelta;
        if (timeStamp - lastTimeStamp > frameInterval.inMilliseconds) {
          await pump(Duration(milliseconds: (timeStamp - lastTimeStamp).truncate()));
          lastTimeStamp = timeStamp;
        }
      }
      await sendEventToBinding(testPointer.up(timeStamp: Duration(milliseconds: timeStamp.round())), result);
    });
  }

  /// A simulator of how the framework handles a series of [PointerEvent]s
  /// received from the Flutter engine.
  ///
  /// The [PointerEventRecord.timeDelay] is used as the time delay of the events
  /// injection relative to the starting point of the method call.
  ///
  /// Returns a list of the difference between the real delay time when the
  /// [PointerEventRecord.events] are processed and
  /// [PointerEventRecord.timeDelay].
  /// - For [AutomatedTestWidgetsFlutterBinding] where the clock is fake, the
  ///   return value should be exact zeros.
  /// - For [LiveTestWidgetsFlutterBinding], the values are typically small
  /// positives, meaning the event happens a little later than the set time,
  /// but a very small portion may have a tiny negatvie value for about tens of
  /// microseconds. This is due to the nature of [Future.delayed].
  ///
  /// The closer the return values are to zero the more faithful it is to the
  /// `records`.
  ///
  /// See [PointerEventRecord].
  Future<List<Duration>> handlePointerEventRecord(List<PointerEventRecord> records);

  /// Called to indicate that there should be a new frame after an optional
  /// delay.
  ///
  /// The frame is pumped after a delay of [duration] if [duration] is not null,
  /// or immediately otherwise.
  ///
  /// This is invoked by [flingFrom], for instance, so that the sequence of
  /// pointer events occurs over time.
  ///
  /// The [WidgetTester] subclass implements this by deferring to the [binding].
  ///
  /// See also [SchedulerBinding.endOfFrame], which returns a future that could
  /// be appropriate to return in the implementation of this method.
  Future<void> pump([Duration duration]);

  /// Attempts to drag the given widget by the given offset, by
  /// starting a drag in the middle of the widget.
  ///
  /// If the middle of the widget is not exposed, this might send
  /// events to another object.
  ///
  /// If you want the drag to end with a speed so that the gesture recognition
  /// system identifies the gesture as a fling, consider using [fling] instead.
  ///
  /// {@template flutter.flutter_test.drag}
  /// By default, if the x or y component of offset is greater than [kTouchSlop], the
  /// gesture is broken up into two separate moves calls. Changing 'touchSlopX' or
  /// `touchSlopY` will change the minimum amount of movement in the respective axis
  /// before the drag will be broken into multiple calls. To always send the
  /// drag with just a single call to [TestGesture.moveBy], `touchSlopX` and `touchSlopY`
  /// should be set to 0.
  ///
  /// Breaking the drag into multiple moves is necessary for accurate execution
  /// of drag update calls with a [DragStartBehavior] variable set to
  /// [DragStartBehavior.start]. Without such a change, the dragUpdate callback
  /// from a drag recognizer will never be invoked.
  ///
  /// To force this function to a send a single move event, the 'touchSlopX' and
  /// 'touchSlopY' variables should be set to 0. However, generally, these values
  /// should be left to their default values.
  /// {@endtemplate}
  Future<void> drag(
    Finder finder,
    Offset offset, {
    int pointer,
    int buttons = kPrimaryButton,
    double touchSlopX = kDragSlopDefault,
    double touchSlopY = kDragSlopDefault,
  }) {
    assert(kDragSlopDefault > kTouchSlop);
    return dragFrom(
      getCenter(finder),
      offset,
      pointer: pointer,
      buttons: buttons,
      touchSlopX: touchSlopX,
      touchSlopY: touchSlopY,
    );
  }

  /// Attempts a drag gesture consisting of a pointer down, a move by
  /// the given offset, and a pointer up.
  ///
  /// If you want the drag to end with a speed so that the gesture recognition
  /// system identifies the gesture as a fling, consider using [flingFrom]
  /// instead.
  ///
  /// {@macro flutter.flutter_test.drag}
  Future<void> dragFrom(
    Offset startLocation,
    Offset offset, {
    int pointer,
    int buttons = kPrimaryButton,
    double touchSlopX = kDragSlopDefault,
    double touchSlopY = kDragSlopDefault,
  }) {
    assert(kDragSlopDefault > kTouchSlop);
    return TestAsyncUtils.guard<void>(() async {
      final TestGesture gesture = await startGesture(startLocation, pointer: pointer, buttons: buttons);
      assert(gesture != null);

      final double xSign = offset.dx.sign;
      final double ySign = offset.dy.sign;

      final double offsetX = offset.dx;
      final double offsetY = offset.dy;

      final bool separateX = offset.dx.abs() > touchSlopX && touchSlopX > 0;
      final bool separateY = offset.dy.abs() > touchSlopY && touchSlopY > 0;

      if (separateY || separateX) {
        final double offsetSlope = offsetY / offsetX;
        final double inverseOffsetSlope = offsetX / offsetY;
        final double slopSlope = touchSlopY / touchSlopX;
        final double absoluteOffsetSlope = offsetSlope.abs();
        final double signedSlopX = touchSlopX * xSign;
        final double signedSlopY = touchSlopY * ySign;
        if (absoluteOffsetSlope != slopSlope) {
          // The drag goes through one or both of the extents of the edges of the box.
          if (absoluteOffsetSlope < slopSlope) {
            assert(offsetX.abs() > touchSlopX);
            // The drag goes through the vertical edge of the box.
            // It is guaranteed that the |offsetX| > touchSlopX.
            final double diffY = offsetSlope.abs() * touchSlopX * ySign;

            // The vector from the origin to the vertical edge.
            await gesture.moveBy(Offset(signedSlopX, diffY));
            if (offsetY.abs() <= touchSlopY) {
              // The drag ends on or before getting to the horizontal extension of the horizontal edge.
              await gesture.moveBy(Offset(offsetX - signedSlopX, offsetY - diffY));
            } else {
              final double diffY2 = signedSlopY - diffY;
              final double diffX2 = inverseOffsetSlope * diffY2;

              // The vector from the edge of the box to the horizontal extension of the horizontal edge.
              await gesture.moveBy(Offset(diffX2, diffY2));
              await gesture.moveBy(Offset(offsetX - diffX2 - signedSlopX, offsetY - signedSlopY));
            }
          } else {
            assert(offsetY.abs() > touchSlopY);
            // The drag goes through the horizontal edge of the box.
            // It is guaranteed that the |offsetY| > touchSlopY.
            final double diffX = inverseOffsetSlope.abs() * touchSlopY * xSign;

            // The vector from the origin to the vertical edge.
            await gesture.moveBy(Offset(diffX, signedSlopY));
            if (offsetX.abs() <= touchSlopX) {
              // The drag ends on or before getting to the vertical extension of the vertical edge.
              await gesture.moveBy(Offset(offsetX - diffX, offsetY - signedSlopY));
            } else {
              final double diffX2 = signedSlopX - diffX;
              final double diffY2 = offsetSlope * diffX2;

              // The vector from the edge of the box to the vertical extension of the vertical edge.
              await gesture.moveBy(Offset(diffX2, diffY2));
              await gesture.moveBy(Offset(offsetX - signedSlopX, offsetY - diffY2 - signedSlopY));
            }
          }
        } else { // The drag goes through the corner of the box.
          await gesture.moveBy(Offset(signedSlopX, signedSlopY));
          await gesture.moveBy(Offset(offsetX - signedSlopX, offsetY - signedSlopY));
        }
      } else { // The drag ends inside the box.
        await gesture.moveBy(offset);
      }
      await gesture.up();
    });
  }

  /// The next available pointer identifier.
  ///
  /// This is the default pointer identifier that will be used the next time the
  /// [startGesture] method is called without an explicit pointer identifier.
  int nextPointer = 1;

  int _getNextPointer() {
    final int result = nextPointer;
    nextPointer += 1;
    return result;
  }

  /// Creates gesture and returns the [TestGesture] object which you can use
  /// to continue the gesture using calls on the [TestGesture] object.
  ///
  /// You can use [startGesture] instead if your gesture begins with a down
  /// event.
  Future<TestGesture> createGesture({
    int pointer,
    PointerDeviceKind kind = PointerDeviceKind.touch,
    int buttons = kPrimaryButton,
  }) async {
    return TestGesture(
      hitTester: hitTestOnBinding,
      dispatcher: sendEventToBinding,
      kind: kind,
      pointer: pointer ?? _getNextPointer(),
      buttons: buttons,
    );
  }

  /// Creates a gesture with an initial down gesture at a particular point, and
  /// returns the [TestGesture] object which you can use to continue the
  /// gesture.
  ///
  /// You can use [createGesture] if your gesture doesn't begin with an initial
  /// down gesture.
  Future<TestGesture> startGesture(
    Offset downLocation, {
    int pointer,
    PointerDeviceKind kind = PointerDeviceKind.touch,
    int buttons = kPrimaryButton,
  }) async {
    final TestGesture result = await createGesture(
      pointer: pointer,
      kind: kind,
      buttons: buttons,
    );
    await result.down(downLocation);
    return result;
  }

  /// Forwards the given location to the binding's hitTest logic.
  HitTestResult hitTestOnBinding(Offset location) {
    final HitTestResult result = HitTestResult();
    binding.hitTest(result, location);
    return result;
  }

  /// Forwards the given pointer event to the binding.
  Future<void> sendEventToBinding(PointerEvent event, HitTestResult result) {
    return TestAsyncUtils.guard<void>(() async {
      binding.dispatchEvent(event, result);
    });
  }

  // GEOMETRY

  /// Returns the point at the center of the given widget.
  Offset getCenter(Finder finder) {
    return _getElementPoint(finder, (Size size) => size.center(Offset.zero));
  }

  /// Returns the point at the top left of the given widget.
  Offset getTopLeft(Finder finder) {
    return _getElementPoint(finder, (Size size) => Offset.zero);
  }

  /// Returns the point at the top right of the given widget. This
  /// point is not inside the object's hit test area.
  Offset getTopRight(Finder finder) {
    return _getElementPoint(finder, (Size size) => size.topRight(Offset.zero));
  }

  /// Returns the point at the bottom left of the given widget. This
  /// point is not inside the object's hit test area.
  Offset getBottomLeft(Finder finder) {
    return _getElementPoint(finder, (Size size) => size.bottomLeft(Offset.zero));
  }

  /// Returns the point at the bottom right of the given widget. This
  /// point is not inside the object's hit test area.
  Offset getBottomRight(Finder finder) {
    return _getElementPoint(finder, (Size size) => size.bottomRight(Offset.zero));
  }

  Offset _getElementPoint(Finder finder, Offset sizeToPoint(Size size)) {
    TestAsyncUtils.guardSync();
    final Element element = finder.evaluate().single;
    final RenderBox box = element.renderObject as RenderBox;
    assert(box != null);
    return box.localToGlobal(sizeToPoint(box.size));
  }

  /// Returns the size of the given widget. This is only valid once
  /// the widget's render object has been laid out at least once.
  Size getSize(Finder finder) {
    TestAsyncUtils.guardSync();
    final Element element = finder.evaluate().single;
    final RenderBox box = element.renderObject as RenderBox;
    assert(box != null);
    return box.size;
  }

  /// Simulates sending physical key down and up events through the system channel.
  ///
  /// This only simulates key events coming from a physical keyboard, not from a
  /// soft keyboard.
  ///
  /// Specify `platform` as one of the platforms allowed in
  /// [Platform.operatingSystem] to make the event appear to be from that type
  /// of system. Defaults to "android". Must not be null. Some platforms (e.g.
  /// Windows, iOS) are not yet supported.
  ///
  /// Keys that are down when the test completes are cleared after each test.
  ///
  /// This method sends both the key down and the key up events, to simulate a
  /// key press. To simulate individual down and/or up events, see
  /// [sendKeyDownEvent] and [sendKeyUpEvent].
  ///
  /// See also:
  ///
  ///  - [sendKeyDownEvent] to simulate only a key down event.
  ///  - [sendKeyUpEvent] to simulate only a key up event.
  Future<void> sendKeyEvent(LogicalKeyboardKey key, { String platform = 'android' }) async {
    assert(platform != null);
    await simulateKeyDownEvent(key, platform: platform);
    // Internally wrapped in async guard.
    return simulateKeyUpEvent(key, platform: platform);
  }

  /// Simulates sending a physical key down event through the system channel.
  ///
  /// This only simulates key down events coming from a physical keyboard, not
  /// from a soft keyboard.
  ///
  /// Specify `platform` as one of the platforms allowed in
  /// [Platform.operatingSystem] to make the event appear to be from that type
  /// of system. Defaults to "android". Must not be null. Some platforms (e.g.
  /// Windows, iOS) are not yet supported.
  ///
  /// Keys that are down when the test completes are cleared after each test.
  ///
  /// See also:
  ///
  ///  - [sendKeyUpEvent] to simulate the corresponding key up event.
  ///  - [sendKeyEvent] to simulate both the key up and key down in the same call.
  Future<void> sendKeyDownEvent(LogicalKeyboardKey key, { String platform = 'android' }) async {
    assert(platform != null);
    // Internally wrapped in async guard.
    return simulateKeyDownEvent(key, platform: platform);
  }

  /// Simulates sending a physical key up event through the system channel.
  ///
  /// This only simulates key up events coming from a physical keyboard,
  /// not from a soft keyboard.
  ///
  /// Specify `platform` as one of the platforms allowed in
  /// [Platform.operatingSystem] to make the event appear to be from that type
  /// of system. Defaults to "android". May not be null.
  ///
  /// See also:
  ///
  ///  - [sendKeyDownEvent] to simulate the corresponding key down event.
  ///  - [sendKeyEvent] to simulate both the key up and key down in the same call.
  Future<void> sendKeyUpEvent(LogicalKeyboardKey key, { String platform = 'android' }) async {
    assert(platform != null);
    // Internally wrapped in async guard.
    return simulateKeyUpEvent(key, platform: platform);
  }

  /// Returns the rect of the given widget. This is only valid once
  /// the widget's render object has been laid out at least once.
  Rect getRect(Finder finder) => getTopLeft(finder) & getSize(finder);

  /// Attempts to find the [SemanticsNode] of first result from `finder`.
  ///
  /// If the object identified by the finder doesn't own it's semantic node,
  /// this will return the semantics data of the first ancestor with semantics.
  /// The ancestor's semantic data will include the child's as well as
  /// other nodes that have been merged together.
  ///
  /// If the [SemanticsNode] of the object identified by the finder is
  /// force-merged into an ancestor (e.g. via the [MergeSemantics] widget)
  /// the node into which it is merged is returned. That node will include
  /// all the semantics information of the nodes merged into it.
  ///
  /// Will throw a [StateError] if the finder returns more than one element or
  /// if no semantics are found or are not enabled.
  SemanticsNode getSemantics(Finder finder) {
    if (binding.pipelineOwner.semanticsOwner == null)
      throw StateError('Semantics are not enabled.');
    final Iterable<Element> candidates = finder.evaluate();
    if (candidates.isEmpty) {
      throw StateError('Finder returned no matching elements.');
    }
    if (candidates.length > 1) {
      throw StateError('Finder returned more than one element.');
    }
    final Element element = candidates.single;
    RenderObject renderObject = element.findRenderObject();
    SemanticsNode result = renderObject.debugSemantics;
    while (renderObject != null && (result == null || result.isMergedIntoParent)) {
      renderObject = renderObject?.parent as RenderObject;
      result = renderObject?.debugSemantics;
    }
    if (result == null)
      throw StateError('No Semantics data found.');
    return result;
  }

  /// Enable semantics in a test by creating a [SemanticsHandle].
  ///
  /// The handle must be disposed at the end of the test.
  SemanticsHandle ensureSemantics() {
    return binding.pipelineOwner.ensureSemantics();
  }

  /// Given a widget `W` specified by [finder] and a [Scrollable] widget `S` in
  /// its ancestry tree, this scrolls `S` so as to make `W` visible.
  ///
  /// Usually the `finder` for this method should be labeled
  /// `skipOffstage: false`, so that [Finder] deals with widgets that's out of
  /// the screen correctly.
  ///
  /// This does not work when the `S` is long and `W` far away from the
  /// dispalyed part does not have a cached element yet. See
  /// https://github.com/flutter/flutter/issues/61458
  ///
  /// Shorthand for `Scrollable.ensureVisible(element(finder))`
  Future<void> ensureVisible(Finder finder) => Scrollable.ensureVisible(element(finder));

  /// Repeatedly scrolls the `scrollable` by `delta` in the
  /// [Scrollable.axisDirection] until `finder` is visible.
  ///
  /// Between each scroll, wait for `duration` time for settling.
  ///
  /// Throws a [StateError] if `finder` is not found for maximum `maxScrolls`
  /// times.
  ///
  /// This is different from [ensureVisible] in that this allows looking for
  /// `finder` that is not built yet, but the caller must specify the scrollable
  /// that will build child specified by `finder`.
  Future<void> scrollUntilVisible(
    Finder finder,
    Finder scrollable,
    double delta, {
      int maxScrolls = 50,
      Duration duration = const Duration(milliseconds: 50),
    }
  ) {
    assert(maxScrolls > 0);
    return TestAsyncUtils.guard<void>(() async {
      Offset moveStep;
      switch(widget<Scrollable>(scrollable).axisDirection) {
        case AxisDirection.up:
          moveStep = Offset(0, delta);
          break;
        case AxisDirection.down:
          moveStep = Offset(0, -delta);
          break;
        case AxisDirection.left:
          moveStep = Offset(delta, 0);
          break;
        case AxisDirection.right:
          moveStep = Offset(-delta, 0);
          break;
      }
      while(maxScrolls > 0 && finder.evaluate().isEmpty) {
        await drag(scrollable, moveStep);
        await pump(duration);
        maxScrolls -= 1;
      }
      await Scrollable.ensureVisible(element(finder));
    });
  }
}

/// Variant of [WidgetController] that can be used in tests running
/// on a device.
///
/// This is used, for instance, by [FlutterDriver].
class LiveWidgetController extends WidgetController {
  /// Creates a widget controller that uses the given binding.
  LiveWidgetController(WidgetsBinding binding) : super(binding);

  @override
  Future<void> pump([Duration duration]) async {
    if (duration != null)
      await Future<void>.delayed(duration);
    binding.scheduleFrame();
    await binding.endOfFrame;
  }

  @override
  Future<List<Duration>> handlePointerEventRecord(List<PointerEventRecord> records) {
    assert(records != null);
    assert(records.isNotEmpty);
    return TestAsyncUtils.guard<List<Duration>>(() async {
      // hitTestHistory is an equivalence of _hitTests in [GestureBinding],
      // used as state for all pointers which are currently down.
      final Map<int, HitTestResult> hitTestHistory = <int, HitTestResult>{};
      final List<Duration> handleTimeStampDiff = <Duration>[];
      DateTime startTime;
      for (final PointerEventRecord record in records) {
        final DateTime now = clock.now();
        startTime ??= now;
        // So that the first event is promised to receive a zero timeDiff
        final Duration timeDiff = record.timeDelay - now.difference(startTime);
        if (timeDiff.isNegative) {
          // This happens when something (e.g. GC) takes a long time during the
          // processing of the events.
          // Flush all past events
          handleTimeStampDiff.add(-timeDiff);
          for (final PointerEvent event in record.events) {
            _handlePointerEvent(event, hitTestHistory);
          }
        } else {
          await Future<void>.delayed(timeDiff);
          handleTimeStampDiff.add(
            // Recalculating the time diff for getting exact time when the event
            // packet is sent. For a perfect Future.delayed like the one in a
            // fake async this new diff should be zero.
            clock.now().difference(startTime) - record.timeDelay,
          );
          for (final PointerEvent event in record.events) {
            _handlePointerEvent(event, hitTestHistory);
          }
        }
      }
      // This makes sure that a gesture is completed, with no more pointers
      // active.
      assert(hitTestHistory.isEmpty);
      return handleTimeStampDiff;
    });
  }

  // This method is almost identical to [GestureBinding._handlePointerEvent]
  // to replicate the bahavior of the real binding.
  void _handlePointerEvent(
    PointerEvent event,
    Map<int, HitTestResult> _hitTests
  ) {
    HitTestResult hitTestResult;
    if (event is PointerDownEvent || event is PointerSignalEvent) {
      assert(!_hitTests.containsKey(event.pointer));
      hitTestResult = HitTestResult();
      binding.hitTest(hitTestResult, event.position);
      if (event is PointerDownEvent) {
        _hitTests[event.pointer] = hitTestResult;
      }
      assert(() {
        if (debugPrintHitTestResults)
          debugPrint('$event: $hitTestResult');
        return true;
      }());
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      hitTestResult = _hitTests.remove(event.pointer);
    } else if (event.down) {
      // Because events that occur with the pointer down (like
      // PointerMoveEvents) should be dispatched to the same place that their
      // initial PointerDownEvent was, we want to re-use the path we found when
      // the pointer went down, rather than do hit detection each time we get
      // such an event.
      hitTestResult = _hitTests[event.pointer];
    }
    assert(() {
      if (debugPrintMouseHoverEvents && event is PointerHoverEvent)
        debugPrint('$event');
      return true;
    }());
    if (hitTestResult != null ||
        event is PointerHoverEvent ||
        event is PointerAddedEvent ||
        event is PointerRemovedEvent) {
      binding.dispatchEvent(event, hitTestResult);
    }
  }
}
