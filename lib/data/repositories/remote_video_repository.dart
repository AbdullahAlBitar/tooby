import 'dart:convert';
import 'package:http/http.dart' as http;
import 'video_repository.dart';
import '../models/video_model.dart';
import '../models/watch_history_model.dart';

class RemoteVideoRepository implements VideoRepository {
  final String baseUrl;

  RemoteVideoRepository({required this.baseUrl});

  VideoModel _mapVideo(VideoModel v) {
    return v.copyWith(
      path: '$baseUrl/stream/file?path=${Uri.encodeComponent(v.path)}',
      thumbnail: v.thumbnail != null ? '$baseUrl/stream/file?path=${Uri.encodeComponent(v.thumbnail!)}' : null,
    );
  }

  @override
  Future<List<VideoModel>> getAllVideos() async {
    final response = await http.get(Uri.parse('$baseUrl/api/videos'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => _mapVideo(VideoModel.fromMap(map))).toList();
    }
    return [];
  }

  @override
  Future<VideoModel?> getVideoById(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/api/videos/$id'));
    if (response.statusCode == 200) {
      return _mapVideo(VideoModel.fromMap(jsonDecode(response.body)));
    }
    return null;
  }

  @override
  Future<int> insertVideo(VideoModel video) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/videos'),
      body: jsonEncode(video.toMap()),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['id'];
    }
    return 0;
  }

  @override
  Future<void> updateVideo(VideoModel video) async {
    await http.put(
      Uri.parse('$baseUrl/api/videos'),
      body: jsonEncode(video.toMap()),
    );
  }

  @override
  Future<void> deleteVideo(int id) async {
    await http.delete(Uri.parse('$baseUrl/api/videos/$id'));
  }

  @override
  Future<void> saveWatchHistory(WatchHistoryModel history) async {
    await http.post(
      Uri.parse('$baseUrl/api/history'),
      body: jsonEncode(history.toMap()),
    );
  }

  @override
  Future<WatchHistoryModel?> getWatchHistory(int videoId) async {
    final response = await http.get(Uri.parse('$baseUrl/api/history/$videoId'));
    if (response.statusCode == 200) {
      final map = jsonDecode(response.body);
      if (map.isEmpty) return null;
      return WatchHistoryModel.fromMap(map);
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getContinueWatching() async {
    final response = await http.get(Uri.parse('$baseUrl/api/continue_watching'));
    if (response.statusCode == 200) {
      final list = List<Map<String, dynamic>>.from(jsonDecode(response.body));
      for (var item in list) {
        final mapped = _mapVideo(VideoModel.fromMap(item));
        item['path'] = mapped.path;
        item['thumbnail'] = mapped.thumbnail;
      }
      return list;
    }
    return [];
  }

  @override
  Future<List<VideoModel>> getRecentVideos() async {
    final response = await http.get(Uri.parse('$baseUrl/api/recent_videos'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => _mapVideo(VideoModel.fromMap(map))).toList();
    }
    return [];
  }

  @override
  Future<void> clearWatchHistory() async {
    // Note: Didn't implement a clear endpoint, but could be added easily
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
    final response = await http.post(
      Uri.parse('$baseUrl/api/search'),
      body: jsonEncode({
        'query': query,
        'includedTagIds': includedTagIds,
        'excludedTagIds': excludedTagIds,
        'includedTypeIds': includedTypeIds,
        'excludedTypeIds': excludedTypeIds,
        'matchAllTags': matchAllTags,
      }),
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((map) => _mapVideo(VideoModel.fromMap(map))).toList();
    }
    return [];
  }
}
