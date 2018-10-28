import 'package:flutter/material.dart';
import 'package:date_interval_navigator/date_interval_navigator.dart';

import 'dart:math';

void main() {
  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Calendar',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new MyHomePage(title: 'Flutter Calendar demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<CalendarEvent> events = <CalendarEvent>[];

  Random random = new Random();

  @override
  void initState() {
    super.initState();
  }

  Widget buildItem(BuildContext context, CalendarEvent e) {
    return Card(
      child: ListTile(
        title: Text("Event ${e.index}"),
        subtitle: Text("Yay for events"),
        leading: const Icon(Icons.gamepad),
      ),
    );
  }

  List<CalendarEvent> getEvents(DateTime start, DateTime end) {
    DateTime nowTime = DateTime.now().subtract(Duration(days: 5));
    for (int i = 0; i < 20; i++) {
      DateTime start = nowTime.add(Duration(days: i + random.nextInt(10)));
      events.add(CalendarEvent(
          index: i,
          instant: start,
          instantEnd: start.add(Duration(minutes: 30))));
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: CalendarWidget(
        initialDate: DateTime.now(),
        buildItem: buildItem,
        getEvents: getEvents,
        bannerHeader: AssetImage("assets/images/calendarheader.png"),
        monthHeader: AssetImage("assets/images/calendarbanner.jpg"),
      ),
    );
  }
}
