import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../services/sound_service.dart';

// ═══════════════════════════════════════════════════════════════
//  NetworkGameScreen — Real-time networked buzzer game
//  Polls get_game_state.php every 1.5 s.
//  State machine: waiting → active → buzzer_locked →
//                 showing_result → finished
// ═══════════════════════════════════════════════════════════════
class NetworkGameScreen extends StatefulWidget {
  final int    gameId;
  final int    teamId;
  final String teamName;
  final String gameName;
  final String gameMode;   // 'single' or 'multi'

  const NetworkGameScreen({
    super.key,
    required this.gameId,
    required this.teamId,
    required this.teamName,
    required this.gameName,
    this.gameMode = 'multi',
  });

  @override
  State<NetworkGameScreen> createState() => _NetworkGameScreenState();
}

class _NetworkGameScreenState extends State<NetworkGameScreen>
    with TickerProviderStateMixin {

  // ── state ─────────────────────────────────────────────────────
  String  _status     = 'waiting';
  String  _lastStatus = '';
  late String _gameMode;   // set from widget.gameMode in initState
  int     _qIdx       = -1;
  int     _total      = 0;
  Map     _question   = {};
  List    _teams      = [];
  int?    _buzzedTeamId;
  String  _buzzedTeamName = '';
  int?    _pointsTeamId;
  String  _pointsTeamName = '';
  int?    _lastAnswerCorrect;
  String? _questionStartedAt;
  int     _duration   = 30;

  bool _buzzLocked     = false;
  bool _resultShown    = false;
  bool _gameOver       = false;
  bool _buzzing        = false;
  bool _timedOut       = false;   // prevent double-timeout

  // ── timer ─────────────────────────────────────────────────────
  int    _timeLeft  = 30;
  Timer? _timerTick;
  Timer? _poll;

  // ── animations ────────────────────────────────────────────────
  late AnimationController _buzzPulse;
  late AnimationController _qFade;
  late Animation<double>   _qFadeAnim;

  @override
  void initState() {
    super.initState();
    _gameMode = widget.gameMode;   // known immediately, no API wait
    _buzzPulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _qFade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _qFadeAnim = CurvedAnimation(parent: _qFade, curve: Curves.easeOut);

    _poll = Timer.periodic(
        const Duration(milliseconds: 1500), (_) => _fetchState());
    _fetchState();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _timerTick?.cancel();
    _buzzPulse.dispose();
    _qFade.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────
  Future<void> _fetchState() async {
    if (!mounted) return;
    try {
      final res = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}get_game_state.php?game_id=${widget.gameId}'));
      if (!mounted) return;
      final d = jsonDecode(res.body) as Map;
      _applyState(d);
    } catch (_) {}
  }

  void _applyState(Map d) {
    final st      = d['status']?.toString() ?? 'waiting';
    final newQIdx = int.tryParse(d['current_question_idx'].toString()) ?? 0;
    final newQ    = newQIdx != _qIdx;

    setState(() {
      _status         = st;
      // Keep widget.gameMode as truth; API value only overrides if present
      if (d['game_mode'] != null) _gameMode = d['game_mode'].toString();
      _total          = int.tryParse(d['total_questions'].toString()) ?? 0;
      _teams          = List.from(d['teams'] ?? []);
      _buzzedTeamId   = d['buzzed_team_id'] != null
          ? int.tryParse(d['buzzed_team_id'].toString()) : null;
      _buzzedTeamName = d['buzzed_team_name']?.toString() ?? '';
      _pointsTeamId   = d['last_points_team_id'] != null
          ? int.tryParse(d['last_points_team_id'].toString()) : null;
      _pointsTeamName = d['last_points_team_name']?.toString() ?? '';
      _lastAnswerCorrect = d['last_answer_correct'] != null
          ? int.tryParse(d['last_answer_correct'].toString()) : null;
      _questionStartedAt = d['question_started_at']?.toString();
      _duration = int.tryParse(d['game_duration'].toString()) ?? 30;
    });

    if (st == 'finished' && !_gameOver) {
      _poll?.cancel();
      _timerTick?.cancel();
      setState(() => _gameOver = true);
      return;
    }

    if (st == 'active') {
      if (newQ || _lastStatus != 'active') {
        setState(() {
          _qIdx        = newQIdx;
          _question    = Map.from(d['question'] ?? {});
          _buzzLocked  = false;
          _resultShown = false;
          _timedOut    = false;
        });
        _qFade.reset();
        _qFade.forward();
        _startLocalTimer();
      }
      if (_lastStatus == 'buzzer_locked' || _lastStatus == 'showing_result') {
        setState(() { _buzzLocked = false; _resultShown = false; });
      }
    }

    if (st == 'buzzer_locked') {
      _timerTick?.cancel();
      if (!_buzzLocked) {
        setState(() => _buzzLocked = true);
        if (_buzzedTeamId == widget.teamId) {
          SoundService.instance.playBuzz();
          HapticFeedback.heavyImpact();
        }
      }
    }

    if (st == 'showing_result' && !_resultShown) {
      setState(() { _resultShown = true; _buzzLocked = true; });
      _showResultOverlay();

      // ── Single player: auto-advance only when player buzzed wrong ─
      // Timeout (buzzed_team_id == null) waits for controller.
      final playerBuzzedWrong = _gameMode == 'single'
          && _lastAnswerCorrect != 1
          && _buzzedTeamId != null;
      if (playerBuzzedWrong) {
        Future.delayed(const Duration(milliseconds: 2600), () {
          if (mounted && _status == 'showing_result') _autoNextQuestion();
        });
      }
    }

    _lastStatus = st;
  }

  // ── local timer ───────────────────────────────────────────────
  void _startLocalTimer() {
    _timerTick?.cancel();
    int rem = _duration;
    if (_questionStartedAt != null && _questionStartedAt!.isNotEmpty) {
      try {
        final started = DateTime.parse(
            _questionStartedAt!.replaceFirst(' ', 'T') + 'Z');
        final elapsed =
            DateTime.now().toUtc().difference(started).inSeconds;
        rem = (_duration - elapsed).clamp(0, _duration);
      } catch (_) {}
    }
    setState(() => _timeLeft = rem);
    _timerTick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft = (_timeLeft - 1).clamp(0, _duration));
      if (_timeLeft <= 5 && _timeLeft > 0) SoundService.instance.playTick();
      if (_timeLeft <= 0) {
        t.cancel();
        // Time's up — lock buzzer immediately and notify server
        if (_status == 'active' && !_timedOut) {
          setState(() {
            _timedOut   = true;
            _buzzLocked = true;   // hide buzz button right away
          });
          _doTimeout();
        }
      }
    });
  }

  // ── buzz ──────────────────────────────────────────────────────
  Future<void> _doBuzz() async {
    if (_buzzLocked || _buzzing || _status != 'active') return;
    setState(() => _buzzing = true);
    HapticFeedback.heavyImpact();
    SoundService.instance.playBuzz();
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}buzz_in.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'game_id': widget.gameId.toString(),
          'team_id': widget.teamId.toString(),
        },
      );
    } catch (_) {}
    if (mounted) setState(() { _buzzing = false; _buzzLocked = true; });
  }

  // ── Single player: timer expired ─────────────────────────────
  Future<void> _doTimeout() async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}timeout_question.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'game_id': widget.gameId.toString(),
          'team_id': widget.teamId.toString(),
        },
      );
    } catch (_) {}
  }

  // ── Single player: auto-advance to next question ──────────────
  Future<void> _autoNextQuestion() async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}next_question.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'game_id': widget.gameId.toString()},
      );
    } catch (_) {}
  }

  // ── result overlay ────────────────────────────────────────────
  void _showResultOverlay() {
    final correct   = _lastAnswerCorrect == 1;
    final myTeamWon = _pointsTeamId == widget.teamId;
    // isTimeout = nobody buzzed AND no team was assigned points (pure timeout)
    // vs. controller marked wrong in single mode (_pointsTeamId != null)
    final isTimeout = !correct && _buzzedTeamId == null && _pointsTeamId == null;

    if (correct) SoundService.instance.playCorrect();
    else         SoundService.instance.playWrong();

    final ov = OverlayEntry(builder: (_) => _ResultOverlay(
      correct:     correct,
      winnerName:  _pointsTeamName,
      myTeamWon:   myTeamWon,
      isTimeout:   isTimeout,
    ));
    Overlay.of(context).insert(ov);
    Future.delayed(
      Duration(milliseconds: correct ? 3200 : 2400),
      () { try { ov.remove(); } catch (_) {} },
    );
  }

  // ── build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_gameOver)            return _buildFinished();
    if (_status == 'waiting') return _buildWaitPlaceholder();
    return _buildGame();
  }

  Widget _buildWaitPlaceholder() => Scaffold(
    body: AppBackground(
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⏳', style: TextStyle(fontSize: 56)),
            SizedBox(height: 16),
            Text('Game starting soon…',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    ),
  );

  // ── game UI ───────────────────────────────────────────────────
  Widget _buildGame() => Scaffold(
    body: AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildScoreStrip(),
            Expanded(
              child: FadeTransition(
                opacity: _qFadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  child: Column(children: [
                    _buildQuestionCard(),
                    // No buzz button in single mode — controller judges orally
                    if (_gameMode != 'single') ...[
                      const SizedBox(height: 20),
                      _buildBuzzer(),
                    ],
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Q ${_qIdx + 1} / $_total',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700),
          ),
        ),
        if (_status == 'active')
          _TimerBadge(seconds: _timeLeft, total: _duration),
      ],
    ),
  );

  Widget _buildScoreStrip() => SizedBox(
    height: 50,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemCount: _teams.length,
      itemBuilder: (_, i) {
        final t    = _teams[i];
        final mine = int.tryParse(t['team_id'].toString()) == widget.teamId;
        return _ScoreChip(
          name:  t['team_name'].toString(),
          score: int.tryParse(t['score'].toString()) ?? 0,
          mine:  mine,
        );
      },
    ),
  );

  // ── Question card — shows question text + answer options ──────
  Widget _buildQuestionCard() {
    final opts = [
      MapEntry('A', _question['option_a']?.toString() ?? ''),
      MapEntry('B', _question['option_b']?.toString() ?? ''),
      MapEntry('C', _question['option_c']?.toString() ?? ''),
      MapEntry('D', _question['option_d']?.toString() ?? ''),
    ];
    final correct       = _question['correct_answer']?.toString() ?? '';
    final revealCorrect = _status == 'showing_result';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buzzer status banner
          if (_buzzLocked && _buzzedTeamId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt, size: 14, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  _buzzedTeamId == widget.teamId
                      ? 'You buzzed in!'
                      : '$_buzzedTeamName buzzed in!',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _buzzedTeamId == widget.teamId
                        ? AppColors.gold : AppColors.wrong,
                  ),
                ),
              ]),
            ),

          // Question text
          Text(
            _question['question_text']?.toString() ?? '…',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800,
                color: Colors.white, height: 1.45),
          ),

          // ── Answer options (display only, no tap) ──────────────
          if (opts.any((e) => e.value.isNotEmpty)) ...[
            const SizedBox(height: 14),
            ...opts.map((e) {
              final isCorrect = revealCorrect && e.key == correct;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
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
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? AppColors.correct.withOpacity(0.25)
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Center(
                      child: Text(e.key,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: isCorrect
                                  ? AppColors.correct
                                  : AppColors.textMuted)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      e.value,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCorrect
                              ? FontWeight.w700 : FontWeight.w500,
                          color: isCorrect
                              ? AppColors.correct : Colors.white),
                    ),
                  ),
                  if (isCorrect)
                    const Icon(Icons.check_circle_rounded,
                        size: 16, color: AppColors.correct),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildBuzzer() {
    if (_buzzLocked) return _buildLockedBuzzer();

    return AnimatedBuilder(
      animation: _buzzPulse,
      builder: (_, __) => Transform.scale(
        scale: 1.0 + _buzzPulse.value * 0.04,
        child: GestureDetector(
          onTap: _doBuzz,
          child: Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.wrong.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.wrong.withOpacity(
                    0.4 + _buzzPulse.value * 0.4),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.wrong.withOpacity(
                      0.15 + _buzzPulse.value * 0.2),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded,
                    color: AppColors.wrong, size: 34),
                const SizedBox(height: 4),
                const Text('BUZZ!',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.wrong,
                        letterSpacing: 2)),
                Text(widget.teamName,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.wrong.withOpacity(0.6),
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockedBuzzer() {
    final myBuzz = _buzzedTeamId == widget.teamId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: (myBuzz ? AppColors.gold : AppColors.bgCard)
            .withOpacity(myBuzz ? 0.12 : 1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: myBuzz
              ? AppColors.gold.withOpacity(0.4)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            myBuzz ? Icons.bolt_rounded : Icons.lock_rounded,
            color: myBuzz ? AppColors.gold : AppColors.textMuted,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            myBuzz
                ? '🔔 You buzzed in!\nWaiting for the result…'
                : (_buzzedTeamId == null
                    ? 'Waiting for result…'
                    : '🔴 $_buzzedTeamName buzzed in!\nBuzzer is locked.'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: myBuzz ? AppColors.gold : AppColors.textMuted,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Finished screen ───────────────────────────────────────────
  Widget _buildFinished() {
    final sorted = [..._teams]..sort((a, b) =>
        (int.tryParse(b['score'].toString()) ?? 0)
            .compareTo(int.tryParse(a['score'].toString()) ?? 0));
    final medals = ['🥇', '🥈', '🥉'];
    final iWon   = sorted.isNotEmpty &&
        int.tryParse(sorted[0]['team_id'].toString()) == widget.teamId;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Winner gets celebration, loser gets normal header
              if (iWon)
                const _WinCelebration()
              else ...[
                AppHeader(title: 'Game Over!', subtitle: widget.gameName),
                const SizedBox(height: 10),
                const Text('🏆', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                const Text('Final Results',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final t        = sorted[i];
                    final mine     = int.tryParse(t['team_id'].toString())
                        == widget.teamId;
                    final isWinner = i == 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: mine
                            ? AppColors.purple.withOpacity(0.18)
                            : isWinner
                                ? AppColors.gold.withOpacity(0.10)
                                : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: mine
                              ? AppColors.purple.withOpacity(0.4)
                              : isWinner
                                  ? AppColors.gold.withOpacity(0.4)
                                  : Colors.white.withOpacity(0.07),
                          width: isWinner ? 1.5 : 1,
                        ),
                      ),
                      child: Row(children: [
                        Text(i < 3 ? medals[i] : '${i + 1}',
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            t['team_name'].toString() +
                                (mine ? ' (You)' : ''),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isWinner
                                  ? AppColors.gold
                                  : mine
                                      ? AppColors.purple
                                      : Colors.white,
                            ),
                          ),
                        ),
                        Text('${t['score']} pts',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppColors.purple)),
                      ]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: GradientButton(
                  label: 'BACK TO MENU',
                  icon: Icons.home_rounded,
                  onTap: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  Win Celebration — pulsing trophy + glowing banner + orbiting stars
// ═══════════════════════════════════════════════════════════════
class _WinCelebration extends StatefulWidget {
  const _WinCelebration();
  @override
  State<_WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<_WinCelebration>
    with TickerProviderStateMixin {

  late final AnimationController _pulseCtrl;
  late final List<AnimationController> _starCtrls;
  final _rng = math.Random(7);

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);

    _starCtrls = List.generate(8, (i) {
      final c = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: 1500 + i * 150));
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) c.repeat();
      });
      return c;
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    for (final c in _starCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const emojis = ['⭐', '✨', '🌟', '💫'];
    final pulse  = Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => SizedBox(
        height: 230,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Orbiting star particles ──────────────────────
            ...List.generate(8, (i) {
              final angle  = i * math.pi * 2 / 8;
              final radius = 80.0 + _rng.nextDouble() * 28;
              final dx = math.cos(angle) * radius;
              final dy = math.sin(angle) * radius;
              return AnimatedBuilder(
                animation: _starCtrls[i],
                builder: (_, __) {
                  final t       = _starCtrls[i].value;
                  final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2)
                      .clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(dx, dy),
                    child: Transform.scale(
                      scale: 0.6 + t * 0.7,
                      child: Opacity(
                        opacity: opacity,
                        child: Text(emojis[i % 4],
                            style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                },
              );
            }),

            // ── Pulsing trophy + glowing YOU WIN banner ──────
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: pulse.value,
                  child: const Text('🏆',
                      style: TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [AppColors.gold, Color(0xFFFF8C42)]),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(
                            0.25 + _pulseCtrl.value * 0.5),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text('YOU WIN! 🎉',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timer Badge ──────────────────────────────────────────────
class _TimerBadge extends StatelessWidget {
  final int seconds;
  final int total;
  const _TimerBadge({required this.seconds, required this.total});

  @override
  Widget build(BuildContext context) {
    final frac  = total > 0 ? seconds / total : 0.0;
    final color = frac > 0.4
        ? AppColors.gold
        : AppColors.wrong;
    return SizedBox(
      width: 44, height: 44,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
          value: frac.clamp(0, 1).toDouble(),
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

// ─── Score Chip ───────────────────────────────────────────────
class _ScoreChip extends StatelessWidget {
  final String name;
  final int    score;
  final bool   mine;
  const _ScoreChip({
      required this.name, required this.score, required this.mine});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: mine
          ? AppColors.purple.withOpacity(0.18)
          : AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: mine
            ? AppColors.purple.withOpacity(0.5)
            : Colors.white.withOpacity(0.08),
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: mine ? AppColors.purple : AppColors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text('$score pts',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: mine ? AppColors.purple : Colors.white)),
      ],
    ),
  );
}

// ─── Result Overlay ───────────────────────────────────────────
class _ResultOverlay extends StatelessWidget {
  final bool   correct;
  final String winnerName;
  final bool   myTeamWon;
  final bool   isTimeout;

  const _ResultOverlay({
    required this.correct,
    required this.winnerName,
    required this.myTeamWon,
    this.isTimeout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: correct
            ? const Color(0xDD052E16)
            : const Color(0xDD450A0A),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTimeout ? '⏰' : (correct ? '⭐' : '❌'),
                style: const TextStyle(fontSize: 72),
              ),
              const SizedBox(height: 12),
              Text(
                isTimeout ? 'TIME\'S UP!' : (correct ? 'CORRECT!' : 'WRONG!'),
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: correct ? AppColors.correct : AppColors.wrong,
                ),
              ),
              const SizedBox(height: 8),
              if (isTimeout)
                const Text('No points this round',
                    style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMuted))
              else if (correct) ...[
                if (winnerName.isNotEmpty)
                  Text('$winnerName got it right!',
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 8),
                const Text('+10 pts',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold)),
                if (myTeamWon) ...[
                  const SizedBox(height: 6),
                  const Text('Amazing! 🎉',
                      style: TextStyle(
                          fontSize: 16, color: Colors.white)),
                ],
              ] else ...[
                if (winnerName.isNotEmpty)
                  Text('$winnerName missed it',
                      style: const TextStyle(
                          fontSize: 16, color: Colors.white70)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
