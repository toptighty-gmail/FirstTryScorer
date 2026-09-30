import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import 'game_board_screen.dart';
import 'new_game_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GameService _gameService = GameService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Game>> _historyFuture;
  late final Future<bool> _adminFuture;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _adminFuture = AuthService.isCurrentUserAdmin();
    _historyFuture = _gameService.listHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final request = _gameService.listHistory();
    setState(() => _historyFuture = request);
    await request;
  }

  Future<void> _createGame() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewGameScreen()));
    if (mounted) await _refresh();
  }

  Future<void> _editGame(Game game) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NewGameScreen(gameToEdit: game)),
    );
    if (updated == true && mounted) await _refresh();
  }

  Future<void> _deleteGame(Game game) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this game?'),
        content: Text(
          'Delete ${game.homeTeamName} vs ${game.awayTeamName}? This also permanently deletes its ticket allocations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete game'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    try {
      await _gameService.deleteGame(game.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Game deleted')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete game: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminFuture,
      builder: (context, adminSnapshot) {
        if (!adminSnapshot.hasData) {
          if (adminSnapshot.hasError) {
            return const Scaffold(
              body: Center(child: Text('Could not verify admin access.')),
            );
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!adminSnapshot.data!) {
          return const Scaffold(
            body: Center(child: Text('History is available to admins only.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Game History')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _createGame,
            icon: const Icon(Icons.add),
            label: const Text('Create game'),
          ),
          body: FutureBuilder<List<Game>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 36),
                        const SizedBox(height: 12),
                        Text('Could not load games: ${snapshot.error}'),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final games = snapshot.data!;
              final filteredGames = games.where((game) {
                final query = _query.trim().toLowerCase();
                if (query.isEmpty) return true;
                return game.homeTeamName.toLowerCase().contains(query) ||
                    game.awayTeamName.toLowerCase().contains(query) ||
                    game.joinCode.toLowerCase().contains(query) ||
                    game.status.toLowerCase().contains(query);
              }).toList();

              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Search teams, code or status',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Clear search',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      sliver: filteredGames.isEmpty
                          ? SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  games.isEmpty
                                      ? 'No games yet. Create your first game.'
                                      : 'No games match your search.',
                                ),
                              ),
                            )
                          : SliverList.separated(
                              itemCount: filteredGames.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) => _GameCard(
                                game: filteredGames[index],
                                onOpen: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => GameBoardScreen(
                                      gameId: filteredGames[index].id,
                                    ),
                                  ),
                                ),
                                onEdit: () => _editGame(filteredGames[index]),
                                onDelete: () =>
                                    _deleteGame(filteredGames[index]),
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GameCard({
    required this.game,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = game.status == 'open'
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${game.homeTeamName} vs ${game.awayTeamName}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      game.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _GameMeta(
                    icon: Icons.calendar_today_outlined,
                    label: DateFormat.yMMMd().format(game.matchDate),
                  ),
                  _GameMeta(
                    icon: Icons.confirmation_number_outlined,
                    label: game.joinCode,
                  ),
                  _GameMeta(
                    icon: Icons.payments_outlined,
                    label: NumberFormat.currency(
                      locale: 'en_GB',
                      symbol: '£',
                    ).format(game.ticketPrice),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.grid_view_outlined),
                    label: const Text('Board'),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Edit game',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete game',
                    onPressed: onDelete,
                    color: colorScheme.error,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameMeta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GameMeta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
