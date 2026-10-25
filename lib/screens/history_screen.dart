import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

// ═══════════════════════════════════════════════════════════════
//  HistoryScreen
// ═══════════════════════════════════════════════════════════════
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _baseUrl = 'http://liuquiz.atwebpages.com/';

  List _history = [];
  bool _loading  = true;
  bool _error    = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final res = await http.get(Uri.parse('${_baseUrl}history.php'));
      if (!mounted) return;
      setState(() {
        _history = jsonDecode(res.body);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All History?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text(
            'This will permanently delete all game results and scores. This cannot be undone.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CLEAR ALL',
                style: TextStyle(
                    color: AppColors.wrong,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      final res = await http.post(
          Uri.parse('${_baseUrl}clear_history.php'));
      final data = jsonDecode(res.body);
      if (!mounted) return;
      if (data['status'] == 'success') {
        setState(() { _history = []; _clearing = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('History cleared'),
            backgroundColor: AppColors.bgSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        setState(() => _clearing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Failed to clear'),
            backgroundColor: AppColors.wrong,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Game History',
                subtitle: 'All past game results',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // refresh
                    GestureDetector(
                      onTap: _loading ? null : _load,
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.refresh,
                            size: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // clear history
                    GestureDetector(
                      onTap: (_clearing || _history.isEmpty) ? null : _clearHistory,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _history.isEmpty
                              ? Colors.white.withOpacity(0.04)
                              : AppColors.wrong.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _history.isEmpty
                                ? Colors.transparent
                                : AppColors.wrong.withOpacity(0.35),
                          ),
                        ),
                        child: _clearing
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.wrong),
                              )
                            : Icon(Icons.delete_sweep_outlined,
                                size: 18,
                                color: _history.isEmpty
                                    ? AppColors.textMuted
                                    : AppColors.wrong),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.purple));
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('❌', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            const Text('Failed to load history',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📋', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No games played yet',
                style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: _history.length,
      itemBuilder: (_, i) {
        final g = _history[i];
        final isMulti = g['game_mode'] == 'multi';
        return GestureDetector(
          onTap: () => _showDetail(g),
          child: isMulti ? _MultiCard(g: g) : _SingleCard(g: g),
        );
      },
    );
  }

  void _showDetail(Map g) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(g: g),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

List _players(Map g) => (g['players'] as List? ?? []);

String _formatDate(String? raw) {
  if (raw == null || raw == '—') return '—';
  try {
    final dt = DateTime.parse(raw);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year}  $h:$m';
  } catch (_) {
    return raw;
  }
}

// ── Single-player card ────────────────────────────────────────
class _SingleCard extends StatelessWidget {
  final Map g;
  const _SingleCard({required this.g});

  @override
  Widget build(BuildContext context) {
    final players  = _players(g);
    final player   = players.isNotEmpty ? players.first : null;
    final name     = player?['player_name'] ?? g['winner_name'] ?? '—';
    final score    = player?['score'] ?? g['top_score'] ?? 0;
    final total    = g['total_questions'] ?? 0;
    final cat      = g['category_name'];
    final date     = _formatDate(g['started_at'] ?? g['game_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🎮', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _ModePill(label: 'SOLO', color: AppColors.purple),
                  if (cat != null && cat != '—') ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(cat,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
                const SizedBox(height: 5),
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$score',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.purple)),
              Text('/ $total',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Multiplayer card ──────────────────────────────────────────
class _MultiCard extends StatelessWidget {
  final Map g;
  const _MultiCard({required this.g});

  @override
  Widget build(BuildContext context) {
    final players = _players(g);
    final total   = g['total_questions'] ?? 0;
    final date    = _formatDate(g['started_at'] ?? g['game_date']);

    // split into two sides by is_winner order (winner first from PHP ORDER BY)
    final p1 = players.isNotEmpty ? players[0] : null;
    final p2 = players.length > 1 ? players[1] : null;

    final name1  = p1?['team_name'] ?? p1?['player_name'] ?? '—';
    final score1 = p1?['score'] ?? 0;
    final win1   = (p1?['is_winner'] ?? 0) == 1;

    final name2  = p2?['team_name'] ?? p2?['player_name'] ?? '—';
    final score2 = p2?['score'] ?? 0;
    final win2   = (p2?['is_winner'] ?? 0) == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── header row ─────────────────────────────────────
          Row(
            children: [
              _ModePill(label: 'MULTI', color: AppColors.pink),
              const SizedBox(width: 6),
              Expanded(
                child: Text(date,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 10),
          // ── score row ──────────────────────────────────────
          Row(
            children: [
              // Team A
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (win1)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text('🏆',
                              style: TextStyle(fontSize: 12)),
                        ),
                      Flexible(
                        child: Text(name1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: win1
                                  ? AppColors.purple
                                  : Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    Text('$score1 pts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: win1
                              ? AppColors.purple
                              : AppColors.textMuted,
                        )),
                  ],
                ),
              ),
              // VS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    const Text('VS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textMuted,
                          letterSpacing: 1.5,
                        )),
                    const SizedBox(height: 2),
                    Text('$total Q',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              // Team B
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(name2,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: win2
                                    ? AppColors.pink
                                    : Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end),
                        ),
                        if (win2)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('🏆',
                                style: TextStyle(fontSize: 12)),
                          ),
                      ],
                    ),
                    Text('$score2 pts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: win2
                              ? AppColors.pink
                              : AppColors.textMuted,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Detail bottom sheet ───────────────────────────────────────
class _DetailSheet extends StatelessWidget {
  final Map g;
  const _DetailSheet({required this.g});

  @override
  Widget build(BuildContext context) {
    final isMulti  = g['game_mode'] == 'multi';
    final players  = _players(g);
    final total    = g['total_questions'] ?? 0;
    final cat      = g['category_name'];
    final date     = _formatDate(g['started_at'] ?? g['game_date']);
    final gameId   = g['game_id'];

    return DraggableScrollableSheet(
      initialChildSize: isMulti ? 0.60 : 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(isMulti ? '⚔️' : '🎮',
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMulti ? 'Multiplayer Match' : 'Single Player Game',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                        Text('Game #$gameId',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: AppColors.border),
            // body
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // meta row
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      _MetaPill(
                          label: isMulti ? 'MULTI' : 'SOLO',
                          color: isMulti ? AppColors.pink : AppColors.purple),
                      if (cat != null && cat != '—')
                        _MetaPill(label: cat, color: AppColors.textMuted),
                      _MetaPill(label: '$total questions',
                          color: AppColors.gold),
                      _MetaPill(label: date, color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (isMulti)
                    _MultiDetail(players: players, total: total)
                  else
                    _SingleDetail(players: players, total: total),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single detail body ────────────────────────────────────────
class _SingleDetail extends StatelessWidget {
  final List players;
  final int total;
  const _SingleDetail({required this.players, required this.total});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Text('No player data',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    final p      = players.first;
    final name   = p['team_name'] ?? p['player_name'] ?? '—';
    final school = (p['school_name'] ?? '').toString();
    final score  = p['score'] ?? 0;
    final pct    = total > 0 ? score / total : 0.0;

    Color pctColor;
    String msg;
    if (pct >= 0.7) {
      pctColor = AppColors.correct;
      msg = 'Excellent! 🔥';
    } else if (pct >= 0.4) {
      pctColor = AppColors.gold;
      msg = 'Good Job 👍';
    } else {
      pctColor = AppColors.wrong;
      msg = 'Keep Practicing 💪';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PLAYER',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 0.5)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.purple.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(Icons.person, color: AppColors.purple, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    if (school.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(school,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.gold)),
                    ],
                    const SizedBox(height: 2),
                    Text(msg,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pctColor)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$score',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: pctColor,
                          height: 1)),
                  Text('/ $total',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct.toDouble(),
            minHeight: 10,
            backgroundColor: AppColors.bgSurface,
            valueColor: AlwaysStoppedAnimation<Color>(pctColor),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(pct * 100).toStringAsFixed(0)}% accuracy',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: pctColor)),
      ],
    );
  }
}

// ── Multiplayer detail body ───────────────────────────────────
class _MultiDetail extends StatelessWidget {
  final List players;
  final int total;
  const _MultiDetail({required this.players, required this.total});

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Text('No player data',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final p1 = players[0];
    final p2 = players.length > 1 ? players[1] : null;

    final name1  = p1['team_name'] ?? p1['player_name'] ?? '—';
    final pname1 = p1['player_name'] ?? '—';
    final score1 = p1['score'] ?? 0;
    final win1   = (p1['is_winner'] ?? 0) == 1;

    final name2  = p2?['team_name'] ?? p2?['player_name'] ?? '—';
    final pname2 = p2?['player_name'] ?? '—';
    final score2 = p2?['score'] ?? 0;
    final win2   = (p2?['is_winner'] ?? 0) == 1;

    final draw = !win1 && !win2;

    return Column(
      children: [
        // winner banner
        if (!draw)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: (win1 ? AppColors.purple : AppColors.pink)
                  .withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: (win1 ? AppColors.purple : AppColors.pink)
                      .withOpacity(0.35)),
            ),
            child: Center(
              child: Text(
                '🏆  ${win1 ? name1 : name2} Wins!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: win1 ? AppColors.purple : AppColors.pink,
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
            ),
            child: const Center(
              child: Text("🤝  It's a Draw!",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.gold)),
            ),
          ),

        // team cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TeamDetailCard(
                teamName:   name1,
                playerName: pname1,
                score:      score1,
                total:      total,
                color:      AppColors.purple,
                winner:     win1,
              ),
            ),
            const SizedBox(width: 12),
            if (p2 != null)
              Expanded(
                child: _TeamDetailCard(
                  teamName:   name2,
                  playerName: pname2,
                  score:      score2,
                  total:      total,
                  color:      AppColors.pink,
                  winner:     win2,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TeamDetailCard extends StatelessWidget {
  final String teamName;
  final String playerName;
  final int score;
  final int total;
  final Color color;
  final bool winner;

  const _TeamDetailCard({
    required this.teamName,
    required this.playerName,
    required this.score,
    required this.total,
    required this.color,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? score / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: winner ? color.withOpacity(0.45) : Colors.white.withOpacity(0.07),
          width: winner ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(teamName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: winner ? color : Colors.white),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(playerName,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('$score',
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: winner ? color : Colors.white,
                  height: 1)),
          Text('/ $total',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                  winner ? color : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────
class _ModePill extends StatelessWidget {
  final String label;
  final Color color;
  const _ModePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 1)),
      );
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;
  const _MetaPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}
