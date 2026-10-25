import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import 'start_page_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  LoadingSplashScreen
//  Shown for 3 s on app launch, then fades into StartPageScreen
// ═══════════════════════════════════════════════════════════════
class LoadingSplashScreen extends StatefulWidget {
  const LoadingSplashScreen({super.key});

  @override
  State<LoadingSplashScreen> createState() => _LoadingSplashScreenState();
}

class _LoadingSplashScreenState extends State<LoadingSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _trophyCtrl;
  late AnimationController _textCtrl;

  late Animation<double> _trophyScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _trophyCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _trophyScale = CurvedAnimation(
        parent: _trophyCtrl, curve: Curves.elasticOut);

    _textFade =
        Tween<double>(begin: 0, end: 1).animate(_textCtrl);
    _textSlide = Tween<Offset>(
            begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut));

    _trophyCtrl.forward().then((_) => _textCtrl.forward());

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        pageBuilder: (_, __, ___) => const StartPageScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ));
    });
  }

  @override
  void dispose() {
    _trophyCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── trophy ───────────────────────────────────────
              ScaleTransition(
                scale: _trophyScale,
                child: Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.3), width: 2),
                  ),
                  child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 68)),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ── text ─────────────────────────────────────────
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: _textSlide,
                  child: Column(
                    children: [
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

                      const SizedBox(height: 10),

                      const Text('QUIZ',
                          style: TextStyle(
                            fontSize: 60,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 10,
                            height: 1,
                          )),

                      const SizedBox(height: 8),

                      const Text('Challenge · Learn · Win',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            letterSpacing: 2,
                          )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 60),

              // ── loading dots ─────────────────────────────────
              FadeTransition(
                opacity: _textFade,
                child: const _LoadingDots(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── bouncing dots ────────────────────────────────────────────
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
        3,
        (i) => AnimationController(
            vsync: this, duration: const Duration(milliseconds: 500))
          ..repeat(reverse: true));
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180),
          () { if (mounted) _ctrls[i].forward(); });
    }
  }

  @override
  void dispose() {
    for (var c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrls[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                  AppColors.gold.withOpacity(0.25),
                  AppColors.gold,
                  _ctrls[i].value),
            ),
          ),
        );
      }),
    );
  }
}