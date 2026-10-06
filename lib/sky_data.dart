import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class BrightStar {
  BrightStar(this.ra, this.dec, this.magnitude, this.kelvin)
    : x = cos(dec * pi / 180) * cos(ra * pi / 180),
      y = cos(dec * pi / 180) * sin(ra * pi / 180),
      z = sin(dec * pi / 180);

  final double ra;
  final double dec;
  final double magnitude;
  final int kelvin;
  final double x;
  final double y;
  final double z;
}

class ExplodingStar {
  ExplodingStar({
    required this.id,
    required this.ra,
    required this.dec,
    required this.firstSeen,
    required this.confidence,
  });

  factory ExplodingStar.fromJson(Map<String, dynamic> json) {
    return ExplodingStar(
      id: json['oid'] as String,
      ra: (json['meanra'] as num).toDouble(),
      dec: (json['meandec'] as num).toDouble(),
      firstSeen: mjdToDate(json['firstmjd'] as num),
      confidence: (json['probability'] as num).toDouble(),
    );
  }

  final String id;
  final double ra;
  final double dec;
  final DateTime firstSeen;
  final double confidence;

  Duration get age => DateTime.now().difference(firstSeen);

  bool get isNew => age.inHours < 24;
}

DateTime mjdToDate(num mjd) {
  return DateTime.fromMillisecondsSinceEpoch(((mjd - 40587) * 86400000).round(), isUtc: true);
}

double dateToMjd(DateTime date) => date.millisecondsSinceEpoch / 86400000 + 40587;

Future<List<BrightStar>> loadBrightStars() async {
  final raw = await rootBundle.loadString('assets/stars.json');
  final list = jsonDecode(raw) as List;
  return [
    for (final s in list)
      BrightStar((s[0] as num).toDouble(), (s[1] as num).toDouble(), (s[2] as num).toDouble(), s[3] as int),
  ];
}

class Telescope {
  static const _api = 'https://api.alerce.online/ztf/v1/objects';

  final _distances = <String, double?>{};

  Future<List<ExplodingStar>> explodingStars({int days = 7}) async {
    final now = dateToMjd(DateTime.now());
    final uri = Uri.parse('$_api/').replace(
      queryParameters: {
        'classifier': 'stamp_classifier',
        'class': 'SN',
        'ranking': '1',
        'probability': '0.5',
        'firstmjd': [(now - days).toStringAsFixed(4), (now + 1).toStringAsFixed(4)],
        'order_by': 'firstmjd',
        'order_mode': 'DESC',
        'page_size': '300',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Telescope data failed (${response.statusCode})');
    }
    final items = (jsonDecode(response.body) as Map<String, dynamic>)['items'] as List;
    return [for (final item in items) ExplodingStar.fromJson(item as Map<String, dynamic>)];
  }

  Future<double?> lightYearsAway(String id) async {
    if (_distances.containsKey(id)) return _distances[id];
    try {
      final response = await http.get(Uri.parse('$_api/$id/magstats')).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final bands = jsonDecode(response.body) as List;
      if (bands.isEmpty) return null;
      final brightest = bands.map((b) => (b['magmin'] as num).toDouble()).reduce(min);
      final parsecs = pow(10, (brightest + 18.5 + 5) / 5).toDouble();
      final lightYears = parsecs * 3.2616;
      _distances[id] = lightYears;
      return lightYears;
    } catch (_) {
      return null;
    }
  }
}

String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 2) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
  if (diff.inHours == 1) return '1 hour ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays} days ago';
}

String lightYearsText(double lightYears) {
  if (lightYears >= 1e9) return '${(lightYears / 1e9).toStringAsFixed(1)} billion';
  return '${(lightYears / 1e6).round()} million';
}
