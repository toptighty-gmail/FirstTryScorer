import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/game.dart';
import '../models/pick.dart';
import '../services/auth_service.dart';
import '../services/game_service.dart';
import '../utils/game_join_link.dart';

class _BoardAccess {
  final bool isAdmin;
  final String? playerName;

  const _BoardAccess({required this.isAdmin, this.playerName});
}

class GameBoardScreen extends StatefulWidget {
  final String gameId;
  final bool justCreated;

  const GameBoardScreen({
    super.key,
    required this.gameId,
    this.justCreated = false,
  });

  @override
  State<GameBoardScreen> createState() => _GameBoardScreenState();
}

class _GameBoardScreenState extends State<GameBoardScreen> {
  final GameService _gameService = GameService();
  late Future<Game> _gameFuture;
  late final Stream<List<Pick>> _picksStream;
  late final Future<_BoardAccess> _accessFuture;
  bool _updatingStatus = false;
  bool _autoCloseStarted = false;
  List<Pick> _latestPicks = const <Pick>[];

  @override
  void initState() {
    super.initState();
    _gameFuture = _gameService.getGameById(widget.gameId);
    _picksStream = _gameService.watchPicks(widget.gameId);
    _accessFuture = _loadBoardAccess();
  }

  Future<_BoardAccess> _loadBoardAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final playerName = prefs.getString('player_name');
    final isAdmin = AuthService.isInitialized
        ? await AuthService.isCurrentUserAdmin()
        : false;
    return _BoardAccess(isAdmin: isAdmin, playerName: playerName);
  }

  Pick? _findPick(Iterable<Pick> picks, int number, PickTeam team) {
    for (final pick in picks) {
      if (pick.number == number && pick.team == team) return pick;
    }
    return null;
  }

  Future<void> _refreshGame() async {
    try {
      final refreshedGame = await _gameService.getGameById(widget.gameId);
      if (!mounted) return;
      setState(() => _gameFuture = Future.value(refreshedGame));
    } catch (_) {
      // The live pick stream remains usable if the status refresh briefly fails.
    }
  }

  Future<void> _endDraw({required bool isFull}) async {
    final isAdmin = await AuthService.isCurrentUserAdmin();
    if (!mounted) return;
    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can end a draw.')),
      );
      return;
    }

    if (!isFull) {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('End this draw?'),
              content: const Text(
                'No more players will be able to draw a ticket.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('End draw'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed || !mounted) return;
    }

    setState(() => _updatingStatus = true);
    try {
      await Supabase.instance.client.rpc(
        'close_game',
        params: {
          'p_game_id': widget.gameId,
          'p_status': isFull ? 'complete' : 'closed',
        },
      );
      final updatedGame = await _gameService.getGameById(widget.gameId);

      if (!mounted) return;
      setState(() {
        _gameFuture = Future.value(updatedGame);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Draw ${isFull ? 'completed' : 'closed'} successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not end the draw: $e')));
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _printBoard(Game game, List<Pick> picks) async {
    final home = picks.where((p) => p.team == PickTeam.home).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final away = picks.where((p) => p.team == PickTeam.away).toList()
      ..sort((a, b) => a.number.compareTo(b.number));

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: pdf.PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          pw.Widget teamTable(
            String teamName,
            List<Pick> teamPicks,
            PickTeam team,
          ) {
            return pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: pdf.PdfColors.blueGrey900,
                    child: pw.Text(
                      teamName,
                      style: pw.TextStyle(
                        color: pdf.PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Table(
                    border: pw.TableBorder.all(
                      color: pdf.PdfColors.blueGrey100,
                      width: 0.5,
                    ),
                    columnWidths: const {0: pw.FixedColumnWidth(42)},
                    children: List.generate(15, (index) {
                      final number = index + 1;
                      final pick = _findPick(teamPicks, number, team);
                      final background = number.isEven
                          ? pdf.PdfColors.blueGrey50
                          : pdf.PdfColors.white;
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(color: background),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: pw.Text(
                              number.toString().padLeft(2, '0'),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            child: pw.Text(
                              pick?.playerName ?? 'Unclaimed',
                              maxLines: 1,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            );
          }

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'FIRST TRY SCORER',
                        style: pw.TextStyle(
                          color: pdf.PdfColors.blueGrey600,
                          fontSize: 9,
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${game.homeTeamName} vs ${game.awayTeamName}',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        DateFormat.yMMMMEEEEd().format(game.matchDate),
                        style: pw.TextStyle(color: pdf.PdfColors.blueGrey700),
                      ),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: pdf.PdfColors.blueGrey50,
                      border: pw.Border.all(color: pdf.PdfColors.blueGrey100),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'JOIN CODE  ${game.joinCode}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Status: ${game.status.toUpperCase()}  |  Tickets drawn: ${picks.length}/$totalGameSlots',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  teamTable(game.homeTeamName, home, PickTeam.home),
                  pw.SizedBox(width: 18),
                  teamTable(game.awayTeamName, away, PickTeam.away),
                ],
              ),
              pw.Spacer(),
              pw.Divider(color: pdf.PdfColors.blueGrey200),
              pw.Text(
                'Generated ${DateFormat.yMMMd().add_jm().format(DateTime.now())}',
                style: pw.TextStyle(
                  color: pdf.PdfColors.blueGrey600,
                  fontSize: 8,
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  Future<void> _printJoinQr(Game game) async {
    try {
      final joinUri = gameJoinUri(Uri.base, game.joinCode);
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (_) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'FIRST TRY SCORER',
                  style: pw.TextStyle(
                    color: pdf.PdfColors.blueGrey600,
                    fontSize: 12,
                    letterSpacing: 2,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  '${game.homeTeamName} vs ${game.awayTeamName}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  DateFormat.yMMMMEEEEd().format(game.matchDate),
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.SizedBox(height: 28),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: joinUri.toString(),
                  width: 230,
                  height: 230,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Scan to open this game',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'If the QR code does not scan, enter this join code in the app:',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  game.joinCode,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.Text(
                  'Direct link: ${joinUri.toString()}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not print the game QR code: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Game>(
      future: _gameFuture,
      builder: (context, gameSnapshot) {
        if (gameSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Could not load game: ${gameSnapshot.error}'),
            ),
          );
        }
        if (!gameSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final game = gameSnapshot.data!;
        return FutureBuilder<_BoardAccess>(
          future: _accessFuture,
          builder: (context, accessSnapshot) {
            if (accessSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Game Board')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      'Could not verify board access. Check that the profiles table and its read policy are set up in Supabase.\n\n${accessSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            if (!accessSnapshot.hasData) {
              return Scaffold(
                appBar: AppBar(title: Text('Game Board')),
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final access = accessSnapshot.data!;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Game Board'),
                actions: access.isAdmin
                    ? [
                        IconButton(
                          icon: const Icon(Icons.qr_code_2),
                          tooltip: 'Print join QR code',
                          onPressed: () => _printJoinQr(game),
                        ),
                        IconButton(
                          icon: const Icon(Icons.print),
                          tooltip: 'Print PDF',
                          onPressed: () => _printBoard(game, _latestPicks),
                        ),
                        if (game.status == 'open')
                          IconButton(
                            icon: const Icon(Icons.stop_circle_outlined),
                            tooltip: 'End draw',
                            onPressed: _updatingStatus
                                ? null
                                : () => _endDraw(isFull: false),
                          ),
                      ]
                    : null,
              ),
              body: StreamBuilder<List<Pick>>(
                stream: _picksStream,
                builder: (context, picksSnapshot) {
                  if (picksSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SelectableText(
                          'Could not load allocated tickets. Check the picks table SELECT policy and Realtime setup in Supabase.\n\n${picksSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  if (!picksSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final picks = picksSnapshot.data!;
                  _latestPicks = picks;
                  final drawnCount = picks.length;
                  final slotsTotal = totalGameSlots;

                  if (game.status == 'open' &&
                      drawnCount >= totalGameSlots &&
                      !_autoCloseStarted) {
                    _autoCloseStarted = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _refreshGame();
                    });
                  }

                  if (!access.isAdmin) {
                    Pick? myPick;
                    final inputName = access.playerName?.trim().toLowerCase();
                    if (inputName != null && inputName.isNotEmpty) {
                      for (final pick in picks) {
                        if (pick.playerName.trim().toLowerCase() == inputName) {
                          myPick = pick;
                          break;
                        }
                      }
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Tickets drawn: $drawnCount/$slotsTotal',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: myPick == null
                                      ? const Text(
                                          'Your seat has not been assigned yet.',
                                          textAlign: TextAlign.center,
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Your ticket',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${myPick.team == PickTeam.home ? game.homeTeamName : game.awayTeamName} #${myPick.number}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.headlineSmall,
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                              if (AuthService.currentUser != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'This account is signed in but is not marked as an admin. In Supabase, set profiles.is_admin to true for this user, then sign out and back in.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final homePicks = {
                    for (final p in picks.where((p) => p.team == PickTeam.home))
                      p.number: p,
                  };
                  final awayPicks = {
                    for (final p in picks.where((p) => p.team == PickTeam.away))
                      p.number: p,
                  };

                  return Column(
                    children: [
                      _GameHeader(
                        game: game,
                        showShareHint: widget.justCreated,
                        isAdmin: access.isAdmin,
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Tickets drawn: $drawnCount/$slotsTotal',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _TeamColumn(
                                teamName: game.homeTeamName,
                                picksByNumber: homePicks,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: _TeamColumn(
                                teamName: game.awayTeamName,
                                picksByNumber: awayPicks,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _GameHeader extends StatelessWidget {
  final Game game;
  final bool showShareHint;
  final bool isAdmin;

  const _GameHeader({
    required this.game,
    required this.showShareHint,
    required this.isAdmin,
  });

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
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text('Status: ${game.status.toUpperCase()}'),
            backgroundColor: game.status == 'open'
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.secondaryContainer,
          ),
          if (showShareHint) ...[
            const SizedBox(height: 8),
            Text(
              'Share this code so everyone can join and draw.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (isAdmin && game.status == 'open') ...[
            const SizedBox(height: 8),
            Text(
              'Admin controls are available in the top bar.',
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
                  backgroundColor: taken
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  foregroundColor: taken
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
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
