import 'package:trackon_mobile/data/models/map_point.dart';

/// Decodes a Google-encoded-polyline string (precision 5) into a list
/// of [MapPoint]s.
///
/// Mirror of the encoder in
/// `trackon_back/.../util/PolylineEncoder.java`. Same algorithm used
/// by Google Maps, Strava, Mapbox Directions — safe to swap for an
/// off-the-shelf library if we ever outgrow this inline copy.
class PolylineDecoder {
  PolylineDecoder._();

  static List<MapPoint> decode(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = <MapPoint>[];
    int index = 0;
    int lat = 0;
    int lon = 0;
    final len = encoded.length;

    while (index < len) {
      final dLat = _decodeValue(encoded, index);
      index = dLat.$2;
      lat += dLat.$1;

      final dLon = _decodeValue(encoded, index);
      index = dLon.$2;
      lon += dLon.$1;

      points.add(MapPoint(lat / 1e5, lon / 1e5));
    }
    return points;
  }

  /// Read one zigzag-chunked signed int starting at [index]. Returns
  /// (decoded value, new index).
  static (int, int) _decodeValue(String s, int index) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      b = s.codeUnitAt(index) - 63;
      index++;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final value = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    return (value, index);
  }
}
