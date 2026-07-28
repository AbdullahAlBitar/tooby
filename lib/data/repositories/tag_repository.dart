import '../local/db_helper.dart';
import '../models/tag_model.dart';
import '../models/tag_type_model.dart';
import '../models/video_model.dart';

abstract class TagRepository {
  // Tag Types CRUD
  Future<List<TagTypeModel>> getAllTagTypes();
  Future<int> insertTagType(String name);
  Future<int> getOrCreateTagType(String name);
  Future<void> updateTagType(int id, String name);
  Future<void> deleteTagType(int id);

  // Tags CRUD
  Future<List<TagModel>> getAllTags();
  Future<List<Map<String, dynamic>>> getAllTagsWithCount();
  Future<int> insertTag(String name, {int? typeId});
  Future<int> getOrCreateTag(String name, {int? typeId});
  Future<void> updateTag(TagModel tag);
  Future<void> deleteTag(int id);

  // Video-Tag relationship
  Future<void> addTagToVideo(int videoId, int tagId);
  Future<void> removeTagFromVideo(int videoId, int tagId);
  Future<List<TagModel>> getTagsForVideo(int videoId);
  Future<List<VideoModel>> getVideosForTag(int tagId);

  // Recommendation logic
  Future<List<VideoModel>> getRecommendedVideos(int videoId);
  Future<Map<String, dynamic>?> getRandomTagTypeWithVideos();
}

class LocalTagRepository implements TagRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  Future<List<TagTypeModel>> getAllTagTypes() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.queryAll('tag_types');
    return List.generate(maps.length, (i) => TagTypeModel.fromMap(maps[i]));
  }

  @override
  Future<int> insertTagType(String name) async {
    return await _dbHelper.insert('tag_types', {'name': name});
  }

  @override
  Future<int> getOrCreateTagType(String name) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
      'SELECT id FROM tag_types WHERE name = ?',
      [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'];
    }
    return await insertTagType(name);
  }

  @override
  Future<void> updateTagType(int id, String name) async {
    await _dbHelper.update('tag_types', {'name': name}, 'id = ?', [id]);
  }

  @override
  Future<void> deleteTagType(int id) async {
    await _dbHelper.delete('tag_types', 'id = ?', [id]);
  }

  @override
  Future<List<TagModel>> getAllTags() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery('''
      SELECT t.*, ty.name as type_name, COUNT(vt.video_id) as video_count
      FROM tags t
      LEFT JOIN tag_types ty ON t.type_id = ty.id
      LEFT JOIN video_tags vt ON t.id = vt.tag_id
      GROUP BY t.id
    ''', []);
    return List.generate(maps.length, (i) => TagModel.fromMap(maps[i]));
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTagsWithCount() async {
    return await _dbHelper.rawQuery('''
      SELECT t.*, ty.name as type_name, COUNT(vt.video_id) as video_count
      FROM tags t
      LEFT JOIN tag_types ty ON t.type_id = ty.id
      LEFT JOIN video_tags vt ON t.id = vt.tag_id
      GROUP BY t.id
      ORDER BY video_count DESC, t.name ASC
    ''', []);
  }

  @override
  Future<int> insertTag(String name, {int? typeId}) async {
    return await _dbHelper.insert('tags', {
      'name': name,
      'type_id': typeId ?? 1,
    });
  }

  @override
  Future<int> getOrCreateTag(String name, {int? typeId}) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery(
      'SELECT id FROM tags WHERE name = ?',
      [name],
    );
    if (maps.isNotEmpty) {
      return maps.first['id'];
    }
    return await insertTag(name, typeId: typeId);
  }

  @override
  Future<void> updateTag(TagModel tag) async {
    await _dbHelper.update(
      'tags',
      {
        'name': tag.name,
        'type_id': tag.typeId ?? 1,
      },
      'id = ?',
      [tag.id],
    );
  }

  @override
  Future<void> deleteTag(int id) async {
    await _dbHelper.delete('tags', 'id = ?', [id]);
  }

  @override
  Future<void> addTagToVideo(int videoId, int tagId) async {
    await _dbHelper.insert('video_tags', {
      'video_id': videoId,
      'tag_id': tagId,
    });
  }

  @override
  Future<void> removeTagFromVideo(int videoId, int tagId) async {
    await _dbHelper.delete(
      'video_tags',
      'video_id = ? AND tag_id = ?',
      [videoId, tagId],
    );
  }

  @override
  Future<List<TagModel>> getTagsForVideo(int videoId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery('''
      SELECT t.*, ty.name as type_name,
             (SELECT COUNT(*) FROM video_tags WHERE tag_id = t.id) as video_count
      FROM tags t
      LEFT JOIN tag_types ty ON t.type_id = ty.id
      JOIN video_tags vt ON t.id = vt.tag_id
      WHERE vt.video_id = ?
    ''', [videoId]);
    return List.generate(maps.length, (i) => TagModel.fromMap(maps[i]));
  }

  @override
  Future<List<VideoModel>> getVideosForTag(int tagId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery('''
      SELECT v.* FROM videos v
      JOIN video_tags vt ON v.id = vt.video_id
      WHERE vt.tag_id = ?
    ''', [tagId]);
    return List.generate(maps.length, (i) => VideoModel.fromMap(maps[i]));
  }

  @override
  Future<List<VideoModel>> getRecommendedVideos(int videoId) async {
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

  @override
  Future<Map<String, dynamic>?> getRandomTagTypeWithVideos() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.rawQuery('''
      SELECT ty.* 
      FROM tag_types ty
      JOIN tags t ON ty.id = t.type_id
      JOIN video_tags vt ON t.id = vt.tag_id
      GROUP BY ty.id
      ORDER BY RANDOM()
      LIMIT 1
    ''', []);
    if (maps.isNotEmpty) {
      final typeId = maps.first['id'] as int;
      final typeName = maps.first['name'] as String;

      final List<Map<String, dynamic>> videoMaps = await _dbHelper.rawQuery('''
        SELECT DISTINCT v.* 
        FROM videos v
        JOIN video_tags vt ON v.id = vt.video_id
        JOIN tags t ON vt.tag_id = t.id
        WHERE t.type_id = ?
        ORDER BY RANDOM()
        LIMIT 10
      ''', [typeId]);
      
      final List<VideoModel> videos = List.generate(videoMaps.length, (i) => VideoModel.fromMap(videoMaps[i]));
      return {
        'typeId': typeId,
        'typeName': typeName,
        'videos': videos,
      };
    }
    return null;
  }
}
