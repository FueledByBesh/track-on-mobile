/// Map-library-agnostic coordinate type.
/// Used as the boundary value object between app code and the map widget.
class MapPoint {
  final double lat;
  final double lon;

  const MapPoint(this.lat, this.lon);

  @override
  bool operator ==(Object other) =>
      other is MapPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'MapPoint($lat, $lon)';
}
