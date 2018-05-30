# Calendar

Shows a scrolling calendar list of events.  This is still relatively basic, it always
assumes that the getEvents returns the entire list of calendar events (mostly ignoring
the values passed into the source).  It does work however :)  Right now it also assumes
there is an asset at assets/images/calendarheader.png which it will use to display the header
and an asset at assets/images/calendarbanner.jpg which it will use for the month header.


The calendar uses slivers to display the widgets in the view and lets you scroll forward
and backward through the events.  The header widget will drop down and open up the days of
the month, letting you select specific days as well as move back and forth between the months.
By default it displays a list of events and not a day view, the day view code is all just a
stub right now.

Here is how to use the calendar widget itself:

```
new CalendarWidget(
              initialDate: new TZDateTime.now(local),
              source: _calendarState,
            );
```

How to setup a source for the calendar widget.
```
class GameListCalendarState extends CalendarSource {
  List<Game> _listToShow;
  StreamSubscription<UpdateReason> _listening;

  @override
  Widget buildWidget(BuildContext context, CalendarEvent event) {
    return new GameCard(_listToShow[event.index]);
  }

  @override
  List<CalendarEvent> getEvents(DateTime start, DateTime end) {
    if (_listToShow == null) {
      _listToShow = UserDatabaseData.instance.games.values.toList();
    }
    if (_listToShow == null) {
      return [];
    }
    List<CalendarEvent> events = new List<CalendarEvent>();
    int pos = 0;
    _listToShow.forEach((Game g) => events.add(new CalendarEvent(
        instant: g.tzTime, instantEnd: g.tzEndTime, index: pos++)));
    return events;
  }

  @override
  void initState() {
    _listToShow = UserDatabaseData.instance.games.values.toList();
    _listening = UserDatabaseData.instance.gameStream.listen((UpdateReason r) {
      _listToShow = UserDatabaseData.instance.games.values.toList();
      state.updateEvents();
    });
  }

  @override
  void dispose() {
    _listening.cancel();
  }

  Future<void> loadGames(FilterDetails details) async {
    Iterable<Game> list = await UserDatabaseData.instance.getGames(details);

    _setGames(list);
  }

  void _setGames(Iterable<Game> res) {
    List<Game> games = res.toList();
    games.sort((a, b) => a.time.compareTo(b.time));

    _listToShow = games;
  }
}
```

Example of the calendar widget in action:
<img src="https://github.com/pinkfish/flutter_calendar/blob/master/screenshots/screenshot.png?raw=true">
<img src="https://github.com/pinkfish/flutter_calendar/blob/master/screenshots/screenrecording.gif?raw=true">

## Getting Started

For help getting started with Flutter, view our online [documentation](https://flutter.io/).

For help on editing package code, view the [documentation](https://flutter.io/developing-packages/).
