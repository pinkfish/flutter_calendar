import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:timezone/timezone.dart';

import 'calendar.dart';
import 'calendarevent.dart';

final Duration _kExpand = Duration(milliseconds: 200);

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
    BuildContext context, DateTime day, CalendarWidgetState? state);

///
/// Generates the small boxes on the calendar to indicate that there are events
/// on this specific day.  It creates a stack and then puts in the main day
/// button inside the stack with the event indicators overlaid on top of it.
/// The calendar events are the events on this day.  It can be an empty array.
///
typedef EventIndicator = Widget Function(
    Widget button, List<CalendarEvent>? events);

///
/// Widget for customizing a specific title to display the desired content
///
typedef Widget CalendarHeaderBuilder(BuildContext context, CalendarWidgetState? state);

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
      Location location,
      this.color,
      this.headerStyle,
      this.expandIconColor,
      this.weekBeginsWithDay,
      this.dayIndicator,
      this.eventIndicator,
      this.beginningRangeDate,
      this.endingRangeDate,
      this.leading,
      this.trailing
      ) : _location = location;

  final Location _location;
  final CalendarWidgetState state;
  final Color? color;
  final TextStyle? headerStyle;
  final Color? expandIconColor;
  final int weekBeginsWithDay;
  final EventIndicator? eventIndicator;
  final HeaderDayIndicator? dayIndicator;
  final TZDateTime beginningRangeDate;
  final TZDateTime endingRangeDate;
  final Widget? leading;
  final CalendarHeaderBuilder? trailing;

  @override
  State createState() {
    return _CalendarHeaderState();
  }
}

///
/// The calendar state associated with the header.
///
class _CalendarHeaderState extends State<CalendarHeader>
    with SingleTickerProviderStateMixin {
  _CalendarHeaderState() {
    _monthIndex = monthIndexFromTime(clock.now());
    _easeInAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_easeInAnimation);
  }

  double get maxExtent => 55.0;

  late StreamSubscription<bool> _headerExpandedSubscription;
  late StreamSubscription<int> _indexChangeSubscription;
  //SharedCalendarState sharedState;
  late AnimationController _controller =
      AnimationController(duration: _kExpand, vsync: this);
  late CurvedAnimation _easeInAnimation;
  late Animation<double> _iconTurns;
  late int _monthIndex;
  bool myExpandedState = false;
  bool _monthState = false;
  int? _beginningMonthIndex;
  int? _endingMonthIndex;

  int monthIndexFromTime(DateTime time) {
    return (time.year - 1970) * 12 + (time.month - 1);
  }

  DateTime monthToShow(int index) {
    return DateTime(index ~/ 12 + 1970, index % 12 + 1, 1);
  }

  @override
  void initState() {
    super.initState();
    _beginningMonthIndex = monthIndexFromTime(widget.beginningRangeDate);
    _endingMonthIndex = monthIndexFromTime(widget.endingRangeDate);
    _indexChangeSubscription =
        widget.state.indexChangeStream.listen((int newTop) {
      if (!_monthState) {
        setState(() {
          _monthIndex = monthIndexFromTime(getTopDisplayDate());
        });
      }
    });
    _headerExpandedSubscription =
        widget.state.headerExpandedChangeStream!.listen((bool change) {
      if (myExpandedState != change) {
        // setState(() {
          myExpandedState = change;
          _doAnimation();
        // });
      }
    });
  }

  DateTime getTopDisplayDate() {
    int ms = (widget.state.currentTopDisplayIndex + 1) *
                Duration.millisecondsPerDay;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
    
  void _doAnimation() {
    if (myExpandedState) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
    _headerExpandedSubscription.cancel();
    _indexChangeSubscription.cancel();
  }

  void _handleOpen() {
    // setState(() {
      // Jump the page controller to the right spot.
      myExpandedState = !widget.state.headerExpanded;
      widget.state.headerExpanded = myExpandedState;
      _doAnimation();
      PageStorage.of(context)
          ?.writeState(context, widget.state..headerExpanded);
    // });
  }

  Widget _buildChildren(BuildContext context, Widget? child) {
    DismissDirection direction = DismissDirection.horizontal;
    if (_beginningMonthIndex == _monthIndex) {
      direction = DismissDirection.endToStart;
    } else if (_endingMonthIndex == _monthIndex) {
      direction = DismissDirection.startToEnd;
    }

    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildCurrentHeader(context),
          ClipRect(
            child: Align(
              heightFactor: _easeInAnimation.value,
              child: Container(
                constraints: BoxConstraints(minHeight: 230.0, maxHeight: 270.0),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                    color: Colors.grey.shade400, width: 1.5))
                ),
                child: Dismissible(
                  key: ValueKey<int?>(_monthIndex),
                  resizeDuration: null,
                  dismissThresholds: const <DismissDirection, double>{
                    DismissDirection.horizontal: 0.2
                  },
                  direction: direction,
                  onDismissed: (DismissDirection direction) => setState(() {
                      _monthIndex +=
                          direction == DismissDirection.endToStart ? 1 : -1;
                      // Update the current scroll pos too.
                      _monthState = true;
                      widget.state.scrollToDay(monthToShow(_monthIndex));
                      Future.delayed(const Duration(milliseconds: 1500), () {
                        _monthState = false;
                      });
                  }),
                  child: _CalendarMonthDisplay(
                      sharedState: widget.state,
                      location: widget._location,
                      displayDate: monthToShow(_monthIndex),
                      weekBeginsWithDay: widget.weekBeginsWithDay,
                      dayIndicator: widget.dayIndicator,
                      eventIndicator: widget.eventIndicator),

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
    return Material(
      elevation: 0.0,
      color: widget.color ?? Colors.white,
      child: AnimatedBuilder(
        animation: _controller,
        builder: _buildChildren,
        child: _buildCurrentHeader(context),
      ),
    );
  }

  Widget _buildCurrentHeader(BuildContext context) {
    DateTime currentTopTemp = getTopDisplayDate();
    DateTime currentTop =
        DateTime(currentTopTemp.year, currentTopTemp.month, currentTopTemp.day);

    return Container(
      padding: EdgeInsets.only(left: 5.0),
      decoration: BoxDecoration(
        color: widget.color ?? Colors.white
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(0),
        leading: widget.leading ?? null,
        title: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            GestureDetector(
              onTap: _handleOpen,
              onDoubleTap: null,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  Text(
                    (myExpandedState
                            ? MaterialLocalizations.of(context)
                                .formatMonthYear(monthToShow(_monthIndex))
                            : MaterialLocalizations.of(context)
                                .formatMonthYear(currentTop)) +
                        ' ',
                    style: widget.headerStyle ??
                        Theme.of(context)
                            .textTheme
                            .headline6!
                            .copyWith(fontSize: 25.0),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: Icon(
                      Icons.expand_more,
                      color: widget.expandIconColor ?? Colors.black,
                      size: 25.0,
                    ),
                  ),
                ]
              )
            ),
            widget.trailing != null ?
            widget.trailing!(context, widget.state) : Container()
          ]
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
    canvas.drawCircle(
        Offset(_radius, _radius), _radius, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_CalendarEventIndicator other) =>
      other._radius != _radius || other._event != _event;
}

///
/// The animated container to show for the month with all the days and the
/// day headers.
///
class _CalendarMonthDisplay extends StatefulWidget {
  final CalendarWidgetState sharedState;
  final Location location;
  final int weekBeginsWithDay;
  final HeaderDayIndicator? dayIndicator;
  final EventIndicator? eventIndicator;
  final DateTime displayDate;
  final Duration week = Duration(days: 7);

  _CalendarMonthDisplay(
      {Key? key,
      required this.sharedState,
      required this.location,
      required this.weekBeginsWithDay,
      this.dayIndicator,
      this.eventIndicator,
      required this.displayDate})
      : super(key: key);

  @override
  _CalendarMonthDisplayState createState() => _CalendarMonthDisplayState();
}

class _CalendarMonthDisplayState extends State<_CalendarMonthDisplay> {
  DateTime selectedDay = clock.now();

  Widget _eventIndicator(Widget button, int eventIndex) {
    if (widget.sharedState.events.containsKey(eventIndex)) {
      if (widget.eventIndicator != null) {
        return widget.eventIndicator!(
          button, widget.sharedState.events[eventIndex]);
      }
      List<Widget> eventIndicators = <Widget>[];
      for (CalendarEvent event in widget.sharedState.events[eventIndex]!) {
        if (widget.displayDate.month == event.instant.month) {
          eventIndicators.add(
            SizedBox(
              height: 4.0,
              width: 4.0,
              child: CustomPaint(
                painter: _CalendarEventIndicator(2.0, event),
              ),
            ),
          );
          eventIndicators.add(
            SizedBox(
              width: 2.0,
            ),
          );
        }
      }
      return SizedBox(
        width: 40.0,
        height: 40.0,
        child: Stack(
          children: <Widget>[
            button,
            Container(
              alignment: Alignment(1.0, 1.0),
              child: Row(
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
      if (widget.eventIndicator != null) {
        return widget.eventIndicator!(button, <CalendarEvent>[]);
      }
      return SizedBox(
        width: 40.0,
        height: 40.0,
        child: button,
      );
    }
  }

  Widget _buildButton(ThemeData theme, DateTime day, DateTime nowTime) {
    Widget button;
    // Only show days in the current month.
    if (day.month != widget.displayDate.month) {
      button = SizedBox(width: 1.0);
    } else {
      if (widget.dayIndicator != null) {
        button = widget.dayIndicator!(context, day, widget.sharedState);
      } else {
        button = Center(
          child: TextButton(
            style: TextButton.styleFrom(
              primary: Colors.black54,
              backgroundColor: day.isAtSameMomentAs(nowTime)
                  ? theme.accentColor
                  : day.isAtSameMomentAs(selectedDay)
                      ? Colors.grey.shade200
                      : null,
              shape: CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: Text(day.day.toString()),
            onPressed: () => setState(() {
              selectedDay = day;
              widget.sharedState.scrollToDay(day);
            }),
          ),
        );
      }
    }
    int eventIndex = CalendarEvent.indexFromMilliseconds(day, widget.location);
    return _eventIndicator(button, eventIndex);
  }

  @override
  Widget build(BuildContext context) {
    DateTime nowTmp = clock.now();
    DateTime nowTime = DateTime(nowTmp.year, nowTmp.month, nowTmp.day);
    DateTime topFirst = widget.displayDate;
    topFirst =
        topFirst.subtract(Duration(days: topFirst.weekday - widget.weekBeginsWithDay));
    DateTime topSecond = topFirst.add(widget.week);
    if (topSecond.day == 1) {
      // Opps, out by a week.
      topFirst = topSecond;
      topSecond = topFirst.add(widget.week);
    }
    DateTime topThird = topSecond.add(widget.week);
    DateTime topFourth = topThird.add(widget.week);
    DateTime topFifth = topFourth.add(widget.week);
    // Check if the sixth row is displayed or not.
    int lastday = DateTime(topFifth.year, topFifth.month + 1, 0).day;
    DateTime topSixth = topFifth;
    bool isShowSixthRow = false;
    if ((topFifth.day + 7) <= lastday) {
      isShowSixthRow = true;
      topSixth = topFifth.add(widget.week);
    }
    List<Widget> dayHeaders = <Widget>[];
    List<Widget> firstDays = <Widget>[];
    List<Widget> secondDays = <Widget>[];
    List<Widget> thirdDays = <Widget>[];
    List<Widget> fourthDays = <Widget>[];
    List<Widget> fifthDays = <Widget>[];
    List<Widget> sixthDays = <Widget>[];
    ThemeData theme = Theme.of(context);

    for (int i = 0; i < 7; i++) {
      dayHeaders.add(
        SizedBox(
          width: 40.0,
          height: 20.0,
          child: Center(
            child: Text(
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
        
      // Join the sixth row if exist.
      if (isShowSixthRow) {
        sixthDays.add(_buildButton(theme, topSixth, nowTime));
        topSixth = topSixth.add(oneDay);
      }

      topFirst = topFirst.add(oneDay);
      topSecond = topSecond.add(oneDay);
      topThird = topThird.add(oneDay);
      topFourth = topFourth.add(oneDay);
      topFifth = topFifth.add(oneDay);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: dayHeaders,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: firstDays,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: secondDays,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: thirdDays,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: fourthDays,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: fifthDays,
        ),
        sixthDays.length > 0 ? 
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: sixthDays,
          ) : Container(),
        SizedBox(height: 10.0),
      ],
    );
  }
}
