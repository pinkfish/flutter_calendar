import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart';

/// One day duration to use in the rest of the system.
const Duration oneDay = const Duration(days: 1);

///
/// The source for the calendar, this is where to get all the events from.
///
/*
abstract class CalendarSource {
  SliverScrollViewCalendarElement element;

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
  void init(SliverScrollViewCalendarElement key) {
    element = key;
    initState();
  }

  ///
  /// Scrolls the calendar to the specific datetime set here.  Note
  /// we only use the month/day/year for this.  The milliseconds is
  /// *not* correct and not in local time.
  ///
  void scrollToDay(DateTime time) {
    element.scrollToDate(time);
  }

  ///
  /// Called when the source is update by a widget redo.
  ///
  void didUpdateSource(CalendarSource source) {
  }

  ///
  /// Updates the events queue to rebuild the display.
  ///
  void updateEvents() {
    element.updateEvents();
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
*/

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
  CalendarEvent({
    @required this.index,
    @required this.instant,
    @required TZDateTime instantEnd,
  }) : _instantEnd = instantEnd;
  TZDateTime instant;
  TZDateTime _instantEnd;
  int index;

  TZDateTime get instantEnd => _instantEnd;

  static const int YEAR_OFFSET = 12 * 31;
  static const int MONTH_OFFSET = 31;

  static int indexFromMilliseconds(DateTime time, Location loc) {
    return time.year * YEAR_OFFSET +
        (time.month - 1) * MONTH_OFFSET +
        time.day -
        1;
  }

  @override
  String toString() {
    return 'CalendarEvent{instant: $instant, index: $index}';
  }
}
