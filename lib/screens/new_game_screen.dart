import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/team.dart';
import '../services/game_service.dart';
import '../widgets/team_dropdown.dart';
import 'game_board_screen.dart';

class NewGameScreen extends StatefulWidget {
  const NewGameScreen({super.key});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final GameService _gameService = GameService();
  DateTime _matchDate = DateTime.now();
  Team? _homeTeam;
  Team? _awayTeam;
  bool _creating = false;
  String? _error;

  bool get _canCreate => _homeTeam != null && _awayTeam != null && _homeTeam!.id != _awayTeam!.id;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _matchDate = picked);
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final game = await _gameService.createGame(
        matchDate: _matchDate,
        homeTeam: _homeTeam!,
        awayTeam: _awayTeam!,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GameBoardScreen(gameId: game.id, justCreated: true)),
      );
    } catch (e) {
      setState(() => _error = 'Could not create the game: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Game')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Match date'),
                  subtitle: Text(DateFormat.yMMMEd().format(_matchDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 16),
                TeamDropdown(label: 'Home team', onSelected: (t) => setState(() => _homeTeam = t)),
                const SizedBox(height: 16),
                TeamDropdown(label: 'Away team', onSelected: (t) => setState(() => _awayTeam = t)),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _canCreate && !_creating ? _create : null,
                  child: _creating
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
