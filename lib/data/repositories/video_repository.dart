import '../local/db_helper.dart';
import '../models/video_model.dart';
import '../models/watch_history_model.dart';

class VideoRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<VideoModel>> getAllVideos() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.queryAll('videos');
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }

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

  Future<int> insertVideo(VideoModel video) async {
    return await _dbHelper.insert('videos', video.toMap());
  }

  Future<void> updateVideo(VideoModel video) async {
    await _dbHelper.update(
      'videos',
      video.toMap(),
      'id = ?',
      [video.id],
    );
  }

  Future<void> deleteVideo(int id) async {
    await _dbHelper.delete('videos', 'id = ?', [id]);
  }

  // Watch History
  Future<void> saveWatchHistory(WatchHistoryModel history) async {
    await _dbHelper.insert('watch_history', history.toMap());
  }

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

  Future<List<Map<String, dynamic>>> getContinueWatching() async {
    // Join videos and watch_history ordered by last_watched desc
    return await _dbHelper.rawQuery('''
      SELECT v.*, h.last_position, h.last_watched 
      FROM videos v
      JOIN watch_history h ON v.id = h.video_id
      ORDER BY h.last_watched DESC
      LIMIT 10
    ''', []);
  }

  Future<List<VideoModel>> getRecentVideos() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
      'SELECT * FROM videos ORDER BY id DESC LIMIT 20',
      [],
    );
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }

  Future<void> clearWatchHistory() async {
    await _dbHelper.rawDelete('DELETE FROM watch_history', []);
  }

  Future<List<VideoModel>> searchVideos(String query, List<int> tagIds) async {
    String sql = 'SELECT v.*, COUNT(vt.tag_id) as match_count FROM videos v';
    List<dynamic> args = [];
    List<String> conditions = [];

    // Always join video_tags if we want to count matches, but use LEFT JOIN
    // so we don't exclude videos with no tags if we're also searching by title.
    if (tagIds.isNotEmpty) {
      sql += ' LEFT JOIN video_tags vt ON v.id = vt.video_id AND vt.tag_id IN (${List.filled(tagIds.length, '?').join(',')})';
      args.addAll(tagIds);
      conditions.add('match_count > 0');
    } else {
      sql += ' LEFT JOIN video_tags vt ON v.id = vt.video_id';
    }

    if (query.isNotEmpty) {
      conditions.add('v.title LIKE ?');
      args.add('%$query%');
    }

    sql += ' GROUP BY v.id';

    if (conditions.isNotEmpty) {
      // Use HAVING because match_count is an aggregate
      if (tagIds.isNotEmpty && query.isNotEmpty) {
        sql += ' HAVING (match_count > 0 OR v.title LIKE ?)';
        args.add('%$query%'); // Add query again for HAVING
      } else if (tagIds.isNotEmpty) {
        sql += ' HAVING match_count > 0';
      } else if (query.isNotEmpty) {
        sql += ' HAVING v.title LIKE ?';
        args.add('%$query%'); // Add query again for HAVING
      }
    }

    sql += ' ORDER BY match_count DESC, v.title ASC';

    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(sql, args);
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }
}
