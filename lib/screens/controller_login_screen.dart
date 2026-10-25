import 'package:flutter/material.dart';
import '../main.dart';
import 'controller_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  ControllerLoginScreen
//  Password: ctrl123
// ═══════════════════════════════════════════════════════════════
class ControllerLoginScreen extends StatefulWidget {
  const ControllerLoginScreen({super.key});

  @override
  State<ControllerLoginScreen> createState() =>
      _ControllerLoginScreenState();
}

class _ControllerLoginScreenState extends State<ControllerLoginScreen> {
  final _pass    = TextEditingController();
  bool  _obscure = true;
  bool  _shaking = false;

  static const _correctPass = 'ctrl123';

  void _login() async {
    if (_pass.text.trim() == _correctPass) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ControllerScreen()),
      );
    } else {
      setState(() => _shaking = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _shaking = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect password'),
          backgroundColor: AppColors.wrongBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() { _pass.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Controller Login',
                subtitle: 'Teacher / Quiz controller',
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Icon
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.purple.withOpacity(0.14),
                          border: Border.all(
                              color: AppColors.purple.withOpacity(0.35),
                              width: 2),
                        ),
                        child: const Center(
                          child: Text('🎮',
                              style: TextStyle(fontSize: 38)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('Quiz Controller',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text('Enter the controller password to continue',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),

                      const SizedBox(height: 36),

                      // Password field
                      TextField(
                        controller: _pass,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppColors.purple, size: 20),
                          suffixIcon: GestureDetector(
                            onTap: () =>
                                setState(() => _obscure = !_obscure),
                            child: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Login button
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        transform: Matrix4.translationValues(
                            _shaking ? 8 : 0, 0, 0),
                        child: GradientButton(
                          label: 'ENTER',
                          icon: Icons.gamepad_rounded,
                          onTap: _login,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
