class WatchHistoryModel {
  final int videoId;
  final Duration lastPosition;
  final DateTime lastWatched;

  WatchHistoryModel({
    required this.videoId,
    required this.lastPosition,
    required this.lastWatched,
  });

  Map<String, dynamic> toMap() {
    return {
      'video_id': videoId,
      'last_position': lastPosition.inMilliseconds,
      'last_watched': lastWatched.millisecondsSinceEpoch,
    };
  }

  factory WatchHistoryModel.fromMap(Map<String, dynamic> map) {
    return WatchHistoryModel(
      videoId: map['video_id'],
      lastPosition: Duration(milliseconds: map['last_position']),
      lastWatched: DateTime.fromMillisecondsSinceEpoch(map['last_watched']),
    );
  }

  WatchHistoryModel copyWith({
    int? videoId,
    Duration? lastPosition,
    DateTime? lastWatched,
  }) {
    return WatchHistoryModel(
      videoId: videoId ?? this.videoId,
      lastPosition: lastPosition ?? this.lastPosition,
      lastWatched: lastWatched ?? this.lastWatched,
    );
  }
}
