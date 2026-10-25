import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'game_waiting_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  GameLobbyScreen
//  Student picks a game → picks their team → clicks "I'M READY"
// ═══════════════════════════════════════════════════════════════
class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  List   _games    = [];
  bool   _loading  = true;
  bool   _error    = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _loadGames();
    // Auto-refresh every 12 seconds
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 12), (_) => _loadGames());
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _loadGames() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = false; });
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}get_games.php?status=waiting'),
      );
      if (!mounted) return;
      final all = List.from(jsonDecode(res.body));
      // Only show multiplayer-mode games in this lobby
      final multi = all.where((g) {
        final mode = (g['game_mode'] ?? '').toString().toLowerCase();
        return mode != 'single';
      }).toList();
      setState(() {
        _games   = multi;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  // ── Pick game → show team sheet ───────────────────────────────
  void _openGame(Map game) {
    final teams = List<Map>.from(game['teams'] ?? []);
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No teams in this game yet.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _TeamPickerSheet(
        game: game,
        teams: teams,
        onPick: (team) => _joinTeam(game, team),
      ),
    );
  }

  // ── Join team → ready → waiting ───────────────────────────────
  Future<void> _joinTeam(Map game, Map team) async {
    Navigator.pop(context); // close bottom sheet

    // Mark team as ready on server
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}set_team_ready.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'game_id': game['game_id'].toString(),
          'team_id': team['team_id'].toString(),
        },
      );
    } catch (_) {
      // Continue even if this fails — polling will sync
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameWaitingScreen(
          gameId:   int.parse(game['game_id'].toString()),
          teamId:   int.parse(team['team_id'].toString()),
          teamName: team['team_name'].toString(),
          gameName: game['game_name'].toString(),
          gameMode: 'multi',
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppHeader(
                title: 'Choose Your Game',
                subtitle: 'Select the game your team is in',
                trailing: IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 22),
                  onPressed: _loadGames,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.purple))
                    : _error
                        ? _errorView()
                        : _games.isEmpty
                            ? _emptyView()
                            : _gameList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('⚠️', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text('Could not load games.',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 6),
        const Text('Check your WiFi connection.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
          onPressed: _loadGames,
        ),
      ],
    ),
  );

  Widget _emptyView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎮', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        const Text('No games available',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Ask your teacher to create a game.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 20),
        TextButton.icon(
          icon: const Icon(Icons.refresh, color: AppColors.purple),
          label: const Text('Refresh',
              style: TextStyle(color: AppColors.purple)),
          onPressed: _loadGames,
        ),
      ],
    ),
  );

  Widget _gameList() => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    itemCount: _games.length,
    itemBuilder: (_, i) => _GameCard(
      game: _games[i],
      onTap: () => _openGame(_games[i]),
    ),
  );
}

// ─── Game Card ────────────────────────────────────────────────
class _GameCard extends StatelessWidget {
  final Map game;
  final VoidCallback onTap;

  const _GameCard({required this.game, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final teams = List<Map>.from(game['teams'] ?? []);
    final sched = game['scheduled_at'];
    String? schedStr;
    if (sched != null && sched.toString().isNotEmpty) {
      try {
        final d = DateTime.parse(sched.toString().replaceFirst(' ', 'T'));
        schedStr =
            '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
      } catch (_) {}
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + arrow
            Row(children: [
              Expanded(
                child: Text(
                  game['game_name']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 22),
            ]),

            if (schedStr != null) ...[
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: Color(0xFF38BDF8)),
                const SizedBox(width: 4),
                Text(schedStr,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.w600)),
              ]),
            ],

            const SizedBox(height: 8),

            // Meta
            Row(children: [
              _meta(Icons.quiz_rounded,
                  '${game['question_count']} questions'),
              const SizedBox(width: 12),
              _meta(Icons.timer_rounded,
                  '${game['game_duration']}s / question'),
            ]),

            const SizedBox(height: 10),

            // Teams
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: teams
                  .map((t) => _TeamPill(name: t['team_name'].toString()))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.textMuted),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textMuted)),
    ],
  );
}

// ─── Team Pill ────────────────────────────────────────────────
class _TeamPill extends StatelessWidget {
  final String name;
  const _TeamPill({required this.name});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.purple.withOpacity(0.18),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.purple.withOpacity(0.35)),
    ),
    child: Text(name,
        style: const TextStyle(
            fontSize: 12,
            color: AppColors.purple,
            fontWeight: FontWeight.w700)),
  );
}

// ─── Team Picker Sheet ────────────────────────────────────────
class _TeamPickerSheet extends StatelessWidget {
  final Map game;
  final List<Map> teams;
  final void Function(Map team) onPick;

  const _TeamPickerSheet({
    required this.game,
    required this.teams,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(game['game_name']?.toString() ?? '',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Pick your team',
              style: TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 20),

          ...teams.map((t) => GestureDetector(
            onTap: () => onPick(t),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.purple.withOpacity(0.25)),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.groups_rounded,
                      color: AppColors.purple, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    t['team_name'].toString(),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ]),
            ),
          )),
        ],
      ),
    );
  }
}
