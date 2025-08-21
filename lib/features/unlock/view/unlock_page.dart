import 'package:flutter/material.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';

class UnlockPage extends StatefulWidget {
  const UnlockPage({super.key});

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> with WidgetsBindingObserver {
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscure = true;
  String? _errorText;

  bool _biometricsEnabled = false;
  bool _canUseBiometrics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBiometricFlags();

    // Coba biometrik setelah frame pertama (sudah visible)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePromptBiometrics();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricFlags() async {
    final s = sl<SecurityService>();
    final enabled = await s.isBiometricsEnabled();
    final canUse = await s.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricsEnabled = enabled;
      _canUseBiometrics = canUse;
    });

    _maybePromptBiometrics();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saat kembali ke foreground, baru kita coba biometrik lagi.
    if (state == AppLifecycleState.resumed) {
      _maybePromptBiometrics();
    }
  }

  void _maybePromptBiometrics() {
    if (!_biometricsEnabled || !_canUseBiometrics) return;
    if (!mounted) return;
    if (_isLoading) return; // jangan dobel
    _tryBiometricUnlock();
  }

  Future<void> _tryBiometricUnlock() async {
    final s = sl<SecurityService>();
    setState(() => _isLoading = true);

    final ok = await s.unlockWithBiometrics();
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    }
    // kalau gagal/cancel: tetap di halaman ini, user bisa masukkan password manual
  }

  Future<void> _unlock() async {
    // Tutup keyboard biar UI rapi
    FocusScope.of(context).unfocus();

    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() => _errorText = 'Password is required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    final s = sl<SecurityService>();
    final ok = await s.unlockVault(pwd);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } else {
      setState(() {
        _isLoading = false;
        _errorText = 'Wrong password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/logo.png', height: 220),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome Back',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 32),

                    // Password field + eye toggle
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofocus: false,
                      decoration: InputDecoration(
                        labelText: 'Master Password',
                        errorText: _errorText,
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show' : 'Hide',
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() {
                            _obscure = !_obscure;
                          }),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _unlock(),
                    ),

                    const SizedBox(height: 24),

                    // Biometric hint (opsional)
                    if (_biometricsEnabled && _canUseBiometrics && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'You can also unlock with biometrics.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ),

                    _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _unlock,
                                  child: const Text('Unlock'),
                                ),
                              ),
                              if (_biometricsEnabled && _canUseBiometrics)
                                TextButton.icon(
                                  onPressed: _tryBiometricUnlock,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Use biometrics'),
                                ),
                            ],
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
