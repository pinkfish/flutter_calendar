import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:timezone/timezone.dart';

import 'calendar.dart';
import 'calendarevent.dart';

const Duration _kExpand = const Duration(milliseconds: 200);

///
/// This function will be called to generate a day in the header.  By
/// default it does this.  Which is overlaid by the event indicators.
/// button = new Center(
///        child: new FlatButton(
///          color: day.isAtSameMomentAs(nowTime)
///              ? theme.accentColor
///              : day.isAtSameMomentAs(displayDate)
///                  ? Colors.grey.shade200
///                  : Colors.white,
///          shape: new CircleBorder(),
///          child: new Text(day.day.toString()),
///          onPressed: () => sharedState.source.scrollToDay(day),
///          padding: EdgeInsets.zero,
///        ),
///      );
///
typedef HeaderDayIndicator = Widget Function(
    ThemeData theme, DateTime day, DateTime nowTime);

///
/// Generates the small boxes on the calendar to indicate that there are events
/// on this specific day.  It creates a stack and then puts in the main day
/// button inside the stack with the event indicators overlaid on top of it.
/// The calendar events are the events on this day.  It can be an empty array.
///
typedef EventIndicator = Widget Function(
    Widget button, List<CalendarEvent> events);

///
/// Displays the header for the calendar.  This handles the title with the
/// month/year and a drop down item as well as opening to show the whole month.
///
class CalendarHeader extends StatefulWidget {
  ///
  /// Creates the calendar header.  [calendarKey] is the key to find the shared
  /// state from.  [location] to use for the calendar.
  ///
  /// See [EventIndicator] and [HeaderDayIndicator] for details on how the
  /// day and event indicators can be customized.
  ///
  CalendarHeader(
    this.state,
    this.bannerHeader,
    Location location,
    this.color,
    this.headerStyle,
    this.expandIconColor,
    this.weekBeginsWithDay,
    this.dayIndicator,
    this.eventIndicator, 
    this.beginningRangeDate,
    this.endingRangeDate
  ) : _location = location ?? local;

  final Location _location;
  final CalendarWidgetState state;
  final ImageProvider bannerHeader;
  final Color color;
  final TextStyle headerStyle;
  final Color expandIconColor;
  final int weekBeginsWithDay;
  final EventIndicator eventIndicator;
  final HeaderDayIndicator dayIndicator;
  final TZDateTime beginningRangeDate;
  final TZDateTime endingRangeDate;

  @override
  State createState() {
    return new CalendarHeaderState();
  }
}

///
/// The calendar state associated with the header.
///
class CalendarHeaderState extends State<CalendarHeader> with SingleTickerProviderStateMixin {
  double get maxExtent => 55.0;

  StreamSubscription<int> _subscription;
  StreamSubscription<bool> _headerExpandedSubscription;
  StreamSubscription<int> _indexChangeSubscription;
  //SharedCalendarState sharedState;
  AnimationController _controller;
  CurvedAnimation _easeInAnimation;
  Animation<double> _iconTurns;
  bool myExpandedState = false;
  int _monthIndex;
  int _beginningMonthIndex;
  int _endingMonthIndex;

  int monthIndexFromTime(DateTime time) {
    return (time.year - 1970) * 12 + (time.month - 1);
  }

  DateTime monthToShow(int index) {
    return new DateTime(index ~/ 12 + 1970, index % 12 + 1, 1);
  }

  @override
  void initState() {
    super.initState();
    _monthIndex = monthIndexFromTime(new DateTime.now());
    _beginningMonthIndex = widget.beginningRangeDate != null ? monthIndexFromTime(widget.beginningRangeDate) : -1;
    _endingMonthIndex = widget.endingRangeDate != null ? monthIndexFromTime(widget.endingRangeDate) : -1;
    _controller = new AnimationController(duration: _kExpand, vsync: this);
    //sharedState = SharedCalendarState.get(widget.calendarKey);
    _easeInAnimation =
        new CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _iconTurns =
        new Tween<double>(begin: 0.0, end: 0.5).animate(_easeInAnimation);
    _indexChangeSubscription =
        widget.state.indexChangeStream.listen((int newTop) {
      setState(() {
        int ms = (widget.state.currentTopDisplayIndex + 1) *
            Duration.millisecondsPerDay;
        DateTime currentTopTemp = new DateTime.fromMillisecondsSinceEpoch(ms);

        _monthIndex = monthIndexFromTime(currentTopTemp);
      });
    });
    _headerExpandedSubscription =
        widget.state.headerExpandedChangeStream.listen((bool change) {
      if (myExpandedState != change) {
        setState(() {
          myExpandedState = change;
          _doAnimation();
        });
      }
    });
  }

  void _doAnimation() {
    if (myExpandedState) {
      _controller.forward();
    } else {
      _controller.reverse().then<void>((void value) {
        setState(() {
          // Rebuild without widget.children.
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _subscription?.cancel();
    _subscription = null;
    _controller?.dispose();
    _controller = null;
    _headerExpandedSubscription?.cancel();
    _headerExpandedSubscription = null;
    _indexChangeSubscription?.cancel();
    _indexChangeSubscription = null;
  }

  void _handleOpen() {
    setState(() {
      // Jump the page controller to the right spot.
      myExpandedState = !widget.state.headerExpanded;
      widget.state.headerExpanded = myExpandedState;
      _doAnimation();
      PageStorage.of(context)
          ?.writeState(context, widget.state..headerExpanded);
    });
  }

  Widget _buildChildren(BuildContext context, Widget child) {
    DismissDirection direction = DismissDirection.horizontal;
    if (_beginningMonthIndex == _monthIndex) {
      direction = DismissDirection.endToStart;
    } else if (_endingMonthIndex == _monthIndex) {
      direction = DismissDirection.startToEnd;
    }

    return new Container(
      child: new Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildCurrentHeader(context),
          new ClipRect(
            child: new Align(
              heightFactor: _easeInAnimation.value,
              child: new Container(
                constraints:
                    new BoxConstraints(minHeight: 230.0, maxHeight: 230.0),
                child: new Dismissible(
                  key: new ValueKey<int>(_monthIndex),
                  resizeDuration: null,
                  dismissThresholds: const <DismissDirection, double>{DismissDirection.horizontal: 0.2},
                  direction: direction,
                  onDismissed: (DismissDirection direction) {
                    setState(() {
                      _monthIndex +=
                          direction == DismissDirection.endToStart ? 1 : -1;
                      // Update the current scroll pos too.
                      widget.state.scrollToDay(monthToShow(_monthIndex));
                    });
                  },
                  child: new _CalendarMonthDisplay(
                    widget.state,
                    widget._location,
                    monthToShow(_monthIndex),
                    widget.weekBeginsWithDay,
                    widget.dayIndicator,
                    widget.eventIndicator,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Material(
      elevation: 4.0,
      color: widget.color ?? Colors.white,
      child: new AnimatedBuilder(
        animation: _controller,
        builder: _buildChildren,
        child: _buildCurrentHeader(context),
      ),
    );
  }

  Widget _buildCurrentHeader(BuildContext context) {
    int ms =
        (widget.state.currentTopDisplayIndex + 1) * Duration.millisecondsPerDay;
    DateTime currentTopTemp = new DateTime.fromMillisecondsSinceEpoch(ms);
    DateTime currentTop = new DateTime(
        currentTopTemp.year, currentTopTemp.month, currentTopTemp.day);

    return new Container(
      padding: new EdgeInsets.only(top: 10.0, left: 5.0, bottom: 10.0),
      decoration: new BoxDecoration(
        color: widget.color ?? Colors.white,
        image: widget.bannerHeader != null ? new DecorationImage(
          image: widget.bannerHeader,
          fit: BoxFit.fitHeight,
          alignment: new Alignment(1.0, 1.0),
        ) : null,
      ),
      child: new GestureDetector(
        onTap: _handleOpen,
        child: new Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            new Text(
              (myExpandedState
                  ? MaterialLocalizations.of(context)
                      .formatMonthYear(monthToShow(_monthIndex))
                  : MaterialLocalizations.of(context)
                      .formatMonthYear(currentTop)) + ' ',
              style: widget.headerStyle ??
                  Theme.of(context).textTheme.title.copyWith(fontSize: 25.0),
            ),
            new RotationTransition(
              turns: _iconTurns,
              child: new Icon(
                Icons.expand_more,
                color: widget.expandIconColor ?? Colors.black,
                size: 25.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

///
/// Shows a small dot for the event to show the calendar day has a specific
/// event at it.
///
class _CalendarEventIndicator extends CustomPainter {
  _CalendarEventIndicator(this._radius, this._event);

  final double _radius;
  final CalendarEvent _event;

  @override
  void paint(Canvas canvas, Size size) {
    if (_radius == null) {
      return;
    }
    canvas.drawCircle(new Offset(_radius, _radius), _radius,
        new Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_CalendarEventIndicator other) =>
      other._radius != _radius || other._event != _event;
}

///
/// The animated container to show for the month with all the days and the
/// day headers.
///
class _CalendarMonthDisplay extends StatelessWidget {
  _CalendarMonthDisplay(this.sharedState, this.location, this.displayDate,
      this.weekBeginsWithDay, this.dayIndicator, this.eventIndicator);

  final CalendarWidgetState sharedState;
  final Location location;
  final DateTime displayDate;
  final int weekBeginsWithDay;
  final HeaderDayIndicator dayIndicator;
  final EventIndicator eventIndicator;

  static const Duration week = const Duration(days: 7);

  Widget _eventIndicator(Widget button, int eventIndex) {
    if (sharedState.events.containsKey(eventIndex)) {
      if (eventIndicator != null) {
        return eventIndicator(button, sharedState.events[eventIndex]);
      }
      List<Widget> eventIndicators = <Widget>[];
      for (CalendarEvent event in sharedState.events[eventIndex]) {
        eventIndicators.add(
          new SizedBox(
            height: 4.0,
            width: 4.0,
            child: new CustomPaint(
              painter: new _CalendarEventIndicator(2.0, event),
            ),
          ),
        );
        eventIndicators.add(
          new SizedBox(
            width: 2.0,
          ),
        );
      }
      return new SizedBox(
        width: 40.0,
        height: 40.0,
        child: new Stack(
          children: <Widget>[
            button,
            new Container(
              alignment: new Alignment(1.0, 1.0),
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                children: eventIndicators,
              ),
            ),
          ],
        ),
      );
    } else {
      if (eventIndicator != null) {
        return eventIndicator(button, <CalendarEvent>[]);
      }
      return new SizedBox(
        width: 40.0,
        height: 40.0,
        child: button,
      );
    }
  }

  Widget _buildButton(ThemeData theme, DateTime day, DateTime nowTime) {
    Widget button;
    // Only show days in the current month.
    if (day.month != displayDate.month) {
      button = new SizedBox(width: 1.0);
    } else {
      if (dayIndicator != null) {
        button = dayIndicator(theme, day, nowTime);
      } else {
        button = new Center(
          child: new FlatButton(
            color: day.isAtSameMomentAs(nowTime)
                ? theme.accentColor
                : day.isAtSameMomentAs(displayDate)
                    ? Colors.grey.shade200
                    : Colors.white,
            shape: new CircleBorder(),
            child: new Text(day.day.toString()),
            onPressed: () => sharedState.scrollToDay(day),
            padding: EdgeInsets.zero,
          ),
        );
      }
    }
    int eventIndex = CalendarEvent.indexFromMilliseconds(day, location);
    return _eventIndicator(button, eventIndex);
  }

  @override
  Widget build(BuildContext context) {
    DateTime nowTmp = new DateTime.now();
    DateTime nowTime = new DateTime(nowTmp.year, nowTmp.month, nowTmp.day);
    DateTime topFirst = displayDate;
    topFirst = topFirst.subtract(new Duration(days: topFirst.weekday - weekBeginsWithDay));
    DateTime topSecond = topFirst.add(week);
    if (topSecond.day == 1) {
      // Opps, out by a week.
      topFirst = topSecond;
      topSecond = topFirst.add(week);
    }
    DateTime topThird = topSecond.add(week);
    DateTime topFourth = topThird.add(week);
    DateTime topFifth = topFourth.add(week);
    List<Widget> dayHeaders = <Widget>[];
    List<Widget> firstDays = <Widget>[];
    List<Widget> secondDays = <Widget>[];
    List<Widget> thirdDays = <Widget>[];
    List<Widget> fourthDays = <Widget>[];
    List<Widget> fifthDays = <Widget>[];
    ThemeData theme = Theme.of(context);

    for (int i = 0; i < 7; i++) {
      dayHeaders.add(
        new SizedBox(
          width: 40.0,
          height: 20.0,
          child: new Center(
            child: new Text(
              MaterialLocalizations.of(context)
                  .narrowWeekdays[topFirst.weekday % 7],
            ),
          ),
        ),
      );

      // First row.
      firstDays.add(_buildButton(theme, topFirst, nowTime));

      // Second row.
      secondDays.add(_buildButton(theme, topSecond, nowTime));

      // Third row.
      thirdDays.add(_buildButton(theme, topThird, nowTime));

      // Fourth row.
      fourthDays.add(_buildButton(theme, topFourth, nowTime));

      // Fifth row.
      fifthDays.add(_buildButton(theme, topFifth, nowTime));

      topFirst = topFirst.add(oneDay);
      topSecond = topSecond.add(oneDay);
      topThird = topThird.add(oneDay);
      topFourth = topFourth.add(oneDay);
      topFifth = topFifth.add(oneDay);
    }

    return new Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: dayHeaders,
        ),
        new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: firstDays,
        ),
        new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: secondDays,
        ),
        new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: thirdDays,
        ),
        new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: fourthDays,
        ),
        new Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: fifthDays,
        ),
        new SizedBox(height: 10.0),
      ],
    );
  }
}
