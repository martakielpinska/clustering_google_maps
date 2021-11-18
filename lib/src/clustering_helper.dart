import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:clustering_google_maps/src/aggregated_points.dart';
import 'package:clustering_google_maps/src/aggregation_setup.dart';
import 'package:clustering_google_maps/src/db_helper.dart';
import 'package:clustering_google_maps/src/lat_lang_geohash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

class ClusteringHelper {
  ClusteringHelper.forDB({
    @required this.dbTable,
    @required this.dbLatColumn,
    @required this.dbLongColumn,
    @required this.dbGeohashColumn,
    @required this.updateMarkers,
    this.database,
    this.whereClause = "",
    @required this.aggregationSetup,
    this.maxZoomForAggregatePoints = 13.5,
    this.getBitmapMarker,
    this.genericPin,
    this.onMarkerTapped,
  })  : assert(dbTable != null),
        assert(dbGeohashColumn != null),
        assert(dbLongColumn != null),
        assert(dbLatColumn != null),
        assert(aggregationSetup != null);

  ClusteringHelper.forMemory({
    @required this.list,
    @required this.updateMarkers,
    this.maxZoomForAggregatePoints = 13.5,
    @required this.aggregationSetup,
    this.getBitmapMarker,
    this.onMarkerTapped,
    this.genericPin,
  })  : assert(list != null),
        assert(aggregationSetup != null);

  //function for retrieving custom marker
  Future<BitmapDescriptor> Function(String color, String number, String id,
      {LatLngAndGeohash point}) getBitmapMarker;
  //custom onTap handler
  void Function(String markerId, LatLngAndGeohash point) onMarkerTapped;
  //Default light pin in custom style
  BitmapDescriptor genericPin;

  //After this value the map show the single points without aggregation
  final double maxZoomForAggregatePoints;

  //Database where we performed the queries
  Database database;

  //Name of table of the databasa SQLite where are stored the latitude, longitude and geoahash value
  String dbTable;

  //Name of column where is stored the latitude
  String dbLatColumn;

  //Name of column where is stored the longitude
  String dbLongColumn;

  //Name of column where is stored the geohash value
  String dbGeohashColumn;

  //Custom bitmap: string of assets position
  final AggregationSetup aggregationSetup;

  //Where clause for query db
  String whereClause;

  GoogleMapController mapController;

  //Function called when the map must show single point without aggregation
  // if null the class use the default function
  Function showSinglePoint;

  //Function for update Markers on Google Map
  Function updateMarkers;

  //List of points for memory clustering
  List<LatLngAndGeohash> list;

  //Call during the editing of CameraPosition
  //If you want updateMap during the zoom in/out set forceUpdate to true
  //this is NOT RECCOMENDED
  onCameraMove(CameraPosition position, {forceUpdate = false}) {
    if (forceUpdate) {
      updateMap(zoom: position.zoom);
    }
  }

  //Call when user stop to move or zoom the map
  Future<void> onMapIdle() async {
    updateMap();
  }

  updateMap({double zoom}) async {
    if (zoom == null) {
      zoom = await mapController.getZoomLevel();
    }
    if (zoom < maxZoomForAggregatePoints) {
      updateAggregatedPoints(zoom: zoom);
    } else {
      if (showSinglePoint != null) {
        showSinglePoint();
      } else {
        updatePoints(zoom);
      }
    }
  }

  // Used for update list
  // NOT RECCOMENDED for good performance (SQL IS BETTER)
  updateData(List<LatLngAndGeohash> newList) {
    list = newList;
    updateMap();
  }

  Future<List<AggregatedPoints>> getAggregatedPoints(double zoom) async {
    int level = 5;

    if (zoom <= aggregationSetup.maxZoomLimits[0]) {
      level = 1;
    } else if (zoom < aggregationSetup.maxZoomLimits[1]) {
      level = 2;
    } else if (zoom < aggregationSetup.maxZoomLimits[2]) {
      level = 3;
    } else if (zoom < aggregationSetup.maxZoomLimits[3]) {
      level = 4;
    } else if (zoom < aggregationSetup.maxZoomLimits[4]) {
      level = 5;
    } else if (zoom < aggregationSetup.maxZoomLimits[5]) {
      level = 6;
    } else if (zoom < aggregationSetup.maxZoomLimits[6]) {
      level = 7;
    }

    try {
      List<AggregatedPoints> aggregatedPoints;
      final latLngBounds = await mapController.getVisibleRegion();
      if (database != null) {
        aggregatedPoints = await DBHelper.getAggregatedPoints(
            database: database,
            dbTable: dbTable,
            dbLatColumn: dbLatColumn,
            dbLongColumn: dbLongColumn,
            dbGeohashColumn: dbGeohashColumn,
            level: level,
            latLngBounds: latLngBounds,
            whereClause: whereClause);
      } else {
        final listBounds = list.where((p) {
          final double leftTopLatitude = latLngBounds.northeast.latitude;
          final double leftTopLongitude = latLngBounds.southwest.longitude;
          final double rightBottomLatitude = latLngBounds.southwest.latitude;
          final double rightBottomLongitude = latLngBounds.northeast.longitude;

          final bool latQuery = (leftTopLatitude > rightBottomLatitude)
              ? p.location.latitude <= leftTopLatitude &&
                  p.location.latitude >= rightBottomLatitude
              : p.location.latitude <= leftTopLatitude ||
                  p.location.latitude >= rightBottomLatitude;

          final bool longQuery = (leftTopLongitude < rightBottomLongitude)
              ? p.location.longitude >= leftTopLongitude &&
                  p.location.longitude <= rightBottomLongitude
              : p.location.longitude >= leftTopLongitude ||
                  p.location.longitude <= rightBottomLongitude;
          return latQuery && longQuery;
        }).toList();

        aggregatedPoints = _retrieveAggregatedPoints(listBounds, [], level);
      }
      return aggregatedPoints;
    } catch (e) {
      assert(() {
        print(e.toString());
        return true;
      }());
      return <AggregatedPoints>[];
    }
  }

  final List<AggregatedPoints> aggList = [];

  List<AggregatedPoints> _retrieveAggregatedPoints(
      List<LatLngAndGeohash> inputList,
      List<AggregatedPoints> resultList,
      int level) {
    if (inputList.isEmpty) {
      return resultList;
    }
    final List<LatLngAndGeohash> newInputList = List.from(inputList);
    List<LatLngAndGeohash> tmp;
    final t = newInputList[0].geohash.substring(0, level);
    tmp =
        newInputList.where((p) => p.geohash.substring(0, level) == t).toList();
    newInputList.removeWhere((p) => p.geohash.substring(0, level) == t);
    double latitude = 0;
    double longitude = 0;
    tmp.forEach((l) {
      latitude += l.location.latitude;
      longitude += l.location.longitude;
    });
    final count = tmp.length;
    final a = AggregatedPoints(
        LatLng(latitude / count, longitude / count), count, null);
    resultList.add(a);
    return _retrieveAggregatedPoints(newInputList, resultList, level);
  }

  Future<void> updateAggregatedPoints({double zoom = 0.0}) async {
    List<AggregatedPoints> aggregation = await getAggregatedPoints(zoom);

    final Set<Marker> markers = {};

    for (var i = 0; i < aggregation.length; i++) {
      final a = aggregation[i];

      BitmapDescriptor bitmapDescriptor;

      if (getBitmapMarker != null) {
        if (a.count == 1) {
          bitmapDescriptor = await getBitmapMarker("light", "", null,
              point: LatLngAndGeohash.fromMap(
                  a.rawData, dbLatColumn, dbLongColumn));
        } else {
          bitmapDescriptor =
              await getBitmapMarker("light", "${a.count}", a.getId());
        }
      } else {
        if (a.count == 1) {
          bitmapDescriptor = BitmapDescriptor.defaultMarker;
        } else {
          // >1
          final Uint8List markerIcon =
              await getBytesFromCanvas(a.count.toString(), getColor(a.count));
          bitmapDescriptor = BitmapDescriptor.fromBytes(markerIcon);
        }
      }

      final MarkerId markerId = MarkerId(a.getId());
      var marker;
      if (onMarkerTapped == null) {
        marker = Marker(
          markerId: markerId,
          position: a.location,
          infoWindow: InfoWindow(title: a.count.toString()),
          icon: bitmapDescriptor,
        );
      } else {
        marker = Marker(
            markerId: markerId,
            position: a.location,
            icon: bitmapDescriptor,
            onTap: () {
              if (a.count == 1) {
                onMarkerTapped(
                    markerId.value,
                    LatLngAndGeohash.fromMap(
                        a.rawData, dbLatColumn, dbLongColumn));
              } else {
                onMarkerTapped(markerId.value, null);
              }
            });
      }

      markers.add(marker);
    }
    updateMarkers(markers);
  }

  updatePoints(double zoom) async {
    final latLngBounds = await mapController.getVisibleRegion();
    try {
      List<LatLngAndGeohash> listOfPoints;
      if (database != null) {
        listOfPoints = await DBHelper.getPoints(
          database: database,
          dbTable: dbTable,
          dbLatColumn: dbLatColumn,
          dbLongColumn: dbLongColumn,
          whereClause: whereClause,
          latLngBounds: latLngBounds,
        );
      } else {
        listOfPoints = list;
      }

      List<Marker> markersList = [];
      for (LatLngAndGeohash point in listOfPoints) {
        final MarkerId markerId = MarkerId(point.getId());

        var icon;
        if (getBitmapMarker != null) {
          icon =
              await getBitmapMarker("light", "", markerId.value, point: point);
        } else {
          icon =
              genericPin != null ? genericPin : BitmapDescriptor.defaultMarker;
        }
        markersList.add(Marker(
          markerId: markerId,
          position: point.location,
          onTap: () {
            if (markerId != null) onMarkerTapped(markerId.value, point);
          },
          icon: icon,
        ));
      }

      Set<Marker> markers = markersList.toSet();

      updateMarkers(markers);
    } catch (ex) {
      assert(() {
        print(ex.toString());
        return true;
      }());
    }
  }

  Future<Uint8List> getBytesFromCanvas(String text, MaterialColor color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint1 = Paint()..color = color[400];
    final Paint paint2 = Paint()..color = color[300];
    final Paint paint3 = Paint()..color = color[100];
    final int size = aggregationSetup.markerSize;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.0, paint3);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2.4, paint2);
    canvas.drawCircle(Offset(size / 2, size / 2), size / 3.3, paint1);
    TextPainter painter = TextPainter(textDirection: TextDirection.ltr);
    painter.text = TextSpan(
      text: text,
      style: TextStyle(
          fontSize: size / 4, color: Colors.black, fontWeight: FontWeight.bold),
    );
    painter.layout();
    painter.paint(
      canvas,
      Offset(size / 2 - painter.width / 2, size / 2 - painter.height / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(size, size);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data.buffer.asUint8List();
  }

  MaterialColor getColor(int count) {
    if (count < aggregationSetup.maxAggregationItems[0]) {
      // + 2
      return aggregationSetup.colors[0];
    } else if (count < aggregationSetup.maxAggregationItems[1]) {
      // + 10
      return aggregationSetup.colors[1];
    } else if (count < aggregationSetup.maxAggregationItems[2]) {
      // + 25
      return aggregationSetup.colors[2];
    } else if (count < aggregationSetup.maxAggregationItems[3]) {
      // + 50
      return aggregationSetup.colors[3];
    } else if (count < aggregationSetup.maxAggregationItems[4]) {
      // + 100
      return aggregationSetup.colors[4];
    } else if (count < aggregationSetup.maxAggregationItems[5]) {
      // +500
      return aggregationSetup.colors[5];
    } else {
      // + 1k
      return aggregationSetup.colors[6];
    }
  }
}
