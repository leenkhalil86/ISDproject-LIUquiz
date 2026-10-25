import 'package:flutter/material.dart';
import '../main.dart';
import 'admin_panel_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  AdminLoginScreen
//  credentials: admin / 1234
// ═══════════════════════════════════════════════════════════════
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _shaking = false;

  void _login() async {
    if (_user.text == 'admin' && _pass.text == '1234') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => const AdminPanelScreen()),
      );
    } else {
      setState(() => _shaking = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _shaking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wrong username or password'),
          backgroundColor: AppColors.wrongBg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(title: 'Admin Login', subtitle: 'Restricted access'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // icon
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withOpacity(0.12),
                          border: Border.all(
                              color: AppColors.gold.withOpacity(0.3),
                              width: 2),
                        ),
                        child: const Center(
                          child: Text('🔐',
                              style: TextStyle(fontSize: 38)),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // username
                      TextField(
                        controller: _user,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline,
                              color: AppColors.gold, size: 20),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // password
                      TextField(
                        controller: _pass,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppColors.gold, size: 20),
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
                        onSubmitted: (_) => _login(),
                      ),

                      const SizedBox(height: 36),

                      // login btn
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        transform: Matrix4.translationValues(
                            _shaking ? 6 : 0, 0, 0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFB800),
                                    Color(0xFFE07800)
                                  ]),
                              borderRadius:
                                  BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold
                                      .withOpacity(0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _login,
                                borderRadius:
                                    BorderRadius.circular(16),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          Icons
                                              .admin_panel_settings_rounded,
                                          color: Colors.white,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text('LOGIN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.w900,
                                            color: Colors.white,
                                            letterSpacing: 1.5,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text('Please enter your admin credentials to access the panel.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted)),
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