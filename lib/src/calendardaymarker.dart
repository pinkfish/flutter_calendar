import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

/// A one device pixel thick horizontal line, with a circle at the start
/// designed to look like the time of day lines in calendar.
///
class CalendarDayMarker extends StatelessWidget {
  /// The height must be positive.
  const CalendarDayMarker(
      {Key key,
      this.height: 16.0,
      this.radius: 5.0,
      this.indent: 0.0,
      this.color})
      : assert(height >= 0.0),
        super(key: key);

  /// The vertical extent.
  final double height;

  /// The amount of empty space to the left of the divider.
  final double indent;

  /// Radius of the dot at the start of the line.
  final double radius;

  /// The color to use when painting the line.
  ///
  /// Defaults to the current theme's divider color, given by
  /// [ThemeData.dividerColor].
  ///
  /// ## Sample code
  ///
  /// ```dart
  /// new Divider(
  ///   color: Colors.deepOrange,
  /// )
  /// ```
  final Color color;

  static BorderSide createBorderSide(BuildContext context,
      {Color color, double width: 0.0}) {
    assert(width != null);
    return new BorderSide(
      color: color ?? Theme.of(context).dividerColor,
      width: width,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new CustomPaint(
      painter: new _CalendarDayMarkerPainter(
          radius, new Offset(indent + radius / 2, height / 2), color),
      child: new SizedBox(
        height: height,
        child: new Center(
          child: new Container(
            height: 0.0,
            margin: new EdgeInsetsDirectional.only(start: indent),
            decoration: new ShapeDecoration(
              shape: new Border(
                bottom: new BorderSide(
                  color: color ?? Theme.of(context).dividerColor,
                  width: 0.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDayMarkerPainter extends CustomPainter {
  _CalendarDayMarkerPainter(this._radius, this._offset, this._color);
  
  final double _radius;
  final Offset _offset;
  final Color _color;

  @override
  void paint(Canvas canvas, Size size) {
    if (_radius == null) {
      return;
    }
    canvas.drawCircle(_offset, _radius, new Paint()..color = _color);
  }

  @override
  bool shouldRepaint(_CalendarDayMarkerPainter other) =>
      other._radius != _radius ||
      other._offset != _offset ||
      other._color != _color;
}
