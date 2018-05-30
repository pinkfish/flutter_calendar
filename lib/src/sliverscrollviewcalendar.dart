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
  int _startIndex;
  Location _currentLocation;
  int _nowIndex;
  SharedCalendarState _sharedState;

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
    _startIndex = CalendarEvent.indexFromMilliseconds(
                calendarWidget.initialDate, _currentLocation) *
            2 -
        2;
    _sharedState.currentTopIndex = _startIndex;
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
  }

  void updateEvents() {
    // Now do stuff with our events.
    _sharedState.updateEvents(_startWindow, _endWindow);
    markNeedsBuild();
  }

  @override
  void scrollToDate(TZDateTime time) {
    SliverScrollViewCalendar calendarWidget = widget;
    RenderBox firstChild = _sharedState.renderSliverList.firstChild;
    int scrollToIndex =
        CalendarEvent.indexFromMilliseconds(time, _currentLocation) * 2;
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
              parentData = currentChild.parentData;
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
      _sharedState.renderSliverList.newTopScrollIndex = scrollToIndex + 1;
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
    const double widthFirst = 40.0;
    const double inset = 5.0;
    if (mainIndex % 2 == 1) {
      int index = mainIndex ~/ 2;
      if (_sharedState.events.containsKey(index)) {
        List<CalendarEvent> events = _sharedState.events[index];
        DateTime day = events[0].instant;
        final Size screenSize = MediaQuery.of(context).size;
        double widthSecond = screenSize.width - widthFirst - inset;
        TextStyle style = Theme.of(context).textTheme.subhead.copyWith(
              fontWeight: FontWeight.w300,
            );
        List<Widget> displayEvents = [];
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
          children: [
            new Container(
              constraints: new BoxConstraints.tightFor(width: widthFirst),
              margin: new EdgeInsets.only(top: 5.0, left: inset),
              child: new Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
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
        int ms = index * Duration.millisecondsPerDay;
        DateTime start = new TZDateTime.fromMillisecondsSinceEpoch(
            _currentLocation, ms + _currentLocation.timeZone(ms).offset);
        // Show day/month headers
        if (!_sharedState.events.containsKey(index + 1) ||
            !_sharedState.events.containsKey(index - 1)) {
          TZDateTime hardStart =
              new TZDateTime(_currentLocation, start.year, start.month, 1);
          TZDateTime hardEnd =
              new TZDateTime(_currentLocation, start.year, start.month + 1)
                  .subtract(oneDay);
          TZDateTime cur = start;
          TZDateTime last = cur;
          bool foundEnd = false;
          if (_rangeVisible.contains(startIndex)) {
            foundEnd = true;
          }
          int lastIndex = startIndex;
          while (hardEnd.compareTo(last) > 0 &&
              !_sharedState.events.containsKey(lastIndex + 1)) {
            last = last.add(oneDay);
            lastIndex++;
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
              startIndex--;
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
            if (_nowIndex >= startIndex && _nowIndex <= lastIndex) {
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
      int index = (mainIndex + 2) ~/ 2;
      // Put in the month header if we are at the start of the month.
      int ms = index * Duration.millisecondsPerDay;
      TZDateTime start = new TZDateTime.fromMillisecondsSinceEpoch(
          _currentLocation, ms + _currentLocation.timeZone(ms).offset);
      if (start.day == 1) {
        return new Container(
          decoration: new BoxDecoration(
            color: Colors.blue,
            image: new DecorationImage(
              image: new AssetImage("assets/images/calendarbanner.jpg"),
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
      startIndex: _startIndex,
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
  void deactivate() {
    super.deactivate();
  }

  @override
  void unmount() {
    super.unmount();
    _sharedState.source.dispose();
  }

  @override
  InheritedWidget inheritFromWidgetOfExactType(Type targetType) {
    return super.inheritFromWidgetOfExactType(targetType);
  }
}

class SliverScrollViewCalendar extends ScrollView {
  final DateTime initialDate;
  final CalendarViewType view;
  final Location location;
  final String calendarKey;

  SliverScrollViewCalendar(
      {@required this.initialDate,
      this.view = CalendarViewType.Schedule,
      this.location,
      @required double initialScrollOffset,
      @required this.calendarKey})
      : super(
            scrollDirection: Axis.vertical,
            shrinkWrap: true,
            controller: new ScrollController(
                initialScrollOffset: initialScrollOffset)) {
    SharedCalendarState.get(calendarKey).controller = controller;
  }

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

  WrappedScrollViewCalendar(
      {@required this.initialDate,
      this.view = CalendarViewType.Schedule,
      this.location,
      @required this.initialScrollOffset,
      @required this.calendarKey});

  @override
  WrapperScrollViewCalendarState createState() {
    return new WrapperScrollViewCalendarState();
  }
}

class WrapperScrollViewCalendarState extends State<WrappedScrollViewCalendar> {
  SharedCalendarState _sharedCalendarState;
  StreamSubscription<bool> _onHeaderExpandChange;

  void initState() {
    super.initState();
    _sharedCalendarState = SharedCalendarState.get(widget.calendarKey);
    _onHeaderExpandChange =
        _sharedCalendarState.headerExpandedChangeStream.listen((bool update) {
      setState(() {});
    });
  }

  void dispose() {
    super.dispose();
    _onHeaderExpandChange?.cancel();
    _onHeaderExpandChange = null;
  }

  void _handleTapOnHeaderExpanded() {
    _sharedCalendarState.headerExpanded = false;
  }

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
        initialScrollOffset: widget.initialScrollOffset,
      ),
    );
  }
}
