import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

// ═══════════════════════════════════════════════════════════════
//  ControllerScreen
//  Teacher's game control panel.
//  View 1: game list → pick a game
//  View 2: control panel (team readiness → start → questions)
// ═══════════════════════════════════════════════════════════════
class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  // ── game list ─────────────────────────────────────────────────
  List _games      = [];
  bool _loadingList = true;

  // ── selected game ─────────────────────────────────────────────
  Map?   _selectedGame;
  String _status       = 'waiting';
  List   _teams        = [];
  Map    _question     = {};
  int    _qIdx         = 0;
  int    _total        = 0;
  int?   _buzzedTeamId;
  String _buzzedTeamName = '';
  int    _duration     = 30;
  String? _questionStartedAt;
  int    _timeLeft     = 0;

  // ── action loading ────────────────────────────────────────────
  bool _acting = false;

  // ── poll ──────────────────────────────────────────────────────
  Timer? _poll;
  Timer? _timerTick;

  @override
  void initState() {
    super.initState();
    _loadGameList();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _timerTick?.cancel();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════
  //  GAME LIST
  // ══════════════════════════════════════════════════════════════
  Future<void> _loadGameList() async {
    if (!mounted) return;
    setState(() => _loadingList = true);
    try {
      final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}get_games.php?status=all'));
      if (!mounted) return;
      setState(() { _games = jsonDecode(res.body); _loadingList = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  void _selectGame(Map game) {
    setState(() {
      _selectedGame = game;
      _status       = 'waiting';
    });
    _startPoll();
  }

  void _backToList() {
    _poll?.cancel();
    _timerTick?.cancel();
    setState(() { _selectedGame = null; });
    _loadGameList();
  }

  // ══════════════════════════════════════════════════════════════
  //  POLLING
  // ══════════════════════════════════════════════════════════════
  void _startPoll() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(milliseconds: 1000), (_) => _fetchState());
    _fetchState();
  }

  Future<void> _fetchState() async {
    if (!mounted || _selectedGame == null) return;
    try {
      final id  = _selectedGame!['game_id'];
      final res = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}get_game_state.php?game_id=$id'));
      if (!mounted) return;
      final d = jsonDecode(res.body) as Map;
      final st     = d['status']?.toString() ?? 'waiting';
      final newIdx = int.tryParse(d['current_question_idx'].toString()) ?? 0;
      final newQ   = newIdx != _qIdx;

      setState(() {
        _status         = st;
        _teams          = List.from(d['teams'] ?? []);
        _qIdx           = newIdx;
        _total          = int.tryParse(d['total_questions'].toString()) ?? 0;
        _question       = Map.from(d['question'] ?? {});
        _buzzedTeamId   = d['buzzed_team_id'] != null
            ? int.tryParse(d['buzzed_team_id'].toString()) : null;
        _buzzedTeamName = d['buzzed_team_name']?.toString() ?? '';
        _duration       = int.tryParse(d['game_duration'].toString()) ?? 30;
        _questionStartedAt = d['question_started_at']?.toString();
      });

      if ((st == 'active') && newQ) _startLocalTimer();
    } catch (_) {}
  }

  void _startLocalTimer() {
    _timerTick?.cancel();
    int rem = _duration;
    if (_questionStartedAt != null && _questionStartedAt!.isNotEmpty) {
      try {
        final started = DateTime.parse(
            _questionStartedAt!.replaceFirst(' ', 'T') + 'Z');
        final elapsed = DateTime.now().toUtc().difference(started).inSeconds;
        rem = (_duration - elapsed).clamp(0, _duration);
      } catch (_) {}
    }
    setState(() => _timeLeft = rem);
    _timerTick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft = (_timeLeft - 1).clamp(0, _duration));
      if (_timeLeft <= 0) t.cancel();
    });
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════════════════════════════
  Future<void> _action(String action, [Map<String, dynamic>? extra]) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      final body = <String, String>{
        'game_id': _selectedGame!['game_id'].toString(),
        'action': action,
      };
      if (extra != null) {
        extra.forEach((k, v) => body[k] = v.toString());
      }

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}update_game_status.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );
      await _fetchState();
    } catch (_) {
      _toast('Network error', isErr: true);
    }
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _markAnswer(int isCorrect) async {
    if (_acting) return;
    setState(() => _acting = true);
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}mark_answer.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'game_id':    _selectedGame!['game_id'].toString(),
          'is_correct': isCorrect.toString(),
          'points':     '10',
        },
      );
      await _fetchState();
    } catch (_) {
      _toast('Network error', isErr: true);
    }
    if (mounted) setState(() => _acting = false);
  }

  Future<void> _nextQuestion() async {
    if (_acting) return;
    setState(() => _acting = true);
    _timerTick?.cancel();
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}next_question.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'game_id': _selectedGame!['game_id'].toString()},
      );
      await _fetchState();
    } catch (_) {
      _toast('Network error', isErr: true);
    }
    if (mounted) setState(() => _acting = false);
  }

  void _toast(String msg, {bool isErr = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isErr ? AppColors.wrongBg : AppColors.bgSurface,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: _selectedGame == null ? _buildList() : _buildPanel(),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  GAME LIST VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppHeader(
        title: 'Controller',
        subtitle: 'Select a game to manage',
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded,
              color: Colors.white, size: 22),
          onPressed: _loadGameList,
        ),
      ),
      const SizedBox(height: 16),
      if (_loadingList)
        const Expanded(child: Center(
            child: CircularProgressIndicator(color: AppColors.purple)))
      else if (_games.isEmpty)
        const Expanded(child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('🎮', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('No games found.',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            SizedBox(height: 6),
            Text('Create one in the Admin panel.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ]),
        ))
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: _games.length,
            itemBuilder: (_, i) {
              final g      = _games[i];
              final status = g['status']?.toString() ?? 'waiting';
              final teams  = List<Map>.from(g['teams'] ?? []);
              return GestureDetector(
                onTap: () => _selectGame(g),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.07)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g['game_name']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            '${g['question_count']} questions  ·  '
                            'Teams: ${teams.map((t) => t['team_name']).join(', ')}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusPill(status: status),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                  ]),
                ),
              );
            },
          ),
        ),
    ],
  );

  // ══════════════════════════════════════════════════════════════
  //  CONTROL PANEL VIEW
  // ══════════════════════════════════════════════════════════════
  Widget _buildPanel() => Column(
    children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
        child: Row(children: [
          GestureDetector(
            onTap: _backToList,
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_selectedGame!['game_name']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                Text('Q ${_qIdx + 1} / $_total  ·  $_status',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          _StatusPill(status: _status),
        ]),
      ),

      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_status == 'waiting')   _buildWaitingView(),
              if (_status == 'finished')  _buildFinishedView(),
              if (_status == 'active' ||
                  _status == 'buzzer_locked' ||
                  _status == 'showing_result') ...[
                _buildQuestionCard(),
                const SizedBox(height: 16),
                _buildTeamScores(),
                const SizedBox(height: 16),
                _buildControls(),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  // ── Waiting view ──────────────────────────────────────────────
  Widget _buildWaitingView() {
    final isSingle = (_selectedGame?['game_mode'] ?? 'multi')
        .toString().toLowerCase() == 'single';
    final readyCount = _teams.where((t) =>
        int.tryParse(t['is_ready'].toString()) == 1).length;
    final total    = _teams.length;
    final canStart = isSingle ? readyCount >= 1 : readyCount >= 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Readiness card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(isSingle ? Icons.person_rounded : Icons.groups_rounded,
                    color: AppColors.purple, size: 18),
                const SizedBox(width: 8),
                Text(isSingle ? 'Player Readiness' : 'Team Readiness',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const Spacer(),
                Text('$readyCount / $total ready',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: canStart
                            ? AppColors.correct
                            : AppColors.textMuted)),
              ]),
              const SizedBox(height: 12),
              ..._teams.map((t) {
                final ready = int.tryParse(t['is_ready'].toString()) == 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Icon(
                      ready ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 18,
                      color: ready ? AppColors.correct : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t['team_name'].toString(),
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ready ? Colors.white : AppColors.textMuted)),
                          if (t['school_name'] != null &&
                              t['school_name'].toString().isNotEmpty)
                            Text(t['school_name'].toString(),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.gold)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: ready
                            ? AppColors.correct.withOpacity(0.15)
                            : AppColors.bgSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ready ? '✅ Ready' : '⏳ Waiting',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ready
                                ? AppColors.correct
                                : AppColors.textMuted),
                      ),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Hint
        Text(
          canStart
              ? (isSingle
                  ? '✅ Player is ready — you can start!'
                  : '✅ $readyCount teams ready — you can start!')
              : (isSingle
                  ? 'Wait for the player to press "I\'M READY" on their device.'
                  : 'Wait for at least 2 teams to press "I\'M READY" on their iPads.'),
          style: TextStyle(
              fontSize: 13,
              color: canStart ? AppColors.correct : AppColors.textMuted,
              height: 1.5),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // Start button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text('START GAME',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: canStart ? AppColors.correct : AppColors.bgSurface,
              foregroundColor: canStart ? Colors.white : AppColors.textMuted,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: canStart && !_acting
                ? () => _action('start') : null,
          ),
        ),
      ],
    );
  }

  // ── Question card (controller sees correct answer) ─────────────
  Widget _buildQuestionCard() {
    final opts = [
      MapEntry('A', _question['option_a'] ?? ''),
      MapEntry('B', _question['option_b'] ?? ''),
      MapEntry('C', _question['option_c'] ?? ''),
      MapEntry('D', _question['option_d'] ?? ''),
    ];
    final correct = _question['correct_answer']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(children: [
            Text('Question ${_qIdx + 1}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_status == 'active')
              _CtrlTimer(seconds: _timeLeft, total: _duration),
          ]),
          const SizedBox(height: 12),

          // Buzzer status
          if (_status == 'buzzer_locked' && _buzzedTeamId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt, size: 14, color: AppColors.gold),
                const SizedBox(width: 6),
                Text('$_buzzedTeamName buzzed in!',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.gold)),
              ]),
            ),

          // Question text
          Text(
            _question['question_text']?.toString() ?? '—',
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: 14),

          // Options
          ...opts.map((e) {
            final isCorrect = e.key == correct;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isCorrect
                    ? AppColors.correctBg
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? AppColors.correct
                      : Colors.white.withOpacity(0.07),
                  width: isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? AppColors.correct.withOpacity(0.25)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(e.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isCorrect
                              ? AppColors.correct
                              : AppColors.textMuted,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(e.value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isCorrect
                            ? FontWeight.w700 : FontWeight.w500,
                        color: isCorrect
                            ? AppColors.correct : Colors.white,
                      )),
                ),
                if (isCorrect)
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.correct),
              ]),
            );
          }),
        ],
      ),
    );
  }

  // ── Team Scores ───────────────────────────────────────────────
  Widget _buildTeamScores() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Scores',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ..._teams.map((t) {
          final buzzed = int.tryParse(t['team_id'].toString())
              == _buzzedTeamId;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              if (buzzed)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.bolt, size: 16, color: AppColors.gold),
                ),
              Expanded(
                child: Text(t['team_name'].toString(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: buzzed ? AppColors.gold : Colors.white,
                    )),
              ),
              Text('${t['score']} pts',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.purple)),
            ]),
          );
        }),
      ],
    ),
  );

  // ── Controls ──────────────────────────────────────────────────
  Widget _buildControls() {
    final isBuzzerLocked  = _status == 'buzzer_locked';
    final isShowingResult = _status == 'showing_result';
    final isActive        = _status == 'active';
    final isSingle = (_selectedGame?['game_mode'] ?? 'multi')
        .toString().toLowerCase() == 'single';

    // Show judge buttons when:
    //   • multi: buzzer is locked (someone buzzed in)
    //   • single: game is active (team answers orally, no buzz needed)
    final showJudge = isBuzzerLocked || (isSingle && isActive);

    return Column(
      children: [
        // Correct / Wrong buttons
        if (showJudge) ...[
          Row(children: [
            Expanded(
              child: _CtrlBtn(
                label: '✓  CORRECT  (+10)',
                color: AppColors.correct,
                onTap: _acting ? null : () => _markAnswer(1),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CtrlBtn(
                label: '✗  WRONG',
                color: AppColors.wrong,
                onTap: _acting ? null : () => _markAnswer(0),
              ),
            ),
          ]),
          const SizedBox(height: 10),
        ],

        // Next Question button (visible after result shown)
        if (isShowingResult)
          _CtrlBtn(
            label: '→  NEXT QUESTION',
            color: AppColors.purple,
            onTap: _acting ? null : _nextQuestion,
          ),

        // Waiting for buzz message — only in multi mode
        if (isActive && !isSingle)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty_rounded,
                    size: 16, color: AppColors.textMuted),
                SizedBox(width: 8),
                Text('Waiting for a team to buzz in…',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // End Game button
        _CtrlBtn(
          label: '⏹  End Game',
          color: AppColors.bgSurface,
          textColor: AppColors.textMuted,
          onTap: _acting
              ? null
              : () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: AppColors.bgCard,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('End game?',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900)),
                      content: const Text(
                          'This will finish the game and show final scores.',
                          style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel',
                                style: TextStyle(color: AppColors.purple))),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('End Game',
                                style: TextStyle(color: AppColors.wrong))),
                      ],
                    ),
                  );
                  if (confirm == true) _action('end');
                },
        ),
      ],
    );
  }

  // ── Finished view ─────────────────────────────────────────────
  Widget _buildFinishedView() {
    final sorted = [..._teams]..sort((a, b) =>
        (int.tryParse(b['score'].toString()) ?? 0)
            .compareTo(int.tryParse(a['score'].toString()) ?? 0));
    final medals = ['🥇', '🥈', '🥉'];

    return Column(
      children: [
        const Center(child: Text('🏆', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 12),
        const Center(
          child: Text('Game Finished!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ),
        const SizedBox(height: 20),
        ...sorted.asMap().entries.map((e) {
          final i = e.key;
          final t = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: i == 0
                  ? AppColors.gold.withOpacity(0.12)
                  : AppColors.bgCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: i == 0
                    ? AppColors.gold.withOpacity(0.4)
                    : Colors.white.withOpacity(0.07),
              ),
            ),
            child: Row(children: [
              Text(i < 3 ? medals[i] : '${i + 1}',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(t['team_name'].toString(),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? AppColors.gold : Colors.white)),
              ),
              Text('${t['score']} pts',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.purple)),
            ]),
          );
        }),
        const SizedBox(height: 20),
        _CtrlBtn(
          label: '↺  Reset & Play Again',
          color: AppColors.purple,
          onTap: _acting ? null : () => _action('reset'),
        ),
      ],
    );
  }
}

// ─── Status Pill ──────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'active':
      case 'buzzer_locked':
      case 'showing_result':
        bg = const Color(0xFF052E16); fg = const Color(0xFF86EFAC);
      case 'finished':
        bg = const Color(0xFF1C1C1C); fg = const Color(0xFF6B7280);
      default: // waiting
        bg = const Color(0xFF1E3A5F); fg = const Color(0xFF7DD3FC);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}

// ─── Controller Button ────────────────────────────────────────
class _CtrlBtn extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  textColor;
  final VoidCallback? onTap;

  const _CtrlBtn({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onTap == null ? 0.4 : 1.0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: textColor)),
        ),
      ),
    ),
  );
}

// ─── Controller Timer ─────────────────────────────────────────
class _CtrlTimer extends StatelessWidget {
  final int seconds;
  final int total;
  const _CtrlTimer({required this.seconds, required this.total});

  @override
  Widget build(BuildContext context) {
    final frac = total > 0 ? (seconds / total).clamp(0.0, 1.0) : 0.0;
    final color = seconds > 10
        ? AppColors.correct
        : seconds > 5
            ? AppColors.gold
            : AppColors.wrong;
    return SizedBox(
      width: 44, height: 44,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: frac,
          strokeWidth: 3,
          backgroundColor: Colors.white.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        Text('$seconds',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 13)),
      ]),
    );
  }
}
