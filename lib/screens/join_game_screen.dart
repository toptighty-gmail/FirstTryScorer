import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/game_service.dart';
import '../widgets/ticket_payment_agreement_dialog.dart';
import 'draw_confirmation_screen.dart';

const _playerNamePrefKey = 'player_name';

class JoinGameScreen extends StatefulWidget {
  final String? initialJoinCode;
  final String? initialName;

  const JoinGameScreen({super.key, this.initialJoinCode, this.initialName});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final GameService _gameService = GameService();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _drawing = false;
  bool _gameUnavailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.text = widget.initialJoinCode ?? '';
    _nameController.text = widget.initialName ?? '';
    SharedPreferences.getInstance().then((prefs) {
      final savedName = prefs.getString(_playerNamePrefKey);
      if (widget.initialName == null && savedName != null && mounted) {
        _nameController.text = savedName;
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Enter the join code and your name.');
      return;
    }

    setState(() {
      _drawing = true;
      _gameUnavailable = false;
      _error = null;
    });

    try {
      final game = await _gameService.getGameByJoinCode(code);
      if (!mounted) return;
      if (game == null) {
        setState(() => _error = "No game found for code '$code'.");
        return;
      }
      if (game.status != 'open') {
        setState(() {
          _gameUnavailable = true;
          _error = closedDrawMessage(game.status);
        });
        return;
      }

      final agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            TicketPaymentAgreementDialog(ticketPrice: game.ticketPrice),
      );
      if (agreed != true || !mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_playerNamePrefKey, name);

      final result = await _gameService.drawSlot(
        gameId: game.id,
        playerName: name,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DrawConfirmationScreen(
            game: game,
            playerName: name,
            team: result.team,
            number: result.number,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is PostgrestException &&
          e.code == 'P0001' &&
          e.message == 'This draw is closed') {
        var message = 'This draw has ended and is no longer accepting entries.';
        try {
          final latestGame = await _gameService.getGameByJoinCode(code);
          if (latestGame != null) {
            message = closedDrawMessage(latestGame.status);
          }
        } catch (_) {
          // Keep the safe generic ended-draw message if status refresh fails.
        }
        if (!mounted) return;
        setState(() {
          _gameUnavailable = true;
          _error = message;
        });
        return;
      }
      setState(() => _error = 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Game')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Join code',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton(
                  onPressed: _drawing || _gameUnavailable ? null : _draw,
                  child: _drawing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Draw'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
