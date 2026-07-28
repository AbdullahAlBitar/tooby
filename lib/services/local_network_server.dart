import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../data/repositories/video_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/models/video_model.dart';
import '../data/models/tag_model.dart';
import '../data/models/watch_history_model.dart';

class LocalNetworkServer {
  final VideoRepository videoRepository;
  final TagRepository tagRepository;
  
  HttpServer? _server;
  
  LocalNetworkServer({
    required this.videoRepository,
    required this.tagRepository,
  });

  Future<String?> start({int port = 8080}) async {
    if (_server != null) return null;

    final router = Router();
    _setupVideoRoutes(router);
    _setupTagRoutes(router);
    _setupFileRoutes(router);

    final handler = const Pipeline()
        .addMiddleware((innerHandler) {
          return (request) async {
            if (request.method == 'OPTIONS') {
              return Response.ok('', headers: _corsHeaders());
            }
            final response = await innerHandler(request);
            return response.change(headers: _corsHeaders());
          };
        })
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    return ip != null ? 'http://$ip:${_server!.port}' : null;
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  bool get isRunning => _server != null;

  Map<String, String> _corsHeaders() => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type',
  };

  void _setupVideoRoutes(Router router) {
    router.get('/api/videos', (Request request) async {
      final videos = await videoRepository.getAllVideos();
      return Response.ok(jsonEncode(videos.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });

    router.get('/api/videos/<id>', (Request request, String id) async {
      final video = await videoRepository.getVideoById(int.parse(id));
      if (video == null) return Response.notFound('Not found');
      return Response.ok(jsonEncode(video.toMap()), headers: {'content-type': 'application/json'});
    });

    router.post('/api/videos', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final video = VideoModel.fromMap(payload);
      final id = await videoRepository.insertVideo(video);
      return Response.ok(jsonEncode({'id': id}));
    });

    router.put('/api/videos', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final video = VideoModel.fromMap(payload);
      await videoRepository.updateVideo(video);
      return Response.ok(jsonEncode({'success': true}));
    });

    router.delete('/api/videos/<id>', (Request request, String id) async {
      await videoRepository.deleteVideo(int.parse(id));
      return Response.ok(jsonEncode({'success': true}));
    });

    router.get('/api/history/<id>', (Request request, String id) async {
      final h = await videoRepository.getWatchHistory(int.parse(id));
      return Response.ok(jsonEncode(h?.toMap() ?? {}), headers: {'content-type': 'application/json'});
    });

    router.post('/api/history', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final h = WatchHistoryModel.fromMap(payload);
      await videoRepository.saveWatchHistory(h);
      return Response.ok(jsonEncode({'success': true}));
    });

    router.get('/api/continue_watching', (Request request) async {
      final list = await videoRepository.getContinueWatching();
      return Response.ok(jsonEncode(list), headers: {'content-type': 'application/json'});
    });

    router.get('/api/recent_videos', (Request request) async {
      final list = await videoRepository.getRecentVideos();
      return Response.ok(jsonEncode(list.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });

    router.post('/api/search', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final list = await videoRepository.searchVideos(
        query: payload['query'] ?? '',
        includedTagIds: List<int>.from(payload['includedTagIds'] ?? []),
        excludedTagIds: List<int>.from(payload['excludedTagIds'] ?? []),
        includedTypeIds: List<int>.from(payload['includedTypeIds'] ?? []),
        excludedTypeIds: List<int>.from(payload['excludedTypeIds'] ?? []),
        matchAllTags: payload['matchAllTags'] ?? false,
      );
      return Response.ok(jsonEncode(list.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });
  }

  void _setupTagRoutes(Router router) {
    router.get('/api/tag_types', (Request request) async {
      final list = await tagRepository.getAllTagTypes();
      return Response.ok(jsonEncode(list.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });

    router.post('/api/tag_types', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final id = await tagRepository.insertTagType(payload['name']);
      return Response.ok(jsonEncode({'id': id}));
    });
    
    router.post('/api/tag_types/get_or_create', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final id = await tagRepository.getOrCreateTagType(payload['name']);
      return Response.ok(jsonEncode({'id': id}));
    });

    router.put('/api/tag_types/<id>', (Request request, String id) async {
      final payload = jsonDecode(await request.readAsString());
      await tagRepository.updateTagType(int.parse(id), payload['name']);
      return Response.ok(jsonEncode({'success': true}));
    });

    router.delete('/api/tag_types/<id>', (Request request, String id) async {
      await tagRepository.deleteTagType(int.parse(id));
      return Response.ok(jsonEncode({'success': true}));
    });

    router.get('/api/tags', (Request request) async {
      final list = await tagRepository.getAllTags();
      return Response.ok(jsonEncode(list.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });

    router.get('/api/tags_with_count', (Request request) async {
      final list = await tagRepository.getAllTagsWithCount();
      return Response.ok(jsonEncode(list), headers: {'content-type': 'application/json'});
    });

    router.post('/api/tags', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final id = await tagRepository.insertTag(payload['name'], typeId: payload['typeId']);
      return Response.ok(jsonEncode({'id': id}));
    });
    
    router.post('/api/tags/get_or_create', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      final id = await tagRepository.getOrCreateTag(payload['name'], typeId: payload['typeId']);
      return Response.ok(jsonEncode({'id': id}));
    });

    router.put('/api/tags', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      await tagRepository.updateTag(TagModel.fromMap(payload));
      return Response.ok(jsonEncode({'success': true}));
    });

    router.delete('/api/tags/<id>', (Request request, String id) async {
      await tagRepository.deleteTag(int.parse(id));
      return Response.ok(jsonEncode({'success': true}));
    });

    router.post('/api/video_tags', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      await tagRepository.addTagToVideo(payload['videoId'], payload['tagId']);
      return Response.ok(jsonEncode({'success': true}));
    });

    router.delete('/api/video_tags', (Request request) async {
      final payload = jsonDecode(await request.readAsString());
      await tagRepository.removeTagFromVideo(payload['videoId'], payload['tagId']);
      return Response.ok(jsonEncode({'success': true}));
    });

    router.get('/api/tags/video/<id>', (Request request, String id) async {
      final list = await tagRepository.getTagsForVideo(int.parse(id));
      return Response.ok(jsonEncode(list.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });

    router.get('/api/videos/tag/<id>', (Request request, String id) async {
      final list = await tagRepository.getVideosForTag(int.parse(id));
      return Response.ok(jsonEncode(list.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });

    router.get('/api/recommendations/<id>', (Request request, String id) async {
      final list = await tagRepository.getRecommendedVideos(int.parse(id));
      return Response.ok(jsonEncode(list.map((v) => v.toMap()).toList()), headers: {'content-type': 'application/json'});
    });

    router.get('/api/random_tag_type', (Request request) async {
      final data = await tagRepository.getRandomTagTypeWithVideos();
      return Response.ok(jsonEncode(data ?? {}), headers: {'content-type': 'application/json'});
    });
  }

  void _setupFileRoutes(Router router) {
    router.get('/stream/file', (Request request) async {
      final path = request.url.queryParameters['path'];
      if (path == null) return Response.badRequest(body: 'Missing path parameter');
      
      final file = File(path);
      if (!await file.exists()) return Response.notFound('File not found');

      final stat = await file.stat();
      final totalLength = stat.size;

      final rangeHeader = request.headers['range'];
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        final start = int.tryParse(parts[0]) ?? 0;
        final end = parts.length > 1 && parts[1].isNotEmpty ? int.tryParse(parts[1]) : null;
        
        final actualEnd = end ?? totalLength - 1;
        final contentLength = actualEnd - start + 1;

        return Response(
          206, // Partial Content
          body: file.openRead(start, actualEnd + 1),
          headers: {
            'Accept-Ranges': 'bytes',
            'Content-Type': path.endsWith('.mp4') ? 'video/mp4' : 'application/octet-stream',
            'Content-Length': contentLength.toString(),
            'Content-Range': 'bytes $start-$actualEnd/$totalLength',
          },
        );
      } else {
        return Response.ok(
          file.openRead(),
          headers: {
            'Accept-Ranges': 'bytes',
            'Content-Type': path.endsWith('.mp4') ? 'video/mp4' : 'image/jpeg',
            'Content-Length': totalLength.toString(),
          },
        );
      }
    });
  }
}
