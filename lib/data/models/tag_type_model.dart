class TagTypeModel {
  final int? id;
  final String name;

  TagTypeModel({
    this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory TagTypeModel.fromMap(Map<String, dynamic> map) {
    return TagTypeModel(
      id: map['id'],
      name: map['name'],
    );
  }

  TagTypeModel copyWith({
    int? id,
    String? name,
  }) {
    return TagTypeModel(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}
