import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'calendarheader.dart';
import 'calendarevent.dart';
export 'calendarevent.dart';
import 'sliverscrollviewcalendar.dart';
import 'sliverlistcalendar.dart';
import 'dart:async';

typedef List<CalendarEvent> CalendarEventBuiler(DateTime start, DateTime end);

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
  final DateTime initialDate;
  final CalendarViewType view;

  final double initialScrollOffset;
  final CalendarEventBuiler getEvents;
  final CalendarWidgetBuilder buildItem;
  final ImageProvider monthHeader;
  final ImageProvider bannerHeader;
  final Color headerColor;
  final TextStyle headerMonthStyle;
  final Widget header;

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
    @required this.initialDate,
    @required this.bannerHeader,
    @required this.monthHeader,
    @required this.buildItem,
    @required this.getEvents,
    Key key,
    this.view = CalendarViewType.Schedule,
    String calendarKey,
    double initialScrollOffset,
    this.headerColor,
    this.headerMonthStyle,
    this.header,
  })  : initialScrollOffset = initialScrollOffset ??
            new DateTime.now().microsecondsSinceEpoch.toDouble(),
        super(key: key);

  @override
  State createState() {
    return CalendarWidgetState();
  }
}

class CalendarWidgetState extends State<CalendarWidget> {
  int _currentTopDisplayIndex;
  Map<int, List<CalendarEvent>> events = <int, List<CalendarEvent>>{};
  StreamController<int> _updateController = new StreamController<int>();
  StreamController<bool> _headerExpandController = new StreamController<bool>();
  Stream<bool> _headerBroadcastStream;
  Stream<int> _indexBroadcastStream;
  RenderSliverCenterList renderSliverList;
  ScrollController controller;
  bool _headerExpanded = false;
  SliverScrollViewCalendarElement element;

  @override
  void initState() {
    super.initState();
    currentTopDisplayIndex = widget.initialDate.millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  /// Sets the current top index and tells people anbout the change.
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

  @override
  void dispose() {
    _updateController?.close();
    _updateController = null;
    _headerExpandController?.close();
    _headerExpandController = null;
    _headerBroadcastStream = null;
    super.dispose();
  }

  ///
  /// Updates the events in the given time range by pulling from the
  /// source and updating the indexes in the events mapping.
  ///
  void updateInternalEvents(DateTime startWindow, DateTime endWindow) {
    List<CalendarEvent> rawEvents = widget.getEvents(startWindow, endWindow);
    rawEvents.sort(
        (CalendarEvent e, CalendarEvent e2) => e.instant.compareTo(e2.instant));
    // Make sure we clean up the old indexes when we update.
    events.clear();
    if (rawEvents.length > 0) {
      int curIndex = CalendarEvent.indexFromMilliseconds(rawEvents[0].instant);
      int sliceIndex = 0;
      // Get the offsets into the array.
      for (int i = 1; i < rawEvents.length; i++) {
        int index = CalendarEvent.indexFromMilliseconds(rawEvents[i].instant);
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
    return new Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        widget.header ??
            new CalendarHeader(this, widget.bannerHeader, widget.headerColor,
                widget.headerMonthStyle, null, null),
        new Expanded(
          child: new WrappedScrollViewCalendar(
            state: this,
            initialDate: widget.initialDate,
            initialScrollOffset: widget.initialScrollOffset,
            view: widget.view,
            monthHeader: widget.monthHeader,
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
    element.scrollToDate(time);
  }

  ///
  /// Update the events on the screen when things change.
  /// This causes the system to re-ask for the events.
  ///
  void updateEvents() {
    element.updateEvents();
  }
}
