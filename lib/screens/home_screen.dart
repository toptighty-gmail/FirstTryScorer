import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'join_game_screen.dart';
import 'new_game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('First Try Scorer')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_rugby, size: 72),
                const SizedBox(height: 8),
                Text('First Try Scorer', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 32),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Game'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NewGameScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Join Game'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinGameScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('History'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
