import 'package:flutter/material.dart';
import 'package:sliver_calendar/sliver_calendar.dart';
import 'package:timezone/timezone.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'dart:math';
import 'dart:typed_data';
import 'dart:async';

void main() async {
  ByteData loadedData;

  await Future.wait([
    rootBundle.load('assets/timezone/2018c.tzf').then((ByteData data) {
      loadedData = data;
      print('loaded data');
    })
  ]);
  initializeDatabase(loadedData.buffer.asUint8List());
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
  int _counter = 0;
  CalendarSource source;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
      ),
      body: new Column(
        children: <Widget>[
          new FutureBuilder(
            future: FlutterNativeTimezone.getLocalTimezone(),
            builder: (BuildContext context, AsyncSnapshot<String> tz) {
              if (tz.hasData) {
                Location loc = getLocation(tz.data);
                if (source == null) {
                  source = new CalendarEventSource(loc);
                }
                return new Expanded(
                  child: new CalendarWidget(
                    initialDate: new TZDateTime.now(loc),
                    location: loc,
                    source: source,
                  ),
                );
              } else {
                return new Center(
                  child: new Text("Getting the timezone"),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class CalendarEventSource extends CalendarSource {
  List<CalendarEvent> events = [];
  final Location loc;
  Random random = new Random();

  CalendarEventSource(this.loc);

  @override
  List<CalendarEvent> getEvents(DateTime start, DateTime end) {
    return events;
  }

  @override
  void dispose() {}

  @override
  void initState() {
    TZDateTime nowTime =
        new TZDateTime.now(loc).subtract(new Duration(days: 5));
    for (int i = 0; i < 20; i++) {
      TZDateTime start =
          nowTime.add(new Duration(days: i + random.nextInt(10)));
      events.add(new CalendarEvent(
          index: i,
          instant: start,
          instantEnd: start.add(new Duration(minutes: 30))));
    }
  }

  @override
  Widget buildWidget(BuildContext context, CalendarEvent index) {
    return new ListTile(
      title: new Text("Event ${index.index}"),
      subtitle: new Text("Yay for events"),
      leading: const Icon(Icons.gamepad),
    );
  }
}
