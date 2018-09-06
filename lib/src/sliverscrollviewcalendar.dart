import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart';
import 'sliverlistcalendar.dart';
import 'calendardaymarker.dart';
import 'dart:async';
import 'calendarevent.dart';
import 'sharedcalendarstate.dart';

class SliverScrollViewCalendarElement extends StatelessElement
    implements CalendarEventElement {
  TZDateTime _startWindow;
  TZDateTime _endWindow;
  CalendarViewType _type;
  Set<int> _rangeVisible = new Set<int>();
  // View index is the number of days since the epoch.
  int _startDisplayIndex;
  Location _currentLocation;
  int _nowIndex;
  SharedCalendarState _sharedState;
  StreamSubscription<int> _topIndexChangedSubscription;

  static DateFormat monthFormat = new DateFormat(DateFormat.ABBR_MONTH);
  static DateFormat dayOfWeekFormat = new DateFormat(DateFormat.ABBR_WEEKDAY);
  static DateFormat dayOfMonthFormat =
      new DateFormat(DateFormat.ABBR_MONTH_DAY);

  SliverScrollViewCalendarElement(SliverScrollViewCalendar widget)
      : super(widget);

  void initState() {
    SliverScrollViewCalendar calendarWidget = widget;
    _sharedState = SharedCalendarState.get(calendarWidget.calendarKey);
    _sharedState.source.init(this);
    if (calendarWidget.location == null) {
      _currentLocation = local;
    } else {
      _currentLocation = calendarWidget.location;
    }
    _nowIndex = CalendarEvent.indexFromMilliseconds(
        new TZDateTime.now(_currentLocation), _currentLocation);
    _startDisplayIndex = calendarWidget.initialDate.millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay *
            2 -
        2;
    _sharedState.currentTopDisplayIndex = _startDisplayIndex ~/ 2;
    print("Display index $_startDisplayIndex $_nowIndex");
    _type = calendarWidget.view;
    // Normalize the dates.
    TZDateTime normalizedStart = new TZDateTime(
        _currentLocation,
        calendarWidget.initialDate.year,
        calendarWidget.initialDate.month,
        calendarWidget.initialDate.day);
    switch (_type) {
      case CalendarViewType.Schedule:
        // Grab 60 days ahead and 60 days behind.
        _startWindow = normalizedStart.subtract(new Duration(days: 60));
        _endWindow = normalizedStart.add(new Duration(days: 60));
        break;
      case CalendarViewType.Week:
        _startWindow = new TZDateTime(
            _currentLocation,
            calendarWidget.initialDate.year,
            calendarWidget.initialDate.month,
            calendarWidget.initialDate.day);
        if (_startWindow.weekday != 0) {
          if (_startWindow.weekday < 0) {
            _startWindow = _startWindow.subtract(new Duration(
                days: 0 - DateTime.daysPerWeek + _startWindow.weekday));
          } else {
            _startWindow = _startWindow
                .subtract(new Duration(days: 0 - _startWindow.weekday));
          }
          _endWindow =
              _startWindow.add(new Duration(days: DateTime.daysPerWeek));
        }
        break;
      case CalendarViewType.Month:
        _startWindow = new TZDateTime(_currentLocation,
            calendarWidget.initialDate.year, calendarWidget.initialDate.month);
        _endWindow = new TZDateTime(
            _currentLocation,
            calendarWidget.initialDate.year,
            calendarWidget.initialDate.month + 1);
        break;
    }
    updateEvents();
    _topIndexChangedSubscription =
        _sharedState.indexChangeStream.listen((int newIndex) {
      // NB: this is the display index, so in GM
      int ms = newIndex * Duration.millisecondsPerDay;

      bool changed = false;
      TZDateTime top =
          new TZDateTime.fromMillisecondsSinceEpoch(_currentLocation, ms);
      print("$top");
      if (_startWindow.difference(top).inDays < 30 ||
          top.isBefore(_startWindow)) {
        // Set a new start window.
        print("Moving start window $newIndex $top $_startWindow");
        _startWindow = top.subtract(new Duration(days: 60));
        changed = true;
      }
      if (_endWindow.difference(top).inDays < 30 || top.isAfter(_endWindow)) {
        _endWindow = top.add(new Duration(days: 60));
        changed = true;
      }
      if (changed) {
        print("Updating between $_startWindow $_endWindow");
        updateEvents();
      }
    });
  }

  @override
  void updateEvents() {
    // Now do stuff with our events.
    _sharedState.updateEvents(_startWindow, _endWindow);
    markNeedsBuild();
  }

  @override
  void scrollToDate(DateTime time) {
    SliverScrollViewCalendar calendarWidget = widget;
    RenderBox firstChild = _sharedState.renderSliverList.firstChild;
    int scrollToIndex =
        time.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay * 2;
    if (firstChild != null) {
      final SliverMultiBoxAdaptorParentData firstParentData =
          firstChild.parentData;
      // Already there...
      if (firstParentData.index == scrollToIndex ||
          firstParentData.index == scrollToIndex + 1) {
        return;
      }
      print(
          'Looking for $scrollToIndex ${firstParentData.index} ${time.month} ${time.day}');
      if (firstParentData.index < scrollToIndex) {
        print('Above');
        // See if it is in the visible set.
        RenderBox lastChild = _sharedState.renderSliverList.lastChild;
        if (lastChild != null) {
          final SliverMultiBoxAdaptorParentData lastParentData =
              lastChild.parentData;

          print('Last ${lastParentData.index}');
          if (lastParentData.index > scrollToIndex) {
            print('Range');
            // In range, easier scroll.
            SliverMultiBoxAdaptorParentData parentData;
            RenderBox currentChild = firstChild;
            do {
              currentChild =
                  _sharedState.renderSliverList.childAfter(currentChild);
              if (currentChild == null) {
                print('No current child! $currentChild');
                break;
              }
              parentData = currentChild.parentData as SliverMultiBoxAdaptorParentData;
              print('finding index ${parentData.index} $currentChild');
            } while (parentData.index != scrollToIndex);
            if (parentData != null && parentData.index == scrollToIndex) {
              // Yay!  Scroll there and end.
              calendarWidget.controller.animateTo(parentData.layoutOffset,
                  curve: Curves.easeIn,
                  duration: new Duration(milliseconds: 250));
              return;
            }
          }
        }
      }
      _sharedState.renderSliverList.newTopScrollIndex = scrollToIndex + 2;
      // Move the index up and down by a lot to force the refresh/move.
      if (firstParentData.index < scrollToIndex) {
        calendarWidget.controller.jumpTo(calendarWidget.controller.offset +
            Duration.microsecondsPerDay.toDouble());
      } else {
        calendarWidget.controller.jumpTo(calendarWidget.controller.offset -
            Duration.microsecondsPerDay.toDouble());
      }
    }
  }

  @override
  void mount(Element parent, dynamic newSlot) {
    initState();
    super.mount(parent, newSlot);
  }

  @override
  void rebuild() {
    _rangeVisible.clear();
    super.rebuild();
  }

  Widget _buildCalendarWidget(BuildContext context, int mainIndex) {
    SliverScrollViewCalendar calendarWidget = widget;
    const double widthFirst = 40.0;
    const double inset = 5.0;
    int ms = mainIndex ~/ 2 * Duration.millisecondsPerDay;
    DateTime time = new DateTime.fromMillisecondsSinceEpoch(ms);
    if (mainIndex % 2 == 1) {
      int index = CalendarEvent.indexFromMilliseconds(time, null);
      if (_sharedState.events.containsKey(index)) {
        List<CalendarEvent> events = _sharedState.events[index];
        DateTime day = events[0].instant;
        final Size screenSize = MediaQuery.of(context).size;
        double widthSecond = screenSize.width - widthFirst - inset;
        TextStyle style = Theme.of(context).textTheme.subhead.copyWith(
              fontWeight: FontWeight.w300,
            );
        List<Widget> displayEvents = <Widget>[];
        if (index == _nowIndex) {
          TZDateTime nowTime = new TZDateTime.now(_currentLocation);
          style.copyWith(color: Theme.of(context).accentColor);
          int lastMS =
              nowTime.millisecondsSinceEpoch - Duration.millisecondsPerDay;
          bool shownDivider = false;
          for (CalendarEvent e in events) {
            if (e.instant.millisecondsSinceEpoch > lastMS &&
                nowTime.isBefore(e.instantEnd)) {
              // Stick in the 'now marker' right here.
              displayEvents.add(new CalendarDayMarker(
                color: Colors.redAccent,
              ));
              displayEvents.add(_sharedState.source.buildWidget(context, e));
              shownDivider = true;
            } else if (e.instant.isAfter(nowTime) &&
                e.instantEnd.isBefore(nowTime)) {
              // Show on top of this card.
              displayEvents.add(new Stack(
                children: <Widget>[
                  _sharedState.source.buildWidget(context, e),
                  new CalendarDayMarker(color: Colors.redAccent),
                ],
              ));
            } else {
              displayEvents.add(_sharedState.source.buildWidget(context, e));
            }
          }
          if (!shownDivider) {
            displayEvents.add(new CalendarDayMarker(color: Colors.redAccent));
          }
        } else {
          displayEvents = events
              .map(
                (CalendarEvent e) =>
                    _sharedState.source.buildWidget(context, e),
              )
              .toList();
        }

        return new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            new Container(
              constraints: new BoxConstraints.tightFor(width: widthFirst),
              margin: new EdgeInsets.only(top: 5.0, left: inset),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  new Text(
                    dayOfWeekFormat.format(day),
                    style: style,
                  ),
                  new Text(
                    dayOfMonthFormat.format(day),
                    style: style.copyWith(fontSize: 10.0),
                  ),
                ],
              ),
            ),
            new Container(
              constraints: new BoxConstraints.tightFor(width: widthSecond),
              margin: new EdgeInsets.only(top: 10.0),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: displayEvents,
              ),
            ),
          ],
        );
      } else {
        int startIndex = index;
        DateTime start = time;
        // Show day/month headers
        if (!_sharedState.events.containsKey(
                CalendarEvent.indexFromMilliseconds(
                    time.add(oneDay), _currentLocation)) ||
            !_sharedState.events.containsKey(
                CalendarEvent.indexFromMilliseconds(
                    time.subtract(oneDay), _currentLocation))) {
          DateTime hardStart = new DateTime(start.year, start.month, 1);
          DateTime hardEnd =
              new DateTime(start.year, start.month + 1).subtract(oneDay);
          DateTime cur = start;
          DateTime last = cur;
          bool foundEnd = false;
          if (_rangeVisible.contains(startIndex)) {
            foundEnd = true;
          }
          int lastIndex = startIndex;
          while (hardEnd.compareTo(last) > 0 &&
              !_sharedState.events.containsKey(lastIndex + 1)) {
            last = last.add(oneDay);
            lastIndex =
                CalendarEvent.indexFromMilliseconds(last, _currentLocation);
            if (_rangeVisible.contains(lastIndex)) {
              foundEnd = true;
            }
          }
          // Pull back to the start too.
          cur = start;
          while (hardStart.compareTo(cur) < 0 &&
              !_sharedState.events.containsKey(startIndex)) {
            start = cur;
            cur = cur.subtract(oneDay);
            if (hardStart.compareTo(cur) < 0) {
              startIndex =
                  CalendarEvent.indexFromMilliseconds(cur, _currentLocation);
              if (_rangeVisible.contains(startIndex)) {
                foundEnd = true;
              }
            }
          }
          if (index % 10 == 0) {
            print('loc $index $startIndex $lastIndex $foundEnd');
          }

          if (!foundEnd &&
              !_rangeVisible.contains(startIndex) &&
              !_rangeVisible.contains(lastIndex)) {
            _rangeVisible.add(startIndex);
            _rangeVisible.add(lastIndex);
            // Range
            if (_nowIndex > startIndex && _nowIndex <= lastIndex) {
              print('$startIndex $lastIndex $_nowIndex $start $last');
              return new Container(
                margin: new EdgeInsets.only(top: 15.0, left: 5.0),
                child: new Stack(
                  children: <Widget>[
                    new Text(
                      monthFormat.format(start) +
                          " " +
                          start.day.toString() +
                          " - " +
                          last.day.toString(),
                      style: Theme.of(context).textTheme.subhead.copyWith(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w300,
                          ),
                    ),
                    new CalendarDayMarker(
                      indent: widthFirst,
                      color: Colors.redAccent,
                    ),
                  ],
                ),
              );
            } else {
              return new Container(
                margin: new EdgeInsets.only(top: 15.0, left: 5.0),
                child: new Text(
                  monthFormat.format(start) +
                      " " +
                      start.day.toString() +
                      " - " +
                      last.day.toString(),
                  style: Theme.of(context).textTheme.subhead.copyWith(
                        fontSize: 12.0,
                        fontWeight: FontWeight.w300,
                      ),
                ),
              );
            }
          }
        } else {
          // Single day
          if (_nowIndex == index) {
            return new Container(
              margin: new EdgeInsets.only(top: 10.0, left: 5.0),
              child: new Stack(
                children: <Widget>[
                  new Text(
                    MaterialLocalizations.of(context).formatMediumDate(start),
                    style: Theme.of(context).textTheme.subhead.copyWith(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w300,
                        ),
                  ),
                  new CalendarDayMarker(
                    indent: widthFirst,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            );
          } else {
            return new Container(
              margin: new EdgeInsets.only(top: 10.0, left: 5.0),
              child: new Text(
                MaterialLocalizations.of(context).formatMediumDate(start),
                style: Theme.of(context).textTheme.subhead.copyWith(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w300,
                    ),
              ),
            );
          }
        }
      }
    } else {
      // Put in the month header if we are at the start of the month.
      TZDateTime start =
          new TZDateTime(_currentLocation, time.year, time.month, time.day);
      if (start.day == 1) {
        return new Container(
          decoration: new BoxDecoration(
            color: Colors.blue,
            image: new DecorationImage(
              image: calendarWidget.monthHeader,
              fit: BoxFit.cover,
            ),
          ),
          margin: new EdgeInsets.only(top: 20.0),
          constraints: new BoxConstraints(minHeight: 100.0, maxHeight: 100.0),
          child: new Text(
            MaterialLocalizations.of(context).formatMonthYear(start),
            style: Theme.of(context).textTheme.title.copyWith(
                  color: Colors.white,
                  fontSize: 30.0,
                ),
          ),
        );
      }
    }
    return const SizedBox(height: 0.1);
  }

  SliverListCenter _buildCalendarList() {
    SliverScrollViewCalendar calendarWidget = widget;
    return new SliverListCenter(
      startIndex: _startDisplayIndex,
      calendarKey: calendarWidget.calendarKey,
      controller: calendarWidget.controller,
      delegate: new SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return _buildCalendarWidget(context, index);
        },
      ),
    );
  }

  void didUpdateWidget(covariant SliverScrollViewCalendar oldWidget) {}

  @override
  void update(StatelessWidget newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    // Notice that we mark ourselves as dirty before calling didUpdateWidget to
    // let authors call setState from within didUpdateWidget without triggering
    // asserts.
    markNeedsBuild();
    rebuild();
  }

  @override
  void activate() {
    super.activate();
    markNeedsBuild();
  }

  @override
  void unmount() {
    super.unmount();
    _sharedState.source.dispose();
    _topIndexChangedSubscription?.cancel();
    _topIndexChangedSubscription = null;
  }
}

class SliverScrollViewCalendar extends ScrollView {
  final DateTime initialDate;
  final CalendarViewType view;
  final Location location;
  final String calendarKey;
  final ImageProvider monthHeader;

  SliverScrollViewCalendar({
    @required this.initialDate,
    @required double initialScrollOffset,
    @required this.calendarKey,
    @required this.monthHeader,
    this.view = CalendarViewType.Schedule,
    this.location,
  }) : super(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            controller: new ScrollController(
                initialScrollOffset: initialScrollOffset)) {
    SharedCalendarState.get(calendarKey).controller = controller;
  }

  @override
  SliverScrollViewCalendarElement createElement() =>
      new SliverScrollViewCalendarElement(this);

  @override
  List<Widget> buildSlivers(BuildContext context) {
    SliverScrollViewCalendarElement element = context;
    return <Widget>[
      element._buildCalendarList(),
    ];
  }
}

class WrappedScrollViewCalendar extends StatefulWidget {
  final String calendarKey;
  final DateTime initialDate;
  final CalendarViewType view;
  final Location location;
  final double initialScrollOffset;
  final ImageProvider monthHeader;

  WrappedScrollViewCalendar({
    @required this.initialDate,
    @required this.initialScrollOffset,
    @required this.calendarKey,
    @required this.monthHeader,
    this.view = CalendarViewType.Schedule,
    this.location,
  });

  @override
  WrapperScrollViewCalendarState createState() {
    return new WrapperScrollViewCalendarState();
  }
}

class WrapperScrollViewCalendarState extends State<WrappedScrollViewCalendar> {
  SharedCalendarState _sharedCalendarState;
  StreamSubscription<bool> _onHeaderExpandChange;

  @override
  void initState() {
    super.initState();
    _sharedCalendarState = SharedCalendarState.get(widget.calendarKey);
    _onHeaderExpandChange =
        _sharedCalendarState.headerExpandedChangeStream.listen((bool update) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    _onHeaderExpandChange?.cancel();
    _onHeaderExpandChange = null;
  }

  void _handleTapOnHeaderExpanded() {
    _sharedCalendarState.headerExpanded = false;
  }

  @override
  Widget build(BuildContext context) {
    return new InkWell(
      onTap: _sharedCalendarState.headerExpanded
          ? _handleTapOnHeaderExpanded
          : null,
      child: new SliverScrollViewCalendar(
        initialDate: widget.initialDate,
        calendarKey: widget.calendarKey,
        location: widget.location,
        view: widget.view,
        monthHeader: widget.monthHeader,
        initialScrollOffset: widget.initialScrollOffset,
      ),
    );
  }
}
