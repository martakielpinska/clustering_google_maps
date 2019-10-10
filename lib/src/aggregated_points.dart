import 'package:google_maps_flutter/google_maps_flutter.dart';

class AggregatedPoints {
  final LatLng location;
  final int count;
  String bitmabAssetName;
  final int id;

  AggregatedPoints(this.location, this.count, this.id) {
    this.bitmabAssetName = getBitmapDescriptor();
  }

  AggregatedPoints.fromMap(
      Map<String, dynamic> map, String dbLatColumn, String dbLongColumn)
      : count = map['n_marker'],
        this.location = LatLng(map['lat'], map['long']),
        this.id = int.parse(map['ids'].split(',')[0].replaceAll('[', '')) {
    print(int.parse(map['ids'].split(',')[0].replaceAll('[', '')));
    this.bitmabAssetName = getBitmapDescriptor();
  }

  String getBitmapDescriptor() {
    String bitmapDescriptor;
    if (count < 10) {
      // + 2
      bitmapDescriptor = "assets/images/m1.png";
    } else if (count < 25) {
      // + 10
      bitmapDescriptor = "assets/images/m2.png";
    } else if (count < 50) {
      // + 25
      bitmapDescriptor = "assets/images/m3.png";
    } else if (count < 100) {
      // + 50
      bitmapDescriptor = "assets/images/m4.png";
    } else if (count < 500) {
      // + 100
      bitmapDescriptor = "assets/images/m5.png";
    } else if (count < 1000) {
      // +500
      bitmapDescriptor = "assets/images/m6.png";
    } else {
      // + 1k
      bitmapDescriptor = "assets/images/m7.png";
    }
    return bitmapDescriptor;
  }

  getId() {
    return count > 1
        ? location.latitude.toString() +
            "_" +
            location.longitude.toString() +
            "_$count"
        : location.latitude.toString() +
            "_" +
            location.longitude.toString() +
            "_id:$id";
  }
}
