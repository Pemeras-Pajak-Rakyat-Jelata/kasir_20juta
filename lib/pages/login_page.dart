import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  int _failedAttempts = 0;
  DateTime? _lockUntil;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  bool get _isLocked {
    if (_lockUntil == null) return false;
    return DateTime.now().isBefore(_lockUntil!);
  }

  int get _remainingSeconds {
    if (_lockUntil == null) return 0;
    final s = _lockUntil!.difference(DateTime.now()).inSeconds;
    return s > 0 ? s : 0;
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      if (_remainingSeconds <= 0) {
        _timer?.cancel();
      }

      setState(() {});
    });
  }

  void _applyLockRule() {
    int seconds = 0;

    if (_failedAttempts >= 10) {
      seconds = 300;
    } else if (_failedAttempts >= 5) {
      seconds = 120;
    } else if (_failedAttempts >= 3) {
      seconds = 30;
    }

    if (seconds > 0) {
      _lockUntil = DateTime.now().add(Duration(seconds: seconds));
      _startTimer();
    }
  }

  Future<void> _login() async {
    if (_isLocked) {
      _showSnack(
        'Terlalu banyak percobaan.\nCoba lagi dalam $_remainingSeconds detik.',
        isError: true,
      );
      return;
    }

    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      _showSnack('Email dan password wajib diisi', isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      await SupabaseService.signIn(
        _emailCtrl.text.trim(),
        _passCtrl.text,
      );

      _failedAttempts = 0;
      _lockUntil = null;
      _timer?.cancel();
    } catch (e) {
      _failedAttempts++;
      _applyLockRule();

      _showSnack(
        _isLocked
            ? 'Login terkunci $_remainingSeconds detik'
            : 'Email atau password salah',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppTheme.merahError : AppTheme.hijauEmerald,
      ),
    );
  }

  String _lockText() {
    final sec = _remainingSeconds;

    if (sec >= 60) {
      final menit = (sec / 60).ceil();
      return 'Tunggu $menit menit';
    }

    return 'Tunggu $sec detik';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.hijauEmerald,
              Color(0xFF0D4A33),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                // FORM LOGIN
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [

                      TextField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscure = !_obscure;
                              });
                            },
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed:
                              (_loading || _isLocked) ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.hijauEmerald,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  _isLocked
                                      ? _lockText()
                                      : 'Masuk',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      if (_isLocked) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Terlalu banyak percobaan login',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}