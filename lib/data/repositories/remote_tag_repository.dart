import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tag_repository.dart';
import '../models/tag_model.dart';
import '../models/tag_type_model.dart';
import '../models/video_model.dart';

class RemoteTagRepository implements TagRepository {
  final String baseUrl;

  RemoteTagRepository({required this.baseUrl});

  VideoModel _mapVideo(VideoModel v) {
    return v.copyWith(
      path: '$baseUrl/stream/file?path=${Uri.encodeComponent(v.path)}',
      thumbnail: v.thumbnail != null ? '$baseUrl/stream/file?path=${Uri.encodeComponent(v.thumbnail!)}' : null,
    );
  }

  @override
  Future<List<TagTypeModel>> getAllTagTypes() async {
    final response = await http.get(Uri.parse('$baseUrl/api/tag_types'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => TagTypeModel.fromMap(map)).toList();
    }
    return [];
  }

  @override
  Future<int> insertTagType(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tag_types'),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body)['id'];
    return 0;
  }

  @override
  Future<int> getOrCreateTagType(String name) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tag_types/get_or_create'),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body)['id'];
    return 0;
  }

  @override
  Future<void> updateTagType(int id, String name) async {
    await http.put(
      Uri.parse('$baseUrl/api/tag_types/$id'),
      body: jsonEncode({'name': name}),
    );
  }

  @override
  Future<void> deleteTagType(int id) async {
    await http.delete(Uri.parse('$baseUrl/api/tag_types/$id'));
  }

  @override
  Future<List<TagModel>> getAllTags() async {
    final response = await http.get(Uri.parse('$baseUrl/api/tags'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => TagModel.fromMap(map)).toList();
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTagsWithCount() async {
    final response = await http.get(Uri.parse('$baseUrl/api/tags_with_count'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    return [];
  }

  @override
  Future<int> insertTag(String name, {int? typeId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tags'),
      body: jsonEncode({'name': name, 'typeId': typeId}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body)['id'];
    return 0;
  }

  @override
  Future<int> getOrCreateTag(String name, {int? typeId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tags/get_or_create'),
      body: jsonEncode({'name': name, 'typeId': typeId}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body)['id'];
    return 0;
  }

  @override
  Future<void> updateTag(TagModel tag) async {
    await http.put(
      Uri.parse('$baseUrl/api/tags'),
      body: jsonEncode(tag.toMap()),
    );
  }

  @override
  Future<void> deleteTag(int id) async {
    await http.delete(Uri.parse('$baseUrl/api/tags/$id'));
  }

  @override
  Future<void> addTagToVideo(int videoId, int tagId) async {
    await http.post(
      Uri.parse('$baseUrl/api/video_tags'),
      body: jsonEncode({'videoId': videoId, 'tagId': tagId}),
    );
  }

  @override
  Future<void> removeTagFromVideo(int videoId, int tagId) async {
    await http.delete(
      Uri.parse('$baseUrl/api/video_tags'),
      body: jsonEncode({'videoId': videoId, 'tagId': tagId}),
    );
  }

  @override
  Future<List<TagModel>> getTagsForVideo(int videoId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/tags/video/$videoId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => TagModel.fromMap(map)).toList();
    }
    return [];
  }

  @override
  Future<List<VideoModel>> getVideosForTag(int tagId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/videos/tag/$tagId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => _mapVideo(VideoModel.fromMap(map))).toList();
    }
    return [];
  }

  @override
  Future<List<VideoModel>> getRecommendedVideos(int videoId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/recommendations/$videoId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => _mapVideo(VideoModel.fromMap(map))).toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getRandomTagTypeWithVideos() async {
    final response = await http.get(Uri.parse('$baseUrl/api/random_tag_type'));
    if (response.statusCode == 200) {
      final map = jsonDecode(response.body);
      if (map.isEmpty) return null;
      // Videos list inside map
      if (map['videos'] != null) {
        map['videos'] = (map['videos'] as List).map((v) => _mapVideo(VideoModel.fromMap(v))).toList();
      }
      return map;
    }
    return null;
  }
}
