import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game.dart';
import '../models/pick.dart';
import '../models/team.dart';

const _gameSelect =
    '*, home:teams!home_team_id(name), away:teams!away_team_id(name)';

class DrawResult {
  final PickTeam team;
  final int number;
  const DrawResult({required this.team, required this.number});
}

class GameService {
  final SupabaseClient _client = Supabase.instance.client;
  final _random = Random.secure();

  static const _codeAlphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O/0, I/1

  String _generateJoinCode() {
    return List.generate(
      6,
      (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
    ).join();
  }

  Future<Game> createGame({
    required DateTime matchDate,
    required Team homeTeam,
    required Team awayTeam,
    required double ticketPrice,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final joinCode = _generateJoinCode();
      try {
        final row = await _client
            .from('games')
            .insert({
              'match_date': matchDate.toIso8601String().substring(0, 10),
              'home_team_id': homeTeam.id,
              'away_team_id': awayTeam.id,
              'ticket_price': ticketPrice,
              'join_code': joinCode,
            })
            .select()
            .single();
        return Game(
          id: row['id'] as String,
          matchDate: matchDate,
          homeTeamId: homeTeam.id,
          awayTeamId: awayTeam.id,
          homeTeamName: homeTeam.name,
          awayTeamName: awayTeam.name,
          joinCode: row['join_code'] as String,
          status: 'open',
          ticketPrice: ticketPrice,
        );
      } on PostgrestException catch (e) {
        if (e.code == '23505') continue; // join code collision, retry
        rethrow;
      }
    }
    throw Exception('Could not generate a unique join code, please try again.');
  }

  Future<Game?> getGameByJoinCode(String joinCode) async {
    final row = await _client
        .from('games')
        .select(_gameSelect)
        .eq('join_code', joinCode.trim().toUpperCase())
        .maybeSingle();
    return row == null ? null : Game.fromMap(row);
  }

  Future<Game> getGameById(String gameId) async {
    final row = await _client
        .from('games')
        .select(_gameSelect)
        .eq('id', gameId)
        .single();
    return Game.fromMap(row);
  }

  Future<List<Game>> listHistory() async {
    final rows = await _client
        .from('games')
        .select(_gameSelect)
        .order('match_date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map((row) => Game.fromMap(row)).toList();
  }

  Future<DrawResult> drawSlot({
    required String gameId,
    required String playerName,
  }) async {
    final rows = await _client.rpc(
      'draw_slot',
      params: {'p_game_id': gameId, 'p_player_name': playerName.trim()},
    );
    final row = (rows as List).first as Map<String, dynamic>;
    return DrawResult(
      team: pickTeamFromString(row['team'] as String),
      number: row['number'] as int,
    );
  }

  Stream<List<Pick>> watchPicks(String gameId) {
    return _client
        .from('picks')
        .stream(primaryKey: ['id'])
        .eq('game_id', gameId)
        .order('claimed_at')
        .map((rows) => rows.map((row) => Pick.fromMap(row)).toList());
  }
}
