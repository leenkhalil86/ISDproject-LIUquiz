import 'package:flutter/material.dart';
import '../main.dart';
import 'main_menu_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  StartPageScreen  — animated landing / "press start" screen
// ═══════════════════════════════════════════════════════════════
class StartPageScreen extends StatefulWidget {
  const StartPageScreen({super.key});

  @override
  State<StartPageScreen> createState() => _StartPageScreenState();
}

class _StartPageScreenState extends State<StartPageScreen>
    with TickerProviderStateMixin {
  late AnimationController _trophyPulse;
  late AnimationController _fadeIn;
  late Animation<double> _fade;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();

    _trophyPulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _fadeIn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));

    _fade = CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
            begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _fadeIn, curve: Curves.easeOut));

    _fadeIn.forward();
  }

  @override
  void dispose() {
    _trophyPulse.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slideUp,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── trophy ──────────────────────────────────
                    AnimatedBuilder(
                      animation: _trophyPulse,
                      builder: (_, __) => Transform.scale(
                        scale: 1.0 + _trophyPulse.value * 0.06,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                            border: Border.all(
                                color: AppColors.gold
                                    .withOpacity(0.25 +
                                        _trophyPulse.value * 0.25),
                                width: 2),
                          ),
                          child: const Center(
                            child: Text('🏆',
                                style: TextStyle(fontSize: 66)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // LIU badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.purple, AppColors.pink]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('LIU',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 5,
                          )),
                    ),

                    const SizedBox(height: 8),

                    const Text('QUIZ',
                        style: TextStyle(
                          fontSize: 62,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 8,
                          height: 1,
                        )),

                    const SizedBox(height: 6),

                    const Text('Challenge Your Knowledge',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textMuted,
                          letterSpacing: 1,
                        )),

                    const SizedBox(height: 36),

                    // ── feature row ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _FeatureChip(icon: '👥', label: 'Multiplayer'),
                        SizedBox(width: 12),
                        _FeatureChip(icon: '🧠', label: '12 Topics'),
                        SizedBox(width: 12),
                        _FeatureChip(icon: '⚡', label: 'Fast-Paced'),
                      ],
                    ),

                    const SizedBox(height: 44),

                    // ── start button ─────────────────────────────
                    GradientButton(
                      label: 'START GAME',
                      icon: Icons.play_arrow_rounded,
                      height: 58,
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const MainMenuScreen()),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text('Tap to begin your adventure',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted)),
        ],
      ),
    );
  }
}