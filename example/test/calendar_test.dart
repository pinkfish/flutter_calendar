import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:sliver_calendar/sliver_calendar.dart';
import 'package:timezone/data/latest.dart';
import 'package:timezone/timezone.dart';

void main() {
  testWidgets('uninitialized', (tester) async {
    initializeTimeZones();
    await loadAppFonts();

    String timezone = "America/Los_Angeles";
    Random random = new Random();
    final la = getLocation(timezone);

    final nowTime = TZDateTime(la, 2010, 1, 2, 3, 4, 5, 6, 7);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      await makeTestableWidget(
        RepaintBoundary(
          child: Material(
            child: CalendarWidget(
              initialDate: nowTime,
              beginningRangeDate: nowTime.subtract(Duration(days: 31)),
              endingRangeDate: nowTime.add(Duration(days: 31)),
              location: la,
              buildItem: buildItem,
              getEvents: (s, e) => getEvents(s, e, la, random, nowTime),
              weekBeginsWithDay: 1,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Golden testsd on't seem to work on github...
    if (Platform.environment["GOLDEN"] != null) {
      await expectLater(find.byType(CalendarWidget),
          matchesGoldenFile('golden/calendar.png'));
    }
  });
}

List<CalendarEvent> getEvents(DateTime start, DateTime end, Location loc,
    Random random, TZDateTime nowTime) {
  var events = <CalendarEvent>[];
  for (int i = 0; i < 20; i++) {
    TZDateTime start = nowTime.add(new Duration(days: i));
    events.add(new CalendarEvent(
        index: i,
        instant: start,
        instantEnd: start.add(new Duration(minutes: 30))));
  }

  return events;
}

Widget buildItem(BuildContext context, CalendarEvent e) {
  return new Card(
    child: new ListTile(
      title: new Text("Event ${e.index}"),
      subtitle: new Text("Yay for events"),
      leading: const Icon(Icons.gamepad),
    ),
  );
}

///
/// Makes a happy little testable widget with a wrapper.
///
Future<Widget> makeTestableWidget(Widget child,
    {NavigatorObserver observer}) async {
  initializeTimeZones();

  return MediaQuery(
    data: MediaQueryData(),
    child: MaterialApp(
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      navigatorObservers: observer != null ? [observer] : [],
      color: Colors.green,
      home: child,
    ),
  );
}
