import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart';

/// One day duration to use in the rest of the system.
const Duration oneDay = const Duration(days: 1);

///
/// The source for the calendar, this is where to get all the events from.
///
abstract class CalendarSource {
  CalendarEventElement state;

  List<CalendarEvent> getEvents(DateTime start, DateTime end);

  ///
  /// The widget for the specific calendar event, this is what to render
  /// when showing the calendar event.
  ///
  Widget buildWidget(BuildContext context, CalendarEvent index);

  ///
  /// Called on startup to connect the calendar event element to the source.
  /// This is used to handle the [scroolToDay] call.
  ///
  void init(CalendarEventElement state) {
    this.state = state;
    initState();
  }

  ///
  /// Scrolls the calendar to the specific datetime set here.
  ///
  void scrollToDay(TZDateTime time) {
    state.scrollToDate(time);
  }

  ///
  /// Called to initialize the state for the event.
  ///
  void initState();

  ///
  /// Called when the event is disposed.
  ///
  void dispose();
}

abstract class CalendarEventElement {
  void updateEvents();

  void scrollToDate(TZDateTime time);
}

/// The type of the calendar view to show.  Right now only schedule is
/// implemented.
enum CalendarViewType { Schedule, Week, Month }

///
/// The calendar event to display in the calendar.  This contains details
/// about how to render it and display it.
///
class CalendarEvent {
  CalendarEvent(
      {@required this.index,
      @required TZDateTime instant,
      @required TZDateTime instantEnd})
      : this.instant = instant,
        _instantEnd = instantEnd;
  TZDateTime instant;
  TZDateTime _instantEnd;
  int index;

  TZDateTime get instantEnd => _instantEnd;

  static int indexFromMilliseconds(DateTime time, Location loc) {
    if (loc == null) {
      return time.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    }
    return ((time.millisecondsSinceEpoch +
            loc.timeZone(time.millisecondsSinceEpoch).offset) ~/
        Duration.millisecondsPerDay);
  }

  @override
  String toString() {
    return 'CalendarEvent{instant: $instant, index: $index}';
  }
}
