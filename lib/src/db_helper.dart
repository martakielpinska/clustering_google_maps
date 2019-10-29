import 'package:clustering_google_maps/src/aggregated_points.dart';
import 'package:clustering_google_maps/src/lat_lang_geohash.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLngBounds;
import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static Future<List<AggregatedPoints>> getAggregatedPoints({
    @required Database database,
    @required String dbTable,
    @required String dbLatColumn,
    @required String dbLongColumn,
    @required String dbGeohashColumn,
    @required int level,
    LatLngBounds latLngBounds,
    String whereClause = "",
  }) async {
    assert(() {
      return true;
    }());
    try {
      if (database == null) {
        throw Exception("Database must not be null");
      }

      final String boundingBoxClause = buildBoundingBoxClause(
        latLngBounds,
        dbTable,
        dbLatColumn,
        dbLongColumn,
      );
      whereClause = whereClause.isEmpty
          ? "WHERE $boundingBoxClause"
          : "$whereClause AND $boundingBoxClause";

      final query =
          'SELECT *, COUNT(*) as n_marker, AVG($dbLatColumn) as lat_avg, AVG($dbLongColumn) as long_avg '
          'FROM $dbTable $whereClause GROUP BY substr($dbGeohashColumn,1,$level);';
      var result = await database.rawQuery(query);

      List<AggregatedPoints> aggregatedPoints = new List();

      for (Map<String, dynamic> item in result) {
        var p = new AggregatedPoints.fromMap(item, dbLatColumn, dbLongColumn);
        aggregatedPoints.add(p);
      }
      return aggregatedPoints;
    } catch (e) {
      assert(() {
        print(e.toString());
        print("--------- COMPLETE QUERY AGGREGATION WITH ERROR");
        return true;
      }());
      return List<AggregatedPoints>();
    }
  }

  static Future<List<LatLngAndGeohash>> getPoints({
    @required Database database,
    @required String dbTable,
    @required String dbLatColumn,
    @required String dbLongColumn,
    LatLngBounds latLngBounds,
    String whereClause = "",
  }) async {
    try {
      final String boundingBoxClause = buildBoundingBoxClause(
        latLngBounds,
        dbTable,
        dbLatColumn,
        dbLongColumn,
      );

      whereClause = whereClause.isEmpty
          ? "WHERE $boundingBoxClause"
          : "$whereClause AND $boundingBoxClause";

      var result =
          await database.rawQuery('SELECT * FROM $dbTable $whereClause;');
      List<LatLngAndGeohash> points = new List();
      for (Map<String, dynamic> item in result) {
        var p = LatLngAndGeohash.fromMap(item, dbLatColumn, dbLongColumn);
        points.add(p);
      }

      return points;
    } catch (e) {
      assert(() {
        print(e.toString());
        return true;
      }());
      return List<LatLngAndGeohash>();
    }
  }

  static String buildBoundingBoxClause(
      LatLngBounds latLngBounds, String dbTable, String dbLat, String dbLong) {
    final double leftTopLatitude = latLngBounds.northeast.latitude;
    final double leftTopLongitude = latLngBounds.southwest.longitude;
    final double rightBottomLatitude = latLngBounds.southwest.latitude;
    final double rightBottomLongitude = latLngBounds.northeast.longitude;

    final latQuery = (leftTopLatitude > rightBottomLatitude)
        ? "($dbLat <= $leftTopLatitude AND $dbLat >= $rightBottomLatitude)"
        : "($dbLat <= $leftTopLatitude OR $dbLat >= $rightBottomLatitude)";

    final longQuery = (leftTopLongitude < rightBottomLongitude)
        ? "($dbLong >= $leftTopLongitude AND $dbLong <= $rightBottomLongitude)"
        : "($dbLong >= $leftTopLongitude OR $dbLong <= $rightBottomLongitude)";

    return "$latQuery AND $longQuery";
  }
}
