// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of core;

import 'dart:math' as math;

class DataPipeFiller {
  MojoDataPipeProducer _producer;
  MojoEventStream _eventStream;
  ByteData _data;
  int _dataPosition;

  DataPipeFiller(this._producer, this._data) {
    _eventStream = new MojoEventStream(_producer.handle);
    _dataPosition = 0;
  }

  MojoResult _doWrite() {
    ByteData thisWrite = _producer.beginWrite(_data.length);
    if (thisWrite == null) {
      throw 'Data pipe beginWrite failed: ${_producer.status}';
    }
    int writeBytes = thisWrite.lengthInBytes.clamp(0, _data.length - _dataPosition);
    Uint8List _dataList = _data.buffer.asUint8List();
    thisWrite.buffer.asUint8List().setRange(0, writeBytes, _dataList, _dataPosition);
    _dataPosition += writeBytes;
    return _producer.endWrite(writeBytes);
  }

  void fill() {
    _eventStream.listen((List<int> event) {
      var mojoSignals = new MojoHandleSignals(event[1]);
      if (mojoSignals.isWritable) {
        var result = _doWrite();
        if (!result.isOk) {
          _eventStream.close();
          _eventStream = null;
        } else {
          _eventStream.enableWriteEvents();
        }
      } else if (mojoSignals.isPeerClosed) {
        _eventStream.close();
        _eventStream = null;
      } else {
        throw 'Unexpected handle event: $mojoSignals';
      }
    });
  }

  static void fillHandle(MojoDataPipeProducer producer, ByteData data) {
    var filler = new DataPipeFiller(consumer, data);
    filler.fill();
  }
}
