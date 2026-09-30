class Game {
  final String id;
  final DateTime matchDate;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final String joinCode;
  final String status;
  final double ticketPrice;

  const Game({
    required this.id,
    required this.matchDate,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.joinCode,
    required this.status,
    required this.ticketPrice,
  });

  // Expects a row selected with the home/away team names embedded, e.g.
  // `select('*, home:teams!home_team_id(name), away:teams!away_team_id(name)')`.
  factory Game.fromMap(Map<String, dynamic> map) {
    return Game(
      id: map['id'] as String,
      matchDate: DateTime.parse(map['match_date'] as String),
      homeTeamId: map['home_team_id'] as String,
      awayTeamId: map['away_team_id'] as String,
      homeTeamName: (map['home'] as Map<String, dynamic>)['name'] as String,
      awayTeamName: (map['away'] as Map<String, dynamic>)['name'] as String,
      joinCode: map['join_code'] as String,
      status: (map['status'] ?? 'open') as String,
      ticketPrice: ((map['ticket_price'] ?? 0) as num).toDouble(),
    );
  }
}
