import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game.dart';
import '../services/game_service.dart'
    show
        DrawResult,
        GameService,
        closedDrawMessage,
        drawAvailabilityMessage;
import '../widgets/ticket_payment_agreement_dialog.dart';
import 'draw_confirmation_screen.dart';

const _playerNamePrefKey = 'player_name';

class JoinGameScreen extends StatefulWidget {
  final String? initialJoinCode;
  final String? initialName;
  final List<DrawResult> previousAllocations;

  const JoinGameScreen({
    super.key,
    this.initialJoinCode,
    this.initialName,
    this.previousAllocations = const [],
  });

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final GameService _gameService = GameService();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  Timer? _lookupDebounce;
  int _lookupRequest = 0;
  Game? _previewGame;
  int? _previewDrawCount;
  bool _lookingUpGame = false;
  String? _lookupError;
  bool _drawing = false;
  bool _gameUnavailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codeController.text = widget.initialJoinCode ?? '';
    _nameController.text = widget.initialName ?? '';
    _scheduleGameLookup(_codeController.text);
    SharedPreferences.getInstance().then((prefs) {
      final savedName = prefs.getString(_playerNamePrefKey);
      if (widget.initialName == null && savedName != null && mounted) {
        _nameController.text = savedName;
      }
    });
  }

  @override
  void dispose() {
    _lookupDebounce?.cancel();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _scheduleGameLookup(String value) {
    _lookupDebounce?.cancel();
    final request = ++_lookupRequest;
    final code = value.trim().toUpperCase();
    setState(() {
      _previewGame = null;
      _previewDrawCount = null;
      _lookingUpGame = code.length == 6;
      _lookupError = null;
      _gameUnavailable = false;
      _error = null;
    });
    if (code.length != 6) return;

    _lookupDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _lookupGame(code, request),
    );
  }

  Future<void> _lookupGame(String code, int request) async {
    try {
      final game = await _gameService.getGameByJoinCode(code);
      if (!mounted || request != _lookupRequest) return;
      if (game == null) {
        setState(() {
          _lookingUpGame = false;
          _lookupError = "No game found for code '$code'.";
        });
        return;
      }

      final drawCount = await _gameService.getDrawCount(game.id);
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        _previewGame = game;
        _previewDrawCount = drawCount;
        _lookingUpGame = false;
        _gameUnavailable = game.status != 'open';
      });
    } catch (error) {
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        _lookingUpGame = false;
        _lookupError = 'Could not load game details: $error';
      });
    }
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
            previousAllocations: widget.previousAllocations,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  onChanged: _scheduleGameLookup,
                  decoration: const InputDecoration(
                    labelText: 'Join code',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                if (_lookingUpGame) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_lookupError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _lookupError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_previewGame case final game?) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${game.homeTeamName} vs ${game.awayTeamName}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(DateFormat.yMMMMd().format(game.matchDate)),
                          const SizedBox(height: 8),
                          Text(
                            drawAvailabilityMessage(_previewDrawCount ?? 0),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
