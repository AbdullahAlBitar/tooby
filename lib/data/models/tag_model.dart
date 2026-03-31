class TagModel {
  final int? id;
  final String name;

  TagModel({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory TagModel.fromMap(Map<String, dynamic> map) {
    return TagModel(
      id: map['id'],
      name: map['name'],
    );
  }

  TagModel copyWith({
    int? id,
    String? name,
  }) {
    return TagModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
