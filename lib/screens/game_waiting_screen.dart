import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'network_game_screen.dart';


// ═══════════════════════════════════════════════════════════════
//  GameWaitingScreen
//  Polls game state every 1.5 s. Navigates to NetworkGameScreen
//  once the controller starts the game (status != 'waiting').
// ═══════════════════════════════════════════════════════════════
class GameWaitingScreen extends StatefulWidget {
  final int    gameId;
  final int    teamId;
  final String teamName;
  final String gameName;
  final String gameMode;   // 'single' or 'multi'

  const GameWaitingScreen({
    super.key,
    required this.gameId,
    required this.teamId,
    required this.teamName,
    required this.gameName,
    this.gameMode = 'multi',
  });

  @override
  State<GameWaitingScreen> createState() => _GameWaitingScreenState();
}

class _GameWaitingScreenState extends State<GameWaitingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _poll;
  late AnimationController _breathe;
  late Animation<double>   _breatheAnim;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _breatheAnim = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _breathe, curve: Curves.easeInOut));

    _markReady();
    _checkState();
    _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _checkState());
  }

  // Mark this team as ready — called on load so it always fires even
  // if the lobby screen's call was blocked by the server firewall.
  Future<void> _markReady() async {
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}set_team_ready.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'game_id': widget.gameId.toString(),
          'team_id': widget.teamId.toString(),
        },
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    _breathe.dispose();
    super.dispose();
  }

  Future<void> _checkState() async {
    if (!mounted) return;
    try {
      final res = await http.get(Uri.parse(
          '${ApiConfig.baseUrl}get_game_state.php?game_id=${widget.gameId}'));
      if (!mounted) return;
      final data   = jsonDecode(res.body);
      final status = data['status']?.toString() ?? 'waiting';
      if (status != 'waiting') {
        _poll?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => NetworkGameScreen(
              gameId:   widget.gameId,
              teamId:   widget.teamId,
              teamName: widget.teamName,
              gameName: widget.gameName,
              gameMode: widget.gameMode,
            ),
          ),
        );
      }
    } catch (_) {}
  }

  void _leaveDialog() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave game?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('You will exit the waiting room.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay', style: TextStyle(color: AppColors.purple)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: AppColors.wrong)),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _breatheAnim,
                    child: const Text('⏳', style: TextStyle(fontSize: 72)),
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Waiting for the game\nto start',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.gameName,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 30),

                  // Team badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.purple.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.groups_rounded,
                            color: AppColors.purple, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          widget.teamName,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'The controller will start soon.\nStay on this screen.',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.6),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 36),
                  _LoadingDots(),

                  const SizedBox(height: 36),
                  TextButton(
                    onPressed: _leaveDialog,
                    child: const Text('Leave game',
                        style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.textMuted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Animated dots ────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> {
  int    _dot = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 500),
        (_) { if (mounted) setState(() => _dot = (_dot + 1) % 3); });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(3, (i) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 10, height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: i == _dot
            ? AppColors.purple
            : AppColors.purple.withOpacity(0.25),
      ),
    )),
  );
}
