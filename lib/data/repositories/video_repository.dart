import '../local/db_helper.dart';
import '../models/video_model.dart';
import '../models/watch_history_model.dart';

abstract class VideoRepository {
  Future<List<VideoModel>> getAllVideos();
  Future<VideoModel?> getVideoById(int id);
  Future<int> insertVideo(VideoModel video);
  Future<void> updateVideo(VideoModel video);
  Future<void> deleteVideo(int id);
  
  // Watch History
  Future<void> saveWatchHistory(WatchHistoryModel history);
  Future<WatchHistoryModel?> getWatchHistory(int videoId);
  Future<List<Map<String, dynamic>>> getContinueWatching();
  Future<List<VideoModel>> getRecentVideos();
  Future<void> clearWatchHistory();

  // Search
  Future<List<VideoModel>> searchVideos({
    required String query,
    required List<int> includedTagIds,
    required List<int> excludedTagIds,
    required List<int> includedTypeIds,
    required List<int> excludedTypeIds,
    bool matchAllTags = false,
  });
}

class LocalVideoRepository implements VideoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<List<VideoModel>> getAllVideos() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.queryAll('videos');
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }

  @override
  Future<VideoModel?> getVideoById(int id) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
      'SELECT * FROM videos WHERE id = ?',
      [id],
    );
    if (maps.isNotEmpty) {
      return VideoModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<int> insertVideo(VideoModel video) async {
    return await _dbHelper.insert('videos', video.toMap());
  }

  @override
  Future<void> updateVideo(VideoModel video) async {
    await _dbHelper.update(
      'videos',
      video.toMap(),
      'id = ?',
      [video.id],
    );
  }

  @override
  Future<void> deleteVideo(int id) async {
    await _dbHelper.delete('videos', 'id = ?', [id]);
  }

  @override
  Future<void> saveWatchHistory(WatchHistoryModel history) async {
    await _dbHelper.insert('watch_history', history.toMap());
  }

  @override
  Future<WatchHistoryModel?> getWatchHistory(int videoId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
      'SELECT * FROM watch_history WHERE video_id = ?',
      [videoId],
    );
    if (maps.isNotEmpty) {
      return WatchHistoryModel.fromMap(maps.first);
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getContinueWatching() async {
    return await _dbHelper.rawQuery('''
      SELECT v.*, h.last_position, h.last_watched 
      FROM videos v
      JOIN watch_history h ON v.id = h.video_id
      ORDER BY h.last_watched DESC
      LIMIT 10
    ''', []);
  }

  @override
  Future<List<VideoModel>> getRecentVideos() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
      'SELECT * FROM videos ORDER BY id DESC LIMIT 20',
      [],
    );
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }

  @override
  Future<void> clearWatchHistory() async {
    await _dbHelper.rawDelete('DELETE FROM watch_history', []);
  }

  @override
  Future<List<VideoModel>> searchVideos({
    required String query,
    required List<int> includedTagIds,
    required List<int> excludedTagIds,
    required List<int> includedTypeIds,
    required List<int> excludedTypeIds,
    bool matchAllTags = false,
  }) async {
    List<String> conditions = [];
    List<dynamic> args = [];

    if (query.isNotEmpty) {
      conditions.add('v.title LIKE ?');
      args.add('%$query%');
    }

    if (excludedTagIds.isNotEmpty) {
      final placeholders = List.filled(excludedTagIds.length, '?').join(',');
      conditions.add('''
        NOT EXISTS (
          SELECT 1 FROM video_tags vt 
          WHERE vt.video_id = v.id AND vt.tag_id IN ($placeholders)
        )
      ''');
      args.addAll(excludedTagIds);
    }

    if (includedTagIds.isNotEmpty) {
      final placeholders = List.filled(includedTagIds.length, '?').join(',');
      if (matchAllTags) {
        conditions.add('''
          (
            SELECT COUNT(DISTINCT vt.tag_id) FROM video_tags vt 
            WHERE vt.video_id = v.id AND vt.tag_id IN ($placeholders)
          ) = ?
        ''');
        args.addAll(includedTagIds);
        args.add(includedTagIds.length);
      } else {
        conditions.add('''
          EXISTS (
            SELECT 1 FROM video_tags vt 
            WHERE vt.video_id = v.id AND vt.tag_id IN ($placeholders)
          )
        ''');
        args.addAll(includedTagIds);
      }
    }

    if (includedTypeIds.isNotEmpty) {
      final placeholders = List.filled(includedTypeIds.length, '?').join(',');
      conditions.add('''
        EXISTS (
          SELECT 1 FROM video_tags vt 
          JOIN tags t ON vt.tag_id = t.id 
          WHERE vt.video_id = v.id AND t.type_id IN ($placeholders)
        )
      ''');
      args.addAll(includedTypeIds);
    }

    if (excludedTypeIds.isNotEmpty) {
      final placeholders = List.filled(excludedTypeIds.length, '?').join(',');
      conditions.add('''
        NOT EXISTS (
          SELECT 1 FROM video_tags vt 
          JOIN tags t ON vt.tag_id = t.id 
          WHERE vt.video_id = v.id AND t.type_id IN ($placeholders)
        )
      ''');
      args.addAll(excludedTypeIds);
    }

    String sql = 'SELECT v.* FROM videos v';
    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }
    sql += ' ORDER BY v.title ASC';

    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(sql, args);
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }
}
