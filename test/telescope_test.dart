import 'package:flutter_test/flutter_test.dart';
import 'package:wishing_sky/sky_data.dart';

void main() {
  test('mjd conversion round trips', () {
    final date = DateTime.utc(2026, 10, 5, 12);
    expect(mjdToDate(dateToMjd(date)), date);
    expect(dateToMjd(DateTime.utc(2026, 10, 5)), 61318);
  });

  test('distance text', () {
    expect(lightYearsText(1.63e9), '1.6 billion');
    expect(lightYearsText(450e6), '450 million');
  });

  test('live telescope feed returns recent exploding stars', () async {
    final telescope = Telescope();
    final stars = await telescope.explodingStars();
    expect(stars, isNotEmpty);
    expect(stars.first.age.inDays, lessThan(7));
    final distance = await telescope.lightYearsAway(stars.first.id);
    expect(distance, isNotNull);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
