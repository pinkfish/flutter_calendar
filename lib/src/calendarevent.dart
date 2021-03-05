import 'package:timezone/timezone.dart';

/// One day duration to use in the rest of the system.
final Duration oneDay = Duration(days: 1);

///
/// The source for the calendar, this is where to get all the events from.
///
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
    required this.index,
    required this.instant,
    required TZDateTime instantEnd,
  }) : _instantEnd = instantEnd;

  /// The instant to display the event at.
  TZDateTime instant;
  TZDateTime _instantEnd;

  /// The index to use for the event.
  int index;

  /// when the event ends.
  TZDateTime get instantEnd => _instantEnd;

  static const int _yearOffset = 12 * 31;
  static const int _monthOffset = 31;

  /// get the index from the milliseconds that are passed in.
  static int indexFromMilliseconds(DateTime time, Location? loc) {
    return time.year * _yearOffset +
        (time.month - 1) * _monthOffset +
        time.day -
        1;
  }

  @override
  String toString() {
    return 'CalendarEvent{instant: $instant, index: $index}';
  }
}
