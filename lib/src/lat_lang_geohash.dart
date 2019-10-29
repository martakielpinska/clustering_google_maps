import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:geohash/geohash.dart';

class LatLngAndGeohash {
  final LatLng location;
  String geohash;
  final Map<String, dynamic> rawData;

  LatLngAndGeohash(this.location, this.rawData) {
    geohash = Geohash.encode(location.latitude, location.longitude);
  }

  LatLngAndGeohash.fromMap(
      Map<String, dynamic> map, String latKey, String longKey)
      : location = LatLng(map[latKey].toDouble(), map[longKey].toDouble()),
        rawData = map {
    this.geohash =
        Geohash.encode(this.location.latitude, this.location.longitude);
  }

  getId() {
    return location.latitude.toString() + "_" + location.longitude.toString();
  }
}
