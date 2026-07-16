class TagModel {
  final int? id;
  final String name;
  final int? typeId;
  final String? typeName;
  final int? videoCount;

  TagModel({
    this.id,
    required this.name,
    this.typeId,
    this.typeName,
    this.videoCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type_id': typeId ?? 1,
    };
  }

  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      id: map['id'],
      name: map['name'],
      typeId: map['type_id'],
      typeName: map['type_name'],
      videoCount: map['video_count'],
    );
  }

  TagModel copyWith({
    int? id,
    String? name,
    int? typeId,
    String? typeName,
    int? videoCount,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
      typeId: typeId ?? this.typeId,
      typeName: typeName ?? this.typeName,
      videoCount: videoCount ?? this.videoCount,
    );
  }
}
