import 'package:expert/maps/map_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('map config', () {
    test('uses the OpenStreetMap tile server without subdomains', () {
      expect(mapTileUrl, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
    });

    test('keeps Bandung as the fallback map center', () {
      expect(bandungCenter.latitude, -6.9175);
      expect(bandungCenter.longitude, 107.6191);
    });
  });
}
