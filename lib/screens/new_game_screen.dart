import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../models/team.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../widgets/team_dropdown.dart';
import 'game_board_screen.dart';

class NewGameScreen extends StatefulWidget {
  final Game? gameToEdit;

  const NewGameScreen({super.key, this.gameToEdit});

  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final GameService _gameService = GameService();
  final TextEditingController _ticketPriceController = TextEditingController();
  DateTime _matchDate = DateTime.now();
  Team? _homeTeam;
  Team? _awayTeam;
  bool _creating = false;
  String? _error;

  double? get _ticketPrice => double.tryParse(_ticketPriceController.text);

  bool get _canCreate =>
      _homeTeam != null &&
      _awayTeam != null &&
      _homeTeam!.id != _awayTeam!.id &&
      _ticketPrice != null &&
      _ticketPrice! >= 0;

  String? get _teamSelectionMessage {
    if (_homeTeam == null || _awayTeam == null) {
      final missing = [
        if (_homeTeam == null) 'home',
        if (_awayTeam == null) 'away',
      ].join(' and ');
      return 'Select the $missing team from the suggestions, or use Add to create it.';
    }
    if (_homeTeam!.id == _awayTeam!.id) {
      return 'Home and away teams must be different.';
    }
    if (_ticketPrice == null || _ticketPrice! < 0) {
      return 'Enter a valid ticket price of £0 or more.';
    }
    return null;
  }

  @override
  void dispose() {
    _ticketPriceController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final game = widget.gameToEdit;
    if (game != null) {
      _matchDate = game.matchDate;
      _homeTeam = Team(id: game.homeTeamId, name: game.homeTeamName);
      _awayTeam = Team(id: game.awayTeamId, name: game.awayTeamName);
      _ticketPriceController.text = game.ticketPrice.toStringAsFixed(2);
    }
    _ensureAdminAccess();
  }

  Future<void> _ensureAdminAccess() async {
    final user = AuthService.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin sign in required to create games.'),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final isAdmin = await AuthService.isCurrentUserAdmin();
    if (!mounted) return;

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can create games.')),
      );
      Navigator.of(context).pop();
    }
  }

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

    final user = AuthService.currentUser;
    if (user == null) {
      setState(() => _error = 'Admin sign in required.');
      return;
    }

    final isAdmin = await AuthService.isCurrentUserAdmin();
    if (!isAdmin) {
      setState(() => _error = 'Only admins can create games.');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final game = widget.gameToEdit;
      if (game == null) {
        final createdGame = await _gameService.createGame(
          matchDate: _matchDate,
          homeTeam: _homeTeam!,
          awayTeam: _awayTeam!,
          ticketPrice: _ticketPrice!,
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                GameBoardScreen(gameId: createdGame.id, justCreated: true),
          ),
        );
      } else {
        await _gameService.updateGame(
          game: game,
          matchDate: _matchDate,
          homeTeam: _homeTeam!,
          awayTeam: _awayTeam!,
          ticketPrice: _ticketPrice!,
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = 'Could not create the game: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameToEdit == null ? 'New Game' : 'Edit Game'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
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
                      TextField(
                        controller: _ticketPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        onChanged: (_) => setState(() => _error = null),
                        decoration: const InputDecoration(
                          labelText: 'Ticket price',
                          prefixText: '£ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TeamDropdown(
                        label: 'Home team',
                        initialTeam: _homeTeam,
                        onSelected: (team) => setState(() {
                          _homeTeam = team;
                          _error = null;
                        }),
                        onQueryChanged: () => setState(() {
                          _homeTeam = null;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      TeamDropdown(
                        label: 'Away team',
                        initialTeam: _awayTeam,
                        onSelected: (team) => setState(() {
                          _awayTeam = team;
                          _error = null;
                        }),
                        onQueryChanged: () => setState(() {
                          _awayTeam = null;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Home: ${_homeTeam?.name ?? 'not selected'}  ·  Away: ${_awayTeam?.name ?? 'not selected'}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (_error != null || _teamSelectionMessage != null) ...[
                        Text(
                          _error ?? _teamSelectionMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: _canCreate && !_creating ? _create : null,
                        child: _creating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                widget.gameToEdit == null
                                    ? 'Create Game'
                                    : 'Save Changes',
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
