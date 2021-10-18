import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:sliver_calendar/sliver_calendar.dart';
import 'package:timezone/timezone.dart';

void main() async {
  // Comment this line to enable debug printing...
  debugPrint = (String? message, {int? wrapWidth}) {};

  ByteData loadedData = ByteData(0);

  await Future.wait<void>(<Future<void>>[
    rootBundle.load('assets/timezone/2018c.tzf').then((ByteData data) {
      loadedData = data;
      print('loaded data');
    })
  ]);
  initializeDatabase(loadedData.buffer.asUint8List());
  var tz = await FlutterNativeTimezone.getLocalTimezone();
  var loc = getLocation(tz);
  runApp(MyApp(loc));
}

class MyApp extends StatelessWidget {
  final Location loc;

  MyApp(this.loc);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Calendar',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const <
          LocalizationsDelegate<MaterialLocalizations>>[
        GlobalMaterialLocalizations.delegate
      ],
      supportedLocales: const <Locale>[
        Locale('en', ''),
        Locale('fr', ''),
      ],
      home: MyHomePage(title: 'Flutter Calendar demo', loc: loc),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title, required this.loc})
      : super(key: key);
  final String title;
  final Location loc;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<CalendarEvent> events = <CalendarEvent>[];
  Random random = Random();
  TZDateTime nowDate = TZDateTime.utc(2021);

  @override
  void initState() {
    super.initState();
    nowDate = TZDateTime.now(widget.loc);
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
    if (events.isEmpty) {
      TZDateTime nowTime =
          TZDateTime.now(widget.loc).subtract(Duration(days: 5));
      for (int i = 0; i < 20; i++) {
        TZDateTime start = nowTime.add(Duration(days: i + random.nextInt(10)));
        events.add(CalendarEvent(
            index: i,
            instant: start,
            instantEnd: start.add(Duration(minutes: 30))));
      }
    }
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(children: <Widget>[
        Expanded(
          child: CalendarWidget(
            initialDate: nowDate,
            location: widget.loc,
            buildItem: buildItem,
            getEvents: getEvents,
            bannerHeader: AssetImage("assets/images/calendarheader.png"),
            monthHeader: AssetImage("assets/images/calendarbanner.jpg"),
            weekBeginsWithDay:
                1, // Sunday = 0, Monday = 1, Tuesday = 2, ..., Saturday = 6
          ),
        ),
      ]),
    );
  }
}
