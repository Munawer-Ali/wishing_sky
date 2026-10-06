import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'look.dart';
import 'sky_data.dart';

class SkyView extends StatefulWidget {
  const SkyView({
    super.key,
    required this.brightStars,
    required this.explodingStars,
    required this.names,
    required this.onStarTap,
  });

  final List<BrightStar> brightStars;
  final List<ExplodingStar> explodingStars;
  final Map<String, String> names;
  final ValueChanged<ExplodingStar> onStarTap;

  @override
  State<SkyView> createState() => SkyViewState();
}

class SkyViewState extends State<SkyView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _clock = ValueNotifier<double>(0);

  double _ra = 80;
  double _dec = 10;
  double _fov = 90;
  double _fovAtPinchStart = 90;

  double? _flyStart;
  late double _flyFromRa, _flyFromDec, _flyToRa, _flyToDec;

  final _explosions = <String, double>{};
  final _wishFlights = <String, double>{};

  StreamSubscription<GyroscopeEvent>? _gyro;
  Offset _turnSpeed = Offset.zero;
  Size _size = Size.zero;
  double _lastRa = 80;
  double _lastDec = 10;
  Offset _lift = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final time = elapsed.inMicroseconds / 1e6;
      final dt = (time - _clock.value).clamp(0.0, 0.05);
      _followPhone(dt);
      _updateFlight();
      _updateLift(dt);
      _clock.value = time;
    })..start();
    _gyro = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) => _turnSpeed = Offset(e.y, e.x), onError: (_) {}, cancelOnError: true);
  }

  @override
  void dispose() {
    _gyro?.cancel();
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  void _followPhone(double dt) {
    if (_flyStart != null) return;
    final turn = _turnSpeed;
    if (turn.distance < 0.03) return;
    _ra += turn.dx * dt * 180 / pi / max(cos(_dec * pi / 180), 0.3);
    _dec = (_dec + turn.dy * dt * 180 / pi).clamp(-85.0, 85.0);
  }

  void _updateLift(double dt) {
    if (dt == 0 || _size.isEmpty) return;
    final pixelsPerDegree = _size.shortestSide / _fov;
    var dRa = _ra - _lastRa;
    if (dRa > 180) dRa -= 360;
    if (dRa < -180) dRa += 360;
    final moved = Offset(dRa * cos(_dec * pi / 180), _dec - _lastDec) * pixelsPerDegree;
    _lastRa = _ra;
    _lastDec = _dec;
    final target = moved / dt * 0.03;
    final clamped = target.distance > 14 ? target / target.distance * 14 : target;
    _lift = Offset.lerp(_lift, clamped, 0.12)!;
  }

  double get _now => _clock.value;

  void lookAt(ExplodingStar star, {bool instant = false}) {
    if (instant) {
      _ra = _lastRa = star.ra;
      _dec = _lastDec = star.dec;
      return;
    }
    _flyFromRa = _ra;
    _flyFromDec = _dec;
    var target = star.ra;
    while (target - _ra > 180) {
      target -= 360;
    }
    while (target - _ra < -180) {
      target += 360;
    }
    _flyToRa = target;
    _flyToDec = star.dec;
    _flyStart = _now;
  }

  void explode(ExplodingStar star, {double delay = 0}) {
    _explosions[star.id] = _now + delay;
  }

  void sendWish(ExplodingStar star) {
    _wishFlights[star.id] = _now;
  }

  void _updateFlight() {
    final start = _flyStart;
    if (start == null) return;
    final t = ((_now - start) / 1.4).clamp(0.0, 1.0);
    final eased = Curves.easeInOutCubic.transform(t);
    _ra = _flyFromRa + (_flyToRa - _flyFromRa) * eased;
    _dec = _flyFromDec + (_flyToDec - _flyFromDec) * eased;
    if (t >= 1) _flyStart = null;
  }

  void _onTap(TapUpDetails details, Size size) {
    final sky = _SkyProjection(_ra, _dec, _fov, size);
    ExplodingStar? closest;
    var closestDistance = 36.0;
    for (final star in widget.explodingStars) {
      final point = sky.project(star.ra, star.dec);
      if (point == null) continue;
      final d = (point + _lift * 1.4 - details.localPosition).distance;
      if (d < closestDistance) {
        closestDistance = d;
        closest = star;
      }
    }
    if (closest != null) widget.onStarTap(closest);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        _size = size;
        return GestureDetector(
          onTapUp: (d) => _onTap(d, size),
          onScaleStart: (_) {
            _flyStart = null;
            _fovAtPinchStart = _fov;
          },
          onScaleUpdate: (d) {
            final degreesPerPixel = _fov / size.shortestSide;
            _ra += d.focalPointDelta.dx * degreesPerPixel / max(cos(_dec * pi / 180), 0.3);
            _dec = (_dec + d.focalPointDelta.dy * degreesPerPixel).clamp(-85.0, 85.0);
            if (d.scale != 1) _fov = (_fovAtPinchStart / d.scale).clamp(25.0, 140.0);
          },
          child: CustomPaint(size: size, painter: _SkyPainter(this)),
        );
      },
    );
  }
}

class _SkyProjection {
  _SkyProjection(double ra, double dec, double fov, this.size) {
    final r = ra * pi / 180;
    final d = dec * pi / 180;
    fx = cos(d) * cos(r);
    fy = cos(d) * sin(r);
    fz = sin(d);
    ux = -sin(d) * cos(r);
    uy = -sin(d) * sin(r);
    uz = cos(d);
    rx = sin(r);
    ry = -cos(r);
    scale = size.shortestSide / 2 / (2 * tan(fov * pi / 180 / 4));
    center = size.center(Offset.zero);
  }

  final Size size;
  late final double fx, fy, fz, ux, uy, uz, rx, ry;
  late final double scale;
  late final Offset center;

  Offset? projectVector(double x, double y, double z) {
    final cz = x * fx + y * fy + z * fz;
    if (cz < -0.2) return null;
    final cx = x * rx + y * ry;
    final cy = x * ux + y * uy + z * uz;
    final k = 2 / (1 + cz);
    final point = center + Offset(k * cx, -k * cy) * scale;
    if (point.dx < -60 || point.dy < -60 || point.dx > size.width + 60 || point.dy > size.height + 60) {
      return null;
    }
    return point;
  }

  Offset? project(double ra, double dec) {
    final r = ra * pi / 180;
    final d = dec * pi / 180;
    return projectVector(cos(d) * cos(r), cos(d) * sin(r), sin(d));
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.view) : super(repaint: view._clock);

  final SkyViewState view;

  @override
  void paint(Canvas canvas, Size size) {
    final time = view._now;
    final sky = _SkyProjection(view._ra, view._dec, view._fov, size);
    final zoom = (90 / view._fov).clamp(0.8, 2.2);
    final lift = view._lift;

    _drawCeiling(canvas, size);
    _drawStars(canvas, sky, time, zoom, lift);

    for (final star in view.widget.explodingStars) {
      final point = sky.project(star.ra, star.dec);
      if (point == null) continue;
      _drawStickerStar(canvas, point + lift * 1.4, star, time);
      final name = view.widget.names[star.id];
      if (name != null) _drawName(canvas, point + lift * 1.4, name, star.isNew);
    }

    for (final entry in view._explosions.entries.toList()) {
      final t = (time - entry.value) / 2.4;
      if (t > 1) {
        view._explosions.remove(entry.key);
        continue;
      }
      if (t < 0) continue;
      final point = _pointOf(sky, entry.key);
      if (point != null) _drawExplosion(canvas, point + lift * 1.4, t);
    }

    for (final entry in view._wishFlights.entries.toList()) {
      final t = (time - entry.value) / 2.0;
      if (t > 1) {
        view._wishFlights.remove(entry.key);
        continue;
      }
      final point = _pointOf(sky, entry.key);
      if (point != null) _drawPaperPlane(canvas, size, point + lift * 1.4, t);
    }
  }

  Offset? _pointOf(_SkyProjection sky, String id) {
    final star = view.widget.explodingStars.where((s) => s.id == id).firstOrNull;
    return star == null ? null : sky.project(star.ra, star.dec);
  }

  void _drawCeiling(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), const [ceilingTop, ceilingBottom]),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(Offset(size.width * 0.1, size.height * 1.05), size.height * 0.6, [
          nightLight.withValues(alpha: 0.16),
          nightLight.withValues(alpha: 0),
        ]),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(size.center(Offset.zero), size.longestSide * 0.75, [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.35),
        ]),
    );
  }

  void _drawStars(Canvas canvas, _SkyProjection sky, double time, double zoom, Offset lift) {
    final dot = Paint();
    final glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    final stars = view.widget.brightStars;

    for (var i = 0; i < stars.length; i++) {
      final star = stars[i];
      final point = sky.projectVector(star.x, star.y, star.z);
      if (point == null) continue;
      final brightness = ((5.2 - star.magnitude) / 6.7).clamp(0.0, 1.0);
      final twinkle = _twinkle(time, i);

      if (star.magnitude < 3.2) {
        final radius = (1.6 + 3.2 * brightness) * zoom;
        final at = point + lift;
        canvas.drawCircle(point + lift * 0.4 + Offset(1, 1.6) * zoom, radius, shadow);
        glow.color = glowGreen.withValues(alpha: 0.35 * twinkle);
        canvas.drawCircle(at, radius * 2.4, glow);
        dot.color = glowGreen.withValues(alpha: 0.95 * twinkle);
        canvas.drawCircle(at, radius, dot);
      } else {
        dot.color = glowGreen.withValues(alpha: (0.25 + 0.45 * brightness) * twinkle);
        canvas.drawCircle(point, (0.7 + 1.6 * brightness) * zoom, dot);
      }
    }
  }

  double _twinkle(double time, int seed) {
    return 0.82 + 0.1 * sin(time * 3.1 + seed * 1.7) + 0.08 * sin(time * 7.3 + seed * 0.9);
  }

  double _lightCurve(double days) {
    if (days < 18) return 0.35 + 0.65 * pow(days / 18, 0.6);
    return exp(-(days - 18) / 35);
  }

  Color _colorAt(double days) {
    const ages = [0.0, 6.0, 18.0, 40.0, 90.0];
    const colors = [Color(0xFFBFD8FF), Color(0xFFF2F4FF), Color(0xFFFFF0B8), Color(0xFFFFB46B), Color(0xFFFF7A5C)];
    if (days >= ages.last) return colors.last;
    for (var i = 1; i < ages.length; i++) {
      if (days <= ages[i]) {
        return Color.lerp(colors[i - 1], colors[i], (days - ages[i - 1]) / (ages[i] - ages[i - 1]))!;
      }
    }
    return colors.last;
  }

  void _drawStickerStar(Canvas canvas, Offset point, ExplodingStar star, double time) {
    final days = star.age.inMinutes / 1440;
    final light = _lightCurve(days) * _twinkle(time, star.id.hashCode);
    final color = _colorAt(days);
    final radius = 2 + 3.5 * light;

    canvas.drawCircle(
      point,
      radius * 3 + days * 1.5,
      Paint()
        ..shader = ui.Gradient.radial(point, radius * 3 + days * 1.5, [
          color.withValues(alpha: 0.25 * light),
          color.withValues(alpha: 0),
        ]),
    );
    canvas.drawCircle(
      point + const Offset(1.5, 2.5),
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      point,
      radius * 1.8,
      Paint()
        ..color = color.withValues(alpha: 0.45 * light)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(point, radius, Paint()..color = Color.lerp(color, Colors.white, 0.5)!);

    if (star.isNew) {
      _drawCrayonCircle(canvas, point, 22 + 1.5 * sin(time * 2), star.id.hashCode);
      _drawLabel(canvas, point + const Offset(20, -30));
    }
  }

  void _drawCrayonCircle(Canvas canvas, Offset center, double radius, int seed) {
    final random = Random(seed);
    final wobble = random.nextDouble() * 6;
    final path = Path();
    for (var i = 0; i <= 48; i++) {
      final a = -0.4 + i / 48 * (2 * pi + 0.5);
      final r = radius + sin(a * 3 + wobble) * 1.6 + i * 0.06;
      final p = center + Offset(cos(a) * r, sin(a) * r * 0.92);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = crayonPink.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawName(Canvas canvas, Offset star, String name, bool circled) {
    final text = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontFamily: 'PatrickHand',
          color: paper,
          fontSize: 17,
          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 160);
    final top = star.dy - (circled ? 30 : 14) - text.height;
    text.paint(canvas, Offset(star.dx - text.width / 2, top));
  }

  void _drawLabel(Canvas canvas, Offset at) {
    final text = TextPainter(
      text: const TextSpan(
        text: 'boom!',
        style: TextStyle(fontFamily: 'PatrickHand', color: crayonPink, fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-0.2);
    text.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _drawExplosion(Canvas canvas, Offset point, double t) {
    final flash = t < 0.12 ? t / 0.12 : pow(1 - (t - 0.12) / 0.88, 2).toDouble();
    final out = Curves.easeOutCubic.transform(t);
    const blueWhite = Color(0xFFE6F0FF);

    canvas.drawCircle(
      point,
      8 + 55 * flash,
      Paint()
        ..color = blueWhite.withValues(alpha: 0.85 * flash)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );
    canvas.drawCircle(
      point,
      10 + 140 * out,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - t)
        ..color = const Color(0xFFBFD8FF).withValues(alpha: 0.7 * (1 - t)),
    );
    final spike = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.7 * flash);
    final length = 70 * flash;
    canvas.drawLine(point - Offset(length, 0), point + Offset(length, 0), spike);
    canvas.drawLine(point - Offset(0, length), point + Offset(0, length), spike);
    canvas.drawCircle(point, 3 + 6 * flash, Paint()..color = Colors.white.withValues(alpha: flash));
  }

  void _drawPaperPlane(Canvas canvas, Size size, Offset target, double t) {
    final start = Offset(size.width * 0.15, size.height + 30);
    final control = Offset(size.width * 0.9, (start.dy + target.dy) / 2);
    Offset at(double s) => start * ((1 - s) * (1 - s)) + control * (2 * (1 - s) * s) + target * (s * s);

    final travel = Curves.easeInOutSine.transform((t / 0.75).clamp(0.0, 1.0));
    if (t < 0.75) {
      final trail = Paint()..color = paper.withValues(alpha: 0.6);
      for (var s = 0.0; s < travel - 0.03; s += 0.035) {
        canvas.drawCircle(at(s), 1.4, trail);
      }
      final here = at(travel);
      final ahead = at(min(travel + 0.01, 1));
      final heading = atan2(ahead.dy - here.dy, ahead.dx - here.dx);
      canvas.save();
      canvas.translate(here.dx, here.dy);
      canvas.rotate(heading);
      final wing = Path()
        ..moveTo(14, 0)
        ..lineTo(-12, -9)
        ..lineTo(-6, 0)
        ..close();
      final body = Path()
        ..moveTo(14, 0)
        ..lineTo(-12, 8)
        ..lineTo(-6, 0)
        ..close();
      canvas.drawPath(wing, Paint()..color = paper);
      canvas.drawPath(body, Paint()..color = const Color(0xFFE8DCC0));
      canvas.restore();
    } else {
      final s = (t - 0.75) / 0.25;
      final sparkle = Paint()..color = stickerYellow.withValues(alpha: 1 - s);
      for (var i = 0; i < 8; i++) {
        final a = i / 8 * 2 * pi;
        canvas.drawCircle(target + Offset(cos(a), sin(a)) * (10 + 26 * s), 3 * (1 - s) + 1, sparkle);
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => true;
}
