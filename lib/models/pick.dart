enum PickTeam { home, away }

PickTeam pickTeamFromString(String value) {
  return value == 'home' ? PickTeam.home : PickTeam.away;
}

class Pick {
  final String id;
  final String gameId;
  final String playerName;
  final PickTeam team;
  final int number;

  const Pick({
    required this.id,
    required this.gameId,
    required this.playerName,
    required this.team,
    required this.number,
  });

  factory Pick.fromMap(Map<String, dynamic> map) {
    return Pick(
      id: map['id'] as String,
      gameId: map['game_id'] as String,
      playerName: map['player_name'] as String,
      team: pickTeamFromString(map['team'] as String),
      number: map['number'] as int,
    );
  }
}
