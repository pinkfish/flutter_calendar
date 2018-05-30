import 'package:timezone/timezone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'calendarevent.dart';
import 'dart:async';
import 'sliverlistcalendar.dart';

class SharedCalendarState {
  int _currentTopIndex;
  Map<int, List<CalendarEvent>> events = {};
  Location location;
  CalendarSource source;
  StreamController<int> _updateController = new StreamController<int>();
  StreamController<bool> _headerExpandController = new StreamController<bool>();
  Stream<bool> _headerBroadcastStream;
  RenderSliverCenterList renderSliverList;
  ScrollController controller;
  bool _headerExpanded = false;

  SharedCalendarState(
      {@required this.source,
      @required TZDateTime currentTop,
      @required this.location})
      : _currentTopIndex =
            CalendarEvent.indexFromMilliseconds(currentTop, location);

  set currentTopIndex(int index) {
    _currentTopIndex = index;
    _updateController.add(index);
  }

  set headerExpanded (bool expanded) {
    if (expanded != _headerExpanded) {
      _headerExpanded = expanded;
      _headerExpandController.add(expanded);
    }
  }

  bool get headerExpanded => _headerExpanded;

  int get currentTopIndex => _currentTopIndex;

  Stream<int> get indexChangeStream {
    return _updateController.stream;
  }

  Stream<bool> get headerExpandedChangeStream {
    if (_headerBroadcastStream == null) {
      _headerBroadcastStream =
          _headerExpandController.stream.asBroadcastStream();
    }
    return _headerBroadcastStream;
  }

  void dispose() {
    _updateController?.close();
    _updateController = null;
    _headerExpandController?.close();
    _headerExpandController = null;
    _headerBroadcastStream = null;
  }

  void updateEvents(TZDateTime startWindow, TZDateTime endWindow) {
    List<CalendarEvent> rawEvents = source.getEvents(startWindow, endWindow);
    rawEvents.sort(
        (CalendarEvent e, CalendarEvent e2) => e.instant.compareTo(e2.instant));
    if (rawEvents.length > 0) {
      int curIndex =
          CalendarEvent.indexFromMilliseconds(rawEvents[0].instant, location);
      int sliceIndex = 0;
      // Get the offsets into the array.
      for (int i = 1; i < rawEvents.length; i++) {
        int index =
            CalendarEvent.indexFromMilliseconds(rawEvents[i].instant, location);
        if (index != curIndex) {
          if (sliceIndex != i) {
            events[curIndex] = rawEvents.sublist(sliceIndex, i);
          } else {
            events[curIndex] = [rawEvents[sliceIndex]];
          }
          curIndex = index;
          sliceIndex = i;
        }
      }
      if (sliceIndex != rawEvents.length) {
        events[curIndex] = rawEvents.sublist(sliceIndex);
      }
    }
  }

  static Map<String, SharedCalendarState> _data = {};

  static SharedCalendarState get(String coordinationKey) {
    return _data[coordinationKey];
  }

  static SharedCalendarState createState(String coordinationKey,
      CalendarSource source, TZDateTime currentTop, Location location) {
    if (_data.containsKey(coordinationKey)) {
      return _data[coordinationKey];
    }
    _data[coordinationKey] = new SharedCalendarState(
        source: source, currentTop: currentTop, location: location);
    return _data[coordinationKey];
  }
}
