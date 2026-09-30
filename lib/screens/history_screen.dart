import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../services/game_service.dart';
import 'game_board_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GameService _gameService = GameService();
  late Future<List<Game>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _gameService.listHistory();
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _gameService.listHistory();
    });
    await _historyFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: FutureBuilder<List<Game>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load history: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final games = snapshot.data!;
          if (games.isEmpty) {
            return const Center(child: Text('No games yet.'));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: games.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final game = games[index];
                return ListTile(
                  title: Text('${game.homeTeamName} vs ${game.awayTeamName}'),
                  subtitle: Text(DateFormat.yMMMEd().format(game.matchDate)),
                  trailing: Text(game.joinCode, style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GameBoardScreen(gameId: game.id)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
