import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:geohash/geohash.dart';

class LatLngAndGeohash {
  final LatLng location;
  String geohash;
  final dynamic id;

  LatLngAndGeohash(this.location, this.id) {
    geohash = Geohash.encode(location.latitude, location.longitude);
  }

  LatLngAndGeohash.fromMap(Map<String, dynamic> map)
      : location = LatLng(map['lat'].toDouble(), map['long'].toDouble()),
        this.id = map['id'] {
    this.geohash =
        Geohash.encode(this.location.latitude, this.location.longitude);
  }

  getId() {
    return location.latitude.toString() +
        "_" +
        location.longitude.toString() +
        "_id:$id";
  }
}
