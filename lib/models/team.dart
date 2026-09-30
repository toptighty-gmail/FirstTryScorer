class Team {
  final String id;
  final String name;

  const Team({required this.id, required this.name});

  factory Team.fromMap(Map<String, dynamic> map) {
    return Team(id: map['id'] as String, name: map['name'] as String);
  }
}
