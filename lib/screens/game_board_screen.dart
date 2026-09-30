import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../models/pick.dart';
import '../services/game_service.dart';

class GameBoardScreen extends StatefulWidget {
  final String gameId;
  final bool justCreated;

  const GameBoardScreen({super.key, required this.gameId, this.justCreated = false});

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final GameService _gameService = GameService();
  late final Future<Game> _gameFuture;
  late final Stream<List<Pick>> _picksStream;

  @override
  void initState() {
    super.initState();
    _gameFuture = _gameService.getGameById(widget.gameId);
    _picksStream = _gameService.watchPicks(widget.gameId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Game Board')),
      body: FutureBuilder<Game>(
        future: _gameFuture,
        builder: (context, gameSnapshot) {
          if (gameSnapshot.hasError) {
            return Center(child: Text('Could not load game: ${gameSnapshot.error}'));
          }
          if (!gameSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final game = gameSnapshot.data!;
          return Column(
            children: [
              _GameHeader(game: game, showShareHint: widget.justCreated),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<Pick>>(
                  stream: _picksStream,
                  builder: (context, picksSnapshot) {
                    final picks = picksSnapshot.data ?? const <Pick>[];
                    final homePicks = {for (final p in picks.where((p) => p.team == PickTeam.home)) p.number: p};
                    final awayPicks = {for (final p in picks.where((p) => p.team == PickTeam.away)) p.number: p};
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _TeamColumn(teamName: game.homeTeamName, picksByNumber: homePicks)),
                        const VerticalDivider(width: 1),
                        Expanded(child: _TeamColumn(teamName: game.awayTeamName, picksByNumber: awayPicks)),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GameHeader extends StatelessWidget {
  final Game game;
  final bool showShareHint;

  const _GameHeader({required this.game, required this.showShareHint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '${game.homeTeamName} vs ${game.awayTeamName}',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(DateFormat.yMMMEd().format(game.matchDate)),
          const SizedBox(height: 12),
          Chip(
            label: Text(
              'Join code: ${game.joinCode}',
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ),
          if (showShareHint) ...[
            const SizedBox(height: 8),
            Text(
              'Share this code so everyone can join and draw.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  final String teamName;
  final Map<int, Pick> picksByNumber;

  const _TeamColumn({required this.teamName, required this.picksByNumber});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(teamName, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 15,
            itemBuilder: (context, index) {
              final number = index + 1;
              final pick = picksByNumber[number];
              final taken = pick != null;
              return ListTile(
                dense: true,
                tileColor: taken ? colorScheme.surfaceContainerHighest : null,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: taken ? colorScheme.primary : colorScheme.outlineVariant,
                  foregroundColor: taken ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                  child: Text('$number'),
                ),
                title: Text(
                  taken ? pick.playerName : '—',
                  style: TextStyle(color: taken ? null : colorScheme.outline),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
