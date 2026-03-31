class VideoModel {
  final int? id;
  final String path;
  final String title;
  final String? duration;
  final String? thumbnail;

  VideoModel({
    this.id,
    required this.path,
    required this.title,
    this.duration,
    this.thumbnail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'duration': duration,
      'thumbnail': thumbnail,
    };
  }

  factory VideoModel.fromMap(Map<String, dynamic> map) {
    return VideoModel(
      id: map['id'],
      path: map['path'],
      title: map['title'],
      duration: map['duration'],
      thumbnail: map['thumbnail'],
    );
  }

  VideoModel copyWith({
    int? id,
    String? path,
    String? title,
    String? duration,
    String? thumbnail,
  }) {
    return VideoModel(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
    );
  }
}
