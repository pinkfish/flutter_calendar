import 'package:timezone/timezone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'calendarevent.dart';
import 'dart:async';
import 'sliverlistcalendar.dart';


///
/// Keeps track of the shared calendar state across all the various pieces
/// of the calendar system that need the shared calendar state.
///
class SharedCalendarState {
  int _currentTopDisplayIndex;
  Map<int, List<CalendarEvent>> events = <int, List<CalendarEvent>>{};
  Location location;
  CalendarSource source;
  StreamController<int> _updateController = new StreamController<int>();
  StreamController<bool> _headerExpandController = new StreamController<bool>();
  Stream<bool> _headerBroadcastStream;
  Stream<int> _indexBroadcastStream;
  RenderSliverCenterList renderSliverList;
  ScrollController controller;
  bool _headerExpanded = false;

  SharedCalendarState(
      {@required this.source,
      @required DateTime currentTop,
      @required this.location})
      : _currentTopDisplayIndex =
            currentTop.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay {
    print("shared cal $_currentTopDisplayIndex");
  }

  /// Sets the current top index and tells people anbout the change.
  set currentTopDisplayIndex(int index) {
    _currentTopDisplayIndex = index;
    print("shared cal index $index");

    _updateController.add(index);
  }

  /// Update if the header is expanded and tell people about the change.
  set headerExpanded(bool expanded) {
    if (expanded != _headerExpanded) {
      _headerExpanded = expanded;
      _headerExpandController.add(expanded);
    }
  }

  /// If the header is currently expanded or not.
  bool get headerExpanded => _headerExpanded;

  /// The index of the current display, this is the display index and not
  /// the index into the events.
  int get currentTopDisplayIndex => _currentTopDisplayIndex;

  ///
  /// Broadcast stream to let the various elements know about the current
  /// top of the display.
  ///
  Stream<int> get indexChangeStream {
    if (_indexBroadcastStream == null) {
      _indexBroadcastStream = _updateController.stream.asBroadcastStream();
    }
    return _indexBroadcastStream;
  }

  /// Broadcast stream that is updated with the current state of the header
  /// when it changes.
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

  ///
  /// Updates the events in the given time range by pulling from the
  /// source and updating the indexes in the events mapping.
  ///
  void updateEvents(TZDateTime startWindow, TZDateTime endWindow) {
    List<CalendarEvent> rawEvents = source.getEvents(startWindow, endWindow);
    rawEvents.sort(
        (CalendarEvent e, CalendarEvent e2) => e.instant.compareTo(e2.instant));
    // Make sure we clean up the old indexes when we update.
    events.clear();
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
            events[curIndex] = <CalendarEvent>[rawEvents[sliceIndex]];
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

  static Map<String, SharedCalendarState> _data =
      <String, SharedCalendarState>{};

  ///
  /// Gets the shared calendar state for this specific co-ordination key.
  ///
  static SharedCalendarState get(String coordinationKey) {
    return _data[coordinationKey];
  }

  ///
  /// Creates the calendar state for the specific co-ordination key.
  ///
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
