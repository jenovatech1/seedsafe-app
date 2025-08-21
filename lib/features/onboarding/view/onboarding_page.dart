import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OnboardingBloc(),
      child: const OnboardingView(),
    );
  }
}

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) async {
        final nav = Navigator.of(context); // cache navigator
        final bloc = context
            .read<
              OnboardingBloc
            >(); // cache bloc (hindari pakai context setelah await)

        if (state is OnboardingNavigateToCreateVault) {
          await nav.pushNamed('/create-password');
          if (!context.mounted) return;
          bloc.add(OnboardingReset());
        } else if (state is OnboardingNavigateToRestore) {
          await nav.pushNamed('/restore');
          if (!context.mounted) return;
          bloc.add(OnboardingReset());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Spacer(),
                Image.asset('assets/images/logo.png', width: 500),
                const SizedBox(height: 24),
                Text(
                  'Welcome to SeedSafe',
                  style: textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your private and offline\nseed phrase manager.',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(color: Colors.white70),
                ),
                const Spacer(flex: 2),
                _ActionButton(
                  label: 'Create New Vault',
                  icon: Icons.add_to_photos_outlined,
                  onTap: () {
                    context.read<OnboardingBloc>().add(CreateVaultTapped());
                  },
                ),
                const SizedBox(height: 16),
                _ActionButton(
                  label: 'Restore from Backup',
                  icon: Icons.qr_code_scanner_outlined,
                  onTap: () {
                    context.read<OnboardingBloc>().add(
                      RestoreFromBackupTapped(),
                    );
                  },
                  isPrimary: false,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final secondaryColor = Colors.white;

    return Material(
      color: isPrimary
          ? primaryColor
          : Colors.grey.shade800.withValues(alpha: 0.5), // ← ganti withOpacity
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? Colors.black : secondaryColor),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isPrimary ? Colors.black : secondaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
