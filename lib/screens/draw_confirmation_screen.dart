import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../models/pick.dart';
import 'game_board_screen.dart';
import 'home_screen.dart';
import 'join_game_screen.dart';

class DrawConfirmationScreen extends StatelessWidget {
  final Game game;
  final String playerName;
  final PickTeam team;
  final int number;

  const DrawConfirmationScreen({
    super.key,
    required this.game,
    required this.playerName,
    required this.team,
    required this.number,
  });

  static const _bankDetails =
      'Mr J Dobson\nSort Code: 77-09-23\nAccount No: 27186560';

  Future<void> _copyBankDetails(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _bankDetails));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(content: Text('Bank details copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamName = team == PickTeam.home
        ? game.homeTeamName
        : game.awayTeamName;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Allocation Summary')),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 52,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Allocation confirmed',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${game.homeTeamName} vs ${game.awayTeamName} · ${DateFormat.yMMMd().format(game.matchDate)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                playerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$teamName #$number',
                                textAlign: TextAlign.center,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Payment required for this allocation',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              const Text('Please pay into this bank account:'),
                              const SizedBox(height: 12),
                              const SelectableText(_bankDetails),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _copyBankDetails(context),
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy bank details'),
                                ),
                              ),
                              Text(
                                'Payment reference: Your Name and First Try Scorer.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => GameBoardScreen(gameId: game.id),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Continue to game board'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => JoinGameScreen(
                              initialJoinCode: game.joinCode,
                              initialName: playerName,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.confirmation_number_outlined),
                        label: const Text('Choose another ticket allocation'),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const HomeScreen(),
                          ),
                          (route) => false,
                        ),
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Exit to home'),
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
