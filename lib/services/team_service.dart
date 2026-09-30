import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team.dart';

class TeamService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Team>> searchTeams(String query) async {
    final builder = _client.from('teams').select();
    final rows = query.trim().isEmpty
        ? await builder.order('name').limit(50)
        : await builder.ilike('name', '%${query.trim()}%').order('name').limit(50);
    return rows.map((row) => Team.fromMap(row)).toList();
  }

  /// Adds a team, or returns the existing one if the name is already taken
  /// (e.g. another device added it a moment earlier).
  Future<Team> addTeam(String name) async {
    final trimmed = name.trim();
    try {
      final row = await _client.from('teams').insert({'name': trimmed}).select().single();
      return Team.fromMap(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final row = await _client.from('teams').select().eq('name', trimmed).single();
        return Team.fromMap(row);
      }
      rethrow;
    }
  }
}
