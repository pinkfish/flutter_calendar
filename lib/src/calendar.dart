import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:timezone/timezone.dart';

import 'calendarevent.dart';
import 'calendarheader.dart';
import 'sliverlistcalendar.dart';
import 'sliverscrollviewcalendar.dart';

export 'calendarevent.dart';

///
/// Create a calendar event list between the two bounding dates.
///
typedef List<CalendarEvent> CalendarEventBuilder(DateTime start, DateTime end);

///
/// The widget for the specific calendar event, this is what to render
/// when showing the calendar event.
///
typedef Widget CalendarWidgetBuilder(BuildContext context, CalendarEvent index);

///
/// The widget to show the calendar with a header that displays the
/// current month, drop down and then the events in a sliverlist.
///
class CalendarWidget extends StatefulWidget {
  ///
  /// Creates a calendar widget in place.  The [initialDate] is the date
  /// which will be used to show the first calendar in the list.  The
  /// [source] is used to get the events from.
  ///
  /// The [header] object can be used to completely customise the header used
  /// in the calendar.  It defaults to making one based on the [CalendarHeader]
  /// class.
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
  CalendarWidget({
    required this.initialDate,
    required this.buildItem,
    required this.getEvents,
    TZDateTime? beginningRangeDate,
    TZDateTime? endingRangeDate,
    this.bannerHeader,
    this.monthHeader,
    Key? key,
    this.view = CalendarViewType.Schedule,
    this.weekBeginsWithDay = 0,
    Location? location,
    String? calendarKey,
    double? initialScrollOffset,
    this.headerColor,
    this.headerMonthStyle,
    this.headerExpandIconColor,
    this.tapToCloseHeader = true,
    this.header,
  })  : beginningRangeDate =
            beginningRangeDate ?? TZDateTime(location ?? local, 2010),
        endingRangeDate = endingRangeDate ??
            TZDateTime(location ?? local, clock.now().year + 2),
        assert(beginningRangeDate == null ||
            (beginningRangeDate.compareTo(initialDate) <= 0) &&
                (endingRangeDate == null ||
                    initialDate.compareTo(endingRangeDate) <= 0)),
        location = location ?? local,
        initialScrollOffset = initialScrollOffset ??
            initialDate.microsecondsSinceEpoch.toDouble(),
        super(key: key);

  /// The initial date to show the calendar for.
  final TZDateTime initialDate;

  ///
  /// The edge of the range to display in the calendar, cannot scroll
  /// back past this point
  ///
  final TZDateTime beginningRangeDate;

  ///
  /// The end of the range to display yin the calendar, cannot scroll forward
  /// past this point.
  ///
  final TZDateTime endingRangeDate;

  /// The type of the calendar to displau.
  final CalendarViewType view;

  /// which day to begin the week for when displaying a week
  final int
      weekBeginsWithDay; // Sunday = 0, Monday = 1, Tuesday = 2, ..., Saturday = 6
  /// the timezone locatrion to use fdor the days.
  final Location location;

  /// Where to start the scroll at.
  final double initialScrollOffset;

  /// Returns the events to use to display on the screen.
  final CalendarEventBuilder getEvents;

  /// building the widget to display for each of the events in the calendar.
  final CalendarWidgetBuilder buildItem;

  /// the header to use at the top of each momth.
  final ImageProvider? monthHeader;

  /// the header to use at the top of the banner.
  final ImageProvider? bannerHeader;

  /// The color of the header.
  final Color? headerColor;

  /// The style to use for displaying the header for the month.
  final TextStyle? headerMonthStyle;

  /// The color of the expand icon for the header.
  final Color? headerExpandIconColor;

  /// If you can close the header with a tap.
  final bool tapToCloseHeader;

  /// The header to display.
  final Widget? header;

  @override
  State createState() {
    return CalendarWidgetState();
  }
}

///
/// The state for the calendar widget.
///
class CalendarWidgetState extends State<CalendarWidget> {
  CalendarWidgetState() {
    _headerBroadcastStream = _headerExpandController.stream.asBroadcastStream();
    _indexBroadcastStream = _updateController.stream.asBroadcastStream();
  }

  late int _currentTopDisplayIndex;
  Map<int, List<CalendarEvent>> events = <int, List<CalendarEvent>>{};
  StreamController<int> _updateController = StreamController<int>();
  StreamController<bool> _headerExpandController = StreamController<bool>();
  late Stream<bool> _headerBroadcastStream;
  late Stream<int> _indexBroadcastStream;
  late RenderSliverCenterList renderSliverList;
  bool _headerExpanded = false;
  SliverScrollViewCalendarElement? element;
  ScrollController? controller;

  @override
  void initState() {
    _currentTopDisplayIndex = widget.initialDate.millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    super.initState();
  }

  /// Sets the current top index and tells people about the change.
  set currentTopDisplayIndex(int index) {
    _currentTopDisplayIndex = index;

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
    return _indexBroadcastStream;
  }

  /// Broadcast stream that is updated with the current state of the header
  /// when it changes.
  Stream<bool>? get headerExpandedChangeStream {
    return _headerBroadcastStream;
  }

  @override
  void dispose() {
    // stop it being disposed twice, althougn not sure why it is being disposed
    // twice.
    super.dispose();
    _updateController.close();
    _headerExpandController.close();
  }

  ///
  /// Updates the events in the given time range by pulling from the
  /// source and updating the indexes in the events mapping.
  ///
  void updateInternalEvents(TZDateTime startWindow, TZDateTime endWindow) {
    List<CalendarEvent> rawEvents = widget.getEvents(startWindow, endWindow);
    rawEvents.sort(
        (CalendarEvent e, CalendarEvent e2) => e.instant.compareTo(e2.instant));
    // Make sure we clean up the old indexes when we update.
    events.clear();
    if (rawEvents.isNotEmpty) {
      int curIndex = CalendarEvent.indexFromMilliseconds(
          rawEvents[0].instant, widget.location);
      int sliceIndex = 0;
      // Get the offsets into the array.
      for (int i = 1; i < rawEvents.length; i++) {
        int index = CalendarEvent.indexFromMilliseconds(
            rawEvents[i].instant, widget.location);
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

  //static Map<String, SharedCalendarState> _data =
  //<String, SharedCalendarState>{};

  ///
  /// Creates the calendar state for the specific co-ordination key.
  ///
  /*
  static SharedCalendarState createState(String coordinationKey,
      CalendarSource source, TZDateTime currentTop, Location location) {
    if (_data.containsKey(coordinationKey)) {
      // Update the source into the new shared state and fix the elemet.
      CalendarSource old = _data[coordinationKey].source;
      _data[coordinationKey].source = source;
      source.init(old.element);
      source.didUpdateSource(old);
      return _data[coordinationKey];
    }
    return _data[coordinationKey];
  }
  */

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        widget.header ??
            CalendarHeader(
                this,
                widget.bannerHeader,
                widget.location,
                widget.headerColor,
                widget.headerMonthStyle,
                widget.headerExpandIconColor,
                widget.weekBeginsWithDay,
                null,
                null,
                widget.beginningRangeDate,
                widget.endingRangeDate),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 5.0),
            child: WrappedScrollViewCalendar(
              state: this,
              initialDate: widget.initialDate,
              beginningRangeDate: widget.beginningRangeDate,
              endingRangeDate: widget.endingRangeDate,
              initialScrollOffset: widget.initialScrollOffset,
              view: widget.view,
              location: widget.location,
              monthHeader: widget.monthHeader,
              tapToCloseHeader: widget.tapToCloseHeader,
            ),
          ),
        ),
      ],
    );
  }

  ///
  /// Scrolls the calendar to the specific datetime set here.  Note
  /// we only use the month/day/year for this.  The milliseconds is
  /// *not* correct and not in local time.
  ///
  void scrollToDay(DateTime time) {
    if (element != null) {
      element!.scrollToDate(time);
    }
  }

  ///
  /// Update the events on the screen when things change.
  /// This causes the system to re-ask for the events.
  ///
  void updateEvents() {
    if (element != null) {
      element!.updateEvents();
    }
  }
}
