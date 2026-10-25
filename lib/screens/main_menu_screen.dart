import 'package:flutter/material.dart';
import '../main.dart';
import 'single_player_setup.dart';
import 'game_lobby_screen.dart';
import 'controller_login_screen.dart';
import 'admin_login_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  MainMenuScreen
// ═══════════════════════════════════════════════════════════════
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const _AppDrawer(),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── app bar ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Row(
                  children: [
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.menu,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // LIU Quiz wordmark
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              AppColors.purple,
                              AppColors.pink,
                            ]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('LIU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                              )),
                        ),
                        const SizedBox(width: 6),
                        const Text('QUIZ',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            )),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── trophy hero ──────────────────────────────────
              const Text('🏆', style: TextStyle(fontSize: 76)),
              const SizedBox(height: 8),
              const Text('READY TO PLAY?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2,
                  )),
              const SizedBox(height: 4),
              const Text('Pick your game mode below',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),

              const SizedBox(height: 30),

              // ── mode buttons ─────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Single Player
                      _ModeButton(
                        icon: Icons.person_rounded,
                        color: AppColors.purple,
                        title: 'Single Player',
                        subtitle: 'Test your knowledge solo',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SinglePlayerSetup())),
                      ),
                      const SizedBox(height: 14),

                      // Multiplayer — network mode
                      _ModeButton(
                        icon: Icons.groups_rounded,
                        color: AppColors.pink,
                        title: 'Multiplayer',
                        subtitle: 'Join a game on the network',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GameLobbyScreen())),
                      ),
                      const SizedBox(height: 14),

                      // Controller
                      _ModeButton(
                        icon: Icons.gamepad_rounded,
                        color: AppColors.gold,
                        title: 'Controller',
                        subtitle: 'Teacher: manage and start games',
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ControllerLoginScreen())),
                      ),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('LIU Quiz v1.0',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mode Button ──────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.3), size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Drawer ───────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bgCard,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppColors.purple, AppColors.pink]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: const Center(
                        child: Text('🏆',
                            style: TextStyle(fontSize: 28))),
                  ),
                  const SizedBox(height: 12),
                  const Text('LIU Quiz',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const Text('Lebanese International University',
                      style:
                          TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            _tile(context, Icons.person_rounded, 'Single Player', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SinglePlayerSetup()));
            }),

            _tile(context, Icons.groups_rounded, 'Multiplayer', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const GameLobbyScreen()));
            }),

            _tile(context, Icons.gamepad_rounded, 'Controller', () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const ControllerLoginScreen()));
            }),

            _tile(context, Icons.admin_panel_settings_rounded, 'Admin Panel',
                () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const AdminLoginScreen()));
            }),

            const Spacer(),

            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Version 1.0',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textMuted),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textMuted, size: 18),
      onTap: onTap,
    );
  }
}
