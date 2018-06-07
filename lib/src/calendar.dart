import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:timezone/timezone.dart';
import 'calendarheader.dart';
import 'calendarevent.dart';
export 'calendarevent.dart';
import 'sharedcalendarstate.dart';
import 'sliverscrollviewcalendar.dart';

///
/// The widget to show the calendar with a header that displays the
/// current month, drop down and then the events in a sliverlist.
///
class CalendarWidget extends StatelessWidget {
  final TZDateTime initialDate;
  final CalendarSource source;
  final CalendarViewType view;
  final Location location;
  final double initialScrollOffset;
  final SharedCalendarState sharedState;
  final String coordinationKey;
  final ImageProvider monthHeader;
  final ImageProvider bannerHeader;

  ///
  /// Creates a calendar widget in place.  The [initialDate] is the date
  /// which will be used to show the first calendar in the list.  The
  /// [source] is used to get the events from.
  ///
  /// The [location] will set itself to the local location if it not set.  The
  /// calendarKey is used to co-ordinate all the pieces of the calendar across
  /// the widget.  THis will default to a useful value if not set, this is only
  /// really needed if you want to display more than one.
  ///
  /// The [initialScrollOffset] is where to put the scroll bar to start with
  /// if this is not set then the offset is so the microseconds since the epoc
  /// based on the initial date.
  ///
  CalendarWidget(
      {@required this.initialDate,
      @required this.source,
      @required this.bannerHeader,
      @required this.monthHeader,
      this.view = CalendarViewType.Schedule,
      Location location,
      String calendarKey,
      double initialScrollOffset})
      : location = location ?? local,
        coordinationKey = calendarKey ?? "calendarwidget",
        initialScrollOffset = initialScrollOffset ??
            new DateTime.now().microsecondsSinceEpoch.toDouble(),
        sharedState = SharedCalendarState.createState(
            calendarKey ?? "calendarwidget",
            source,
            initialDate,
            location ?? local);

  @override
  Widget build(BuildContext context) {
    return new Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        new CalendarHeader(coordinationKey, bannerHeader, location),
        new Expanded(
          child: new WrappedScrollViewCalendar(
              initialDate: initialDate,
              initialScrollOffset: initialScrollOffset,
              view: view,
              location: location,
              monthHeader: monthHeader,
              calendarKey: coordinationKey),
        ),
      ],
    );
  }
}
