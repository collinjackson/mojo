// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of internal;

class WaitManyState {
  static const int _GROWTH_SIZE = 100;
  Uint32List _handles;
  Uint32List _signals;
  Uint32List _outIndex;
  Uint64List _outSignals;

  // A port for each handle on which to send events back to the isolate that
  // owns the handle.
  List<SendPort> _ports;

  // A mapping from Mojo handles to their indices in _handles.
  Map<int, int> _handleIndices;

  int _occupied;

  WaitManyState() {
    _ports = [];
    _handleIndices = new Map<int, int>();
    _occupied = 0;
    _grow();
  }

  int get length => _occupied;
  Uint32List get handles => _handles;
  Uint32List get signals => _signals;
  List<SendPort> get ports => _ports;
  Map<int, int> get handleIndices => _handleIndices;

  // Output of calls to waitMany.
  int mojoResult;
  int get outIndex => _outIndex[0];
  int outSignals(int idx) =>
      _outSignals[idx] & MojoHandleWatcher.kMojoSignalsAll;

  void waitMany(int deadline) {
    mojoResult = MojoHandleWatcherNatives.waitMany(_occupied, deadline);
  }

  // The control handle lives at entry zero. So we add new entries at
  // index 1, shifting the existing entries down by 1. The idea here is that
  // more active handles will tend to be at the front of the list.
  void addFront(int handle, int signals, SendPort port) {
    if (_occupied == 0) {
      add(handle, signals, port);
      return;
    }

    // Grow if needed.
    if (_occupied == _handles.length) {
      _grow();
    }

    // Shift existing entries down by one.
    for (int i = _occupied - 1; i >= 1; i--) {
      int h = _handles[i];
      _handleIndices[h] = i + 1;
      _handles[i + 1] = h;
      _signals[i + 1] = _signals[i];
      _ports[i + 1] = _ports[i];
    }

    // Insert new entry.
    _handleIndices[handle] = 1;
    _handles[1] = handle;
    _signals[1] = signals;
    _ports[1] = port;
    _occupied++;
  }

  void add(int handle, int signals, SendPort port) {
    if (_occupied == _handles.length) {
      _grow();
    }
    _handleIndices[handle] = _occupied;
    _handles[_occupied] = handle;
    _signals[_occupied] = signals;
    _ports[_occupied] = port;
    _occupied++;
  }

  void removeLast() {
    int handle = _handles[_occupied - 1];
    _handleIndices[handle] = null;
    _handles[_occupied - 1] = 0;
    _signals[_occupied - 1] = 0;
    _ports[_occupied - 1] = null;
    _occupied--;
  }

  void remove(int idx) {
    if (idx == (_occupied - 1)) {
      removeLast();
      return;
    }
    // Copy the last element over the one being removed.
    int last = _occupied - 1;
    _handleIndices.remove(_handles[idx]);
    _handles[idx] = _handles[last];
    _signals[idx] = _signals[last];
    _ports[idx] = _ports[last];

    // Remove the old copy.
    removeLast();
    _handleIndices[_handles[idx]] = idx;
  }

  void _grow() {
    int newSize = _occupied + _GROWTH_SIZE;
    List newArrays =
        MojoHandleWatcherNatives.growStateArrays(_occupied + _GROWTH_SIZE);
    _handles = newArrays[0];
    _signals = newArrays[1];
    _outIndex = newArrays[2];
    _outSignals = newArrays[3];
    _ports.length = _handles.length;
  }

  String toString() {
    String hands = "";
    String sigs = "";
    for (int i = 0; i < _occupied; i++) {
      hands = "$hands ${_handles[i]}";
      sigs = "$sigs ${_outSignals[i] & _signals[i]}";
    }
    return "length: $_occupied\n"
        "status: $result\n"
        "index: $index\n"
        "handles: $hands\n"
        "signals: $sigs\n";
  }
}
