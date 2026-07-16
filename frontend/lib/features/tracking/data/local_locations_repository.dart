import 'package:sqflite/sqflite.dart';
import '../../../../core/database/db_helper.dart';
import '../domain/location_point.dart';

class LocalLocationsRepository {
  final DbHelper _dbHelper;

  LocalLocationsRepository(this._dbHelper);

  Future<int> saveLocation(LocationPoint point) async {
    final db = await _dbHelper.database;
    return await db.insert('locations_cache', point.toSqliteMap());
  }

  Future<List<LocationPoint>> getPendingLocations(int limit) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'locations_cache',
      orderBy: 'timestamp ASC',
      limit: limit,
    );
    return maps.map((map) => LocationPoint.fromSqliteMap(map)).toList();
  }

  Future<int> deleteLocations(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await _dbHelper.database;
    return await db.delete(
      'locations_cache',
      where: 'id IN (${ids.join(",")})',
    );
  }

  Future<int> getPendingCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM locations_cache');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<LocationPoint?> getLastCapturedLocation() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'locations_cache',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return LocationPoint.fromSqliteMap(maps.first);
  }
}
