import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/video_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../services/video_scanner_service.dart';
import '../data/models/video_model.dart';
import '../data/models/tag_model.dart';
import '../data/models/tag_type_model.dart';

// Repositories
final videoRepositoryProvider = Provider((ref) => VideoRepository());
final tagRepositoryProvider = Provider((ref) => TagRepository());

// Services
final videoScannerServiceProvider = Provider((ref) => VideoScannerService());

// State Providers
final allVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final repo = ref.watch(videoRepositoryProvider);
  return await repo.getAllVideos();
});

final recentVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final repo = ref.watch(videoRepositoryProvider);
  return await repo.getRecentVideos();
});

final continueWatchingProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(videoRepositoryProvider);
  return await repo.getContinueWatching();
});

final allTagsProvider = FutureProvider<List<TagModel>>((ref) async {
  final repo = ref.watch(tagRepositoryProvider);
  final tags = await repo.getAllTags();
  tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return tags;
});

final allTagsWithCountProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(tagRepositoryProvider);
  return await repo.getAllTagsWithCount();
});

final allTagTypesProvider = FutureProvider<List<TagTypeModel>>((ref) async {
  final repo = ref.watch(tagRepositoryProvider);
  final types = await repo.getAllTagTypes();
  types.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return types;
});

// Parameterized Providers
final videoByIdProvider = FutureProvider.family<VideoModel?, int>((ref, id) async {
  final repo = ref.watch(videoRepositoryProvider);
  return await repo.getVideoById(id);
});

final tagsForVideoProvider = FutureProvider.family<List<TagModel>, int>((ref, videoId) async {
  final repo = ref.watch(tagRepositoryProvider);
  return await repo.getTagsForVideo(videoId);
});

final recommendedVideosProvider = FutureProvider.family<List<VideoModel>, int>((ref, videoId) async {
  final repo = ref.watch(tagRepositoryProvider);
  return await repo.getRecommendedVideos(videoId);
});

final videosForTagProvider = FutureProvider.family<List<VideoModel>, int>((ref, tagId) async {
  final repo = ref.watch(tagRepositoryProvider);
  return await repo.getVideosForTag(tagId);
});

final randomTagTypeVideosProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final repo = ref.watch(tagRepositoryProvider);
  return await repo.getRandomTagTypeWithVideos();
});
