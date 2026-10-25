import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'game_waiting_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  SinglePlayerSetup
//  Step 0 : Browse single-player games
//  Step 1 : Pick your player slot (pre-defined by admin)
// ═══════════════════════════════════════════════════════════════
class SinglePlayerSetup extends StatefulWidget {
  const SinglePlayerSetup({super.key});

  @override
  State<SinglePlayerSetup> createState() => _SinglePlayerSetupState();
}

class _SinglePlayerSetupState extends State<SinglePlayerSetup> {
  // ── Step 0 — game list ────────────────────────────────────────
  List   _games        = [];
  bool   _loadingGames = true;
  bool   _errorGames   = false;
  Timer? _refresh;

  // ── Step 1 — player selection ─────────────────────────────────
  int     _step             = 0;
  Map?    _selectedGame;
  List    _teams            = [];  // teams with nested players
  bool    _loadingTeams     = false;
  bool    _joining          = false;

  @override
  void initState() {
    super.initState();
    _loadGames();
    _refresh = Timer.periodic(
        const Duration(seconds: 12), (_) { if (_step == 0) _loadGames(); });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  // ── Load game list ────────────────────────────────────────────
  Future<void> _loadGames() async {
    if (!mounted) return;
    setState(() { _loadingGames = true; _errorGames = false; });
    try {
      final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}get_games.php?status=waiting'));
      if (!mounted) return;
      final all = List.from(jsonDecode(res.body));
      final single = all.where((g) =>
          (g['game_mode'] ?? '').toString().toLowerCase() == 'single')
          .toList();
      setState(() { _games = single; _loadingGames = false; });
    } catch (_) {
      if (mounted) setState(() { _loadingGames = false; _errorGames = true; });
    }
  }

  // ── Select a game → load its teams/players ────────────────────
  Future<void> _selectGame(Map game) async {
    setState(() {
      _selectedGame  = game;
      _step          = 1;
      _loadingTeams  = true;
      _teams         = [];
    });
    try {
      final res = await http.get(
          Uri.parse(
              '${ApiConfig.baseUrl}get_game_state.php?game_id=${game['game_id']}'));
      if (!mounted) return;
      final data = jsonDecode(res.body);
      setState(() {
        _teams        = List.from(data['teams'] ?? []);
        _loadingTeams = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTeams = false);
    }
  }

  // ── Join: mark this pre-defined team as ready ─────────────────
  Future<void> _joinAsTeam(Map team) async {
    if (_joining || _selectedGame == null) return;
    setState(() => _joining = true);
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}set_team_ready.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'game_id': _selectedGame!['game_id'].toString(),
          'team_id': team['team_id'].toString(),
        },
      );
      if (!mounted) return;
      _refresh?.cancel();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameWaitingScreen(
            gameId:   int.parse(_selectedGame!['game_id'].toString()),
            teamId:   int.parse(team['team_id'].toString()),
            teamName: team['team_name'].toString(),
            gameName: _selectedGame!['game_name'].toString(),
            gameMode: 'single',
          ),
        ),
      );
    } catch (_) {
      _snack('Network error — check connection');
    }
    if (mounted) setState(() => _joining = false);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.bgSurface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: _step == 0 ? _buildGameList() : _buildPlayerSelect(),
        ),
      ),
    );
  }

  // ── Step 0: Game list ─────────────────────────────────────────
  Widget _buildGameList() {
    return Column(
      children: [
        AppHeader(
          title: 'Single Player',
          subtitle: 'Choose your game',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.purple.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_rounded, size: 14, color: AppColors.purple),
                SizedBox(width: 5),
                Text('Solo',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.purple)),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loadingGames
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.purple))
              : _errorGames
                  ? _errorView()
                  : _games.isEmpty
                      ? _emptyView()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          itemCount: _games.length,
                          itemBuilder: (_, i) => _SPGameCard(
                            game: _games[i],
                            onTap: () => _selectGame(_games[i] as Map),
                          ),
                        ),
        ),
      ],
    );
  }

  // ── Step 1: Ready screen — shows team name + I'M READY button ──
  Widget _buildPlayerSelect() {
    final gameName = _selectedGame?['game_name']?.toString() ?? '';
    final team     = _teams.isNotEmpty ? _teams[0] as Map : null;

    return Column(
      children: [
        AppHeader(
          title: 'Ready?',
          subtitle: gameName,
          trailing: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => setState(() {
              _step = 0;
              _selectedGame = null;
              _teams = [];
            }),
          ),
        ),
        if (_joining)
          const LinearProgressIndicator(color: AppColors.purple),
        Expanded(
          child: _loadingTeams
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.purple))
              : team == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🤔', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          const Text('No team found for this game.',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16)),
                          const SizedBox(height: 4),
                          const Text('Ask your teacher to set it up.',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh,
                                color: AppColors.purple),
                            label: const Text('Refresh',
                                style: TextStyle(color: AppColors.purple)),
                            onPressed: () => _selectGame(_selectedGame!),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Team name card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: AppColors.bgCard,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: AppColors.purple.withOpacity(0.3),
                                  width: 1.5),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 64, height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.purple.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.groups_rounded,
                                      color: AppColors.purple, size: 32),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  team['team_name']?.toString() ?? '',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  gameName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Ready button
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              label: "I'M READY",
                              icon: Icons.play_arrow_rounded,
                              onTap: () { if (!_joining) _joinAsTeam(team!); },
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          const Text('Could not load games.',
              style: TextStyle(color: Colors.white, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: _loadGames),
        ]),
      );

  Widget _emptyView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎮', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('No games available',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('Ask your teacher to create a\nSingle Player game.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          TextButton.icon(
            icon: const Icon(Icons.refresh, color: AppColors.purple),
            label: const Text('Refresh',
                style: TextStyle(color: AppColors.purple)),
            onPressed: _loadGames,
          ),
        ]),
      );
}

// ─── Game Card (step 0) ───────────────────────────────────────
class _SPGameCard extends StatelessWidget {
  final dynamic game;
  final VoidCallback? onTap;
  const _SPGameCard({required this.game, this.onTap});

  @override
  Widget build(BuildContext context) {
    final sched = game['scheduled_at'];
    String? schedStr;
    if (sched != null && sched.toString().isNotEmpty) {
      try {
        final d = DateTime.parse(sched.toString().replaceFirst(' ', 'T'));
        schedStr =
            '${d.day}/${d.month}/${d.year}  '
            '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    final teams = List.from(game['teams'] ?? []);

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
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('SOLO',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.purple)),
              ),
              const Spacer(),
              const Icon(Icons.play_circle_outline_rounded,
                  color: AppColors.purple, size: 22),
            ]),
            const SizedBox(height: 8),
            Text(game['game_name']?.toString() ?? '',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
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
            Row(children: [
              _meta(Icons.quiz_rounded,
                  '${game['question_count']} questions'),
              const SizedBox(width: 12),
              _meta(Icons.timer_rounded,
                  '${game['game_duration']}s / question'),
              if (teams.isNotEmpty) ...[
                const SizedBox(width: 12),
                _meta(Icons.people_outline_rounded,
                    '${teams.length} player${teams.length == 1 ? '' : 's'}'),
              ],
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.purple.withOpacity(0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 14, color: AppColors.purple),
                  SizedBox(width: 6),
                  Text('Tap to see players',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.purple,
                          fontWeight: FontWeight.w600)),
                ],
              ),
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

// ─── Team / Player Card (step 1) ──────────────────────────────
class _TeamPlayerCard extends StatelessWidget {
  final dynamic team;
  final VoidCallback? onTap;
  const _TeamPlayerCard({required this.team, this.onTap});

  @override
  Widget build(BuildContext context) {
    final players   = List.from(team['players'] ?? []);
    final schoolName = (team['school_name'] ?? '').toString();
    final isReady   = (team['is_ready'] ?? 0).toString() == '1';

    return GestureDetector(
      onTap: isReady ? null : onTap,
      child: Opacity(
        opacity: (isReady || onTap == null) ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isReady
                  ? AppColors.correct.withOpacity(0.4)
                  : AppColors.purple.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Team header ─────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                decoration: BoxDecoration(
                  color: isReady
                      ? AppColors.correct.withOpacity(0.08)
                      : AppColors.purple.withOpacity(0.08),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReady
                            ? AppColors.correct.withOpacity(0.15)
                            : AppColors.purple.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Icon(
                          isReady
                              ? Icons.check_circle_rounded
                              : Icons.person_rounded,
                          size: 18,
                          color: isReady
                              ? AppColors.correct
                              : AppColors.purple,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team['team_name']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                          if (schoolName.isNotEmpty)
                            Text(schoolName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (isReady)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.correct.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('READY',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppColors.correct)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.touch_app_rounded,
                                size: 12, color: AppColors.purple),
                            SizedBox(width: 4),
                            Text('Play',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.purple)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Players list ────────────────────────────────
              if (players.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    children: players.map<Widget>((p) {
                      final pSchool =
                          (p['school_name'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Center(
                                child: Icon(Icons.person_outline,
                                    size: 13,
                                    color: AppColors.textMuted),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p['player_name']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (pSchool.isNotEmpty)
                              Text(pSchool,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.gold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
