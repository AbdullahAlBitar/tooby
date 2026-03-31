import '../local/db_helper.dart';
import '../models/tag_model.dart';
import '../models/video_model.dart';

class TagRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<TagModel>> getAllTags() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.queryAll('tags');
    return List.generate(maps.length, (i) => TagModel.fromMap(maps[i]));
  }

  Future<List<Map<String, dynamic>>> getAllTagsWithCount() async {
    return await _dbHelper.rawQuery('''
      SELECT t.*, COUNT(vt.video_id) as video_count
      FROM tags t
      LEFT JOIN video_tags vt ON t.id = vt.tag_id
      GROUP BY t.id
      ORDER BY video_count DESC, t.name ASC
    ''', []);
  }

  Future<int> insertTag(String name) async {
    return await _dbHelper.insert('tags', {'name': name});
  }

  Future<int> getOrCreateTag(String name) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
      'SELECT id FROM tags WHERE name = ?',
      [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'];
    }
    return await insertTag(name);
  }

  Future<void> deleteTag(int id) async {
    await _dbHelper.delete('tags', 'id = ?', [id]);
  }

  // Video-Tag relationship
  Future<void> addTagToVideo(int videoId, int tagId) async {
    await _dbHelper.insert('video_tags', {
      'video_id': videoId,
      'tag_id': tagId,
    });
  }

  Future<void> removeTagFromVideo(int videoId, int tagId) async {
    await _dbHelper.delete(
      'video_tags',
      'video_id = ? AND tag_id = ?',
      [videoId, tagId],
    );
  }

  Future<List<TagModel>> getTagsForVideo(int videoId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery('''
      SELECT t.* FROM tags t
      JOIN video_tags vt ON t.id = vt.tag_id
      WHERE vt.video_id = ?
    ''', [videoId]);
    return List.generate(maps.length, (i) => TagModel.fromMap(maps[i]));
  }

  Future<List<VideoModel>> getVideosForTag(int tagId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery('''
      SELECT v.* FROM videos v
      JOIN video_tags vt ON v.id = vt.video_id
      WHERE vt.tag_id = ?
    ''', [tagId]);
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }

  // Recommendation logic
  Future<List<VideoModel>> getRecommendedVideos(int videoId) async {
    // 1. Get tags for the current video
    // 2. Find other videos that share the same tags
    // 3. Count shared tags and order by count
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery('''
      SELECT v.*, COUNT(vt2.tag_id) as shared_tag_count
      FROM videos v
      JOIN video_tags vt2 ON v.id = vt2.video_id
      WHERE vt2.tag_id IN (
        SELECT tag_id FROM video_tags WHERE video_id = ?
      )
      AND v.id != ?
      GROUP BY v.id
      ORDER BY shared_tag_count DESC
      LIMIT 10
    ''', [videoId, videoId]);
    
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }
}
