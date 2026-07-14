/// Shared OpenStreetMap-compatible tile config for flutter_map.
///
/// CartoCDN is used instead of tile.openstreetmap.org because the public OSM
/// endpoint is often rate-limited or very slow on mobile carrier networks.
abstract final class MapTiles {
  static const urlTemplate =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
  static const subdomains = ['a', 'b', 'c', 'd'];
  static const userAgentPackageName = 'com.epn.nexus_campus';
}
