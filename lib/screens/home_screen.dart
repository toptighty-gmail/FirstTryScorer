import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'admin_sign_in_screen.dart';
import 'history_screen.dart';
import 'join_game_screen.dart';
import 'new_game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<AuthState>? _authStateSubscription;

  bool _loading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    if (AuthService.isInitialized) {
      _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
          .listen((event) {
            if (mounted) {
              _refreshAdminStatus();
            }
          });
    }
    _refreshAdminStatus();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshAdminStatus() async {
    if (!AuthService.isInitialized) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isAdmin = false;
        });
      }
      return;
    }

    final isAdmin = await AuthService.isCurrentUserAdmin();
    if (mounted) {
      setState(() {
        _loading = false;
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) {
      setState(() {
        _loading = true;
      });
      await _refreshAdminStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('First Try Scorer')),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'Assets/PlymstockOaksLogo.png',
                        width: 144,
                        height: 144,
                        fit: BoxFit.contain,
                        semanticLabel: 'Plymstock Oaks RFC logo',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'First Try Scorer',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Developed by Sean Cook',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (user == null) ...[
                        const Text('Admin sign in required to create games.'),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Admin Sign In'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminSignInScreen(),
                            ),
                          ),
                        ),
                      ] else if (!_isAdmin) ...[
                        Text('Signed in as ${user.email ?? 'admin'}'),
                        const SizedBox(height: 8),
                        const Text('Admin access is required to create games.'),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                          onPressed: _signOut,
                        ),
                      ] else ...[
                        Text('Signed in as ${user.email ?? 'admin'}'),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('New Game'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NewGameScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.logout),
                          label: const Text('Sign out'),
                          onPressed: _signOut,
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Join Game'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const JoinGameScreen(),
                          ),
                        ),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.history),
                          label: const Text('History'),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HistoryScreen(),
                            ),
                          ),
                        ),
                      ],
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
