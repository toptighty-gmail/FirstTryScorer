import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/game.dart';
import '../models/pick.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import 'game_board_screen.dart';
import 'home_screen.dart';
import 'join_game_screen.dart';

class DrawConfirmationScreen extends StatefulWidget {
  final Game game;
  final String playerName;
  final PickTeam team;
  final int number;
  final List<DrawResult> previousAllocations;

  const DrawConfirmationScreen({
    super.key,
    required this.game,
    required this.playerName,
    required this.team,
    required this.number,
    this.previousAllocations = const [],
  });

  @override
  State<DrawConfirmationScreen> createState() => _DrawConfirmationScreenState();
}

class _DrawConfirmationScreenState extends State<DrawConfirmationScreen> {
  static const _bankDetails =
      'Mr J Dobson\nSort Code: 77-09-23\nAccount No: 27186560';

  late Future<bool> _adminFuture;

  List<DrawResult> get _allocations => [
    ...widget.previousAllocations,
    DrawResult(team: widget.team, number: widget.number),
  ];

  @override
  void initState() {
    super.initState();
    _adminFuture = _loadAdminStatus();
  }

  Future<bool> _loadAdminStatus() => AuthService.isInitialized
      ? AuthService.isCurrentUserAdmin()
      : Future.value(false);

  Future<void> _copyBankDetails(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _bankDetails));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(content: Text('Bank details copied to clipboard')),
    );
  }

  Future<void> _showTicketSummary() async {
    final price = NumberFormat.currency(
      locale: 'en_GB',
      symbol: '£',
    );
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your ticket summary'),
        content: SizedBox(
          width: 360,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_allocations.length} ticket${_allocations.length == 1 ? '' : 's'} for ${widget.playerName}',
                  ),
                  const SizedBox(height: 12),
                  ..._allocations.asMap().entries.map((entry) {
                    final teamName = entry.value.team == PickTeam.home
                        ? widget.game.homeTeamName
                        : widget.game.awayTeamName;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Ticket ${entry.key + 1}: $teamName #${entry.value.number}',
                      ),
                    );
                  }),
                  const Divider(),
                  Text(
                    'Total: ${price.format(widget.game.ticketPrice * _allocations.length)}',
                  ),
                  const SizedBox(height: 8),
                  const Text('Winnings are split 50/50.'),
                ],
              ),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _onPrimaryAction(bool isAdmin) async {
    if (!isAdmin) {
      await _showTicketSummary();
      return;
    }

    try {
      final stillAdmin = await _loadAdminStatus();
      if (!mounted) return;
      if (!stillAdmin) {
        setState(() => _adminFuture = Future.value(false));
        await _showTicketSummary();
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameBoardScreen(gameId: widget.game.id),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not verify admin access: $error')),
      );
      setState(() => _adminFuture = _loadAdminStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        '${widget.game.homeTeamName} vs ${widget.game.awayTeamName} · ${DateFormat.yMMMd().format(widget.game.matchDate)}',
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
                                widget.playerName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              ..._allocations.asMap().entries.map((entry) {
                                final teamName = entry.value.team == PickTeam.home
                                    ? widget.game.homeTeamName
                                    : widget.game.awayTeamName;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    _allocations.length == 1
                                        ? '$teamName #${entry.value.number}'
                                        : 'Ticket ${entry.key + 1}: $teamName #${entry.value.number}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                );
                              }),
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
                      FutureBuilder<bool>(
                        future: _adminFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Column(
                              children: [
                                Text(
                                  'Could not verify admin access.',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                                TextButton(
                                  onPressed: () => setState(
                                    () => _adminFuture = _loadAdminStatus(),
                                  ),
                                  child: const Text('Try again'),
                                ),
                              ],
                            );
                          }
                          if (!snapshot.hasData) {
                            return const FilledButton(
                              onPressed: null,
                              child: Text('Checking admin access...'),
                            );
                          }
                          final isAdmin = snapshot.data!;
                          return FilledButton.icon(
                            onPressed: () => _onPrimaryAction(isAdmin),
                            icon: Icon(
                              isAdmin
                                  ? Icons.arrow_forward
                                  : Icons.confirmation_number_outlined,
                            ),
                            label: Text(
                              isAdmin
                                  ? 'Continue to game board'
                                  : 'Show tickets summary',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => JoinGameScreen(
                              initialJoinCode: widget.game.joinCode,
                              initialName: widget.playerName,
                              previousAllocations: _allocations,
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
