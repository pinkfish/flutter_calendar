import 'dart:math';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:sliver_calendar/sliver_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
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
      ],
      home: MyHomePage(title: 'Flutter Calendar demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<CalendarEvent> events = <CalendarEvent>[];
  Random random = Random();
  DateTime _now = DateTime.now();
  DateTime selectedDate;
  DateTime nowDate;
  tz.Location loc;

  @override
  void initState() {
    super.initState();
    selectedDate = _now;
    nowDate = DateTime(_now.year, _now.month, _now.day);
  }

  Widget trailingWidget(BuildContext ctx, CalendarWidgetState state) {
    return IconButton(
        icon: Icon(Icons.today_outlined),
        onPressed: () {
          state.scrollToDay(nowDate);
        });
  }

  Widget dayIndicatorWidget(BuildContext c, DateTime d, CalendarWidgetState s) {
    return GestureDetector(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: d.isAtSameMomentAs(nowDate)
                ? Colors.lime
                : d.isAtSameMomentAs(selectedDate)
                    ? Colors.grey.shade200
                    : null,
            shape: BoxShape.circle),
        child: Text(
          d.day.toString(),
          style: TextStyle(color: Colors.black54),
        ),
      ),
      onDoubleTap: () {
        print("Double click");
      },
      onTap: () => setState(() {
        selectedDate = d;
        s.scrollToDay(d);
      }),
    );
  }

  Widget buildItem(BuildContext ctx, CalendarEvent e) {
    return Card(
      shape: Border(left: BorderSide(color: Colors.blue, width: 3)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          child: ListTile(
            title: Text("Event：${e.index}"),
            subtitle: Text("have fun..."),
            leading: const Icon(Icons.grass),
          ),
          onTap: () {
            print([e.index, e.instant.month, e.instant.day]);
            // s.s
          },
        ),
      ),
    );
  }

  List<CalendarEvent> getEvents(DateTime start, DateTime end) {
    if (loc != null && events.isEmpty) {
      tz.TZDateTime nowTime =
          tz.TZDateTime.now(loc).subtract(Duration(days: 5));
      for (int i = 0; i < 20; i++) {
        tz.TZDateTime start =
            nowTime.add(Duration(days: i + random.nextInt(10)));
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
      body: SafeArea(
        child: Column(
          children: <Widget>[
            FutureBuilder<String>(
              future: FlutterNativeTimezone.getLocalTimezone(),
              builder: (BuildContext context, AsyncSnapshot<String> tzone) {
                if (tzone.hasData) {
                  loc = tz.getLocation(tzone.data);
                  tz.TZDateTime nowTime = tz.TZDateTime.now(loc);
                  return Expanded(
                    child: CalendarWidget(
                      initialDate: nowTime,
                      location: loc,
                      buildItem: buildItem,
                      getEvents: getEvents,
                      tapToCloseHeader: false,
                      dayIndicator: dayIndicatorWidget,
                      leading: IconButton(
                          icon: Icon(Icons.menu),
                          onPressed: () {
                            print("Clicked menu");
                          }),
                      trailing: trailingWidget,
                      headerColor: Colors.lightBlue,
                      headerMonthStyle:
                          TextStyle(color: Colors.black87, fontSize: 18.0),
                      monthHeader:
                          AssetImage("assets/images/calendarbanner.jpg"),
                      weekBeginsWithDay:
                          0, // Sunday = 0, Monday = 1, Tuesday = 2, ..., Saturday = 6
                    ),
                  );
                } else {
                  return Center(
                    child: Text("Getting the timezone..."),
                  );
                }
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        child: Icon(Icons.add),
        onPressed: () {
          print("hahaha");
        },
      ),
    );
  }
}
