import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/vault_setup_bloc.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/security/security_service.dart';
import '../../../shared/widgets/progress_dialog.dart';

class CreatePasswordPage extends StatelessWidget {
  const CreatePasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          VaultSetupBloc(securityService: sl<SecurityService>()),
      child: const CreatePasswordView(),
    );
  }
}

class CreatePasswordView extends StatelessWidget {
  const CreatePasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VaultSetupBloc, VaultSetupState>(
      listener: (context, state) {
        if (state.status == VaultSetupStatus.inProgress) {
          showSimulatedProgressDialog(context, title: 'Creating vault...', subtitle: 'Deriving encryption key');
        } else if (state.status == VaultSetupStatus.success) {
          // Navigasi ke home dan hapus semua halaman sebelumnya dari stack
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/home', (route) => false);
        } else if (state.status == VaultSetupStatus.failure) {
          // Tampilkan snackbar jika ada error
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text('Error: ${state.errorMessage}')),
            );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Master Password')),
        body: BlocBuilder<VaultSetupBloc, VaultSetupState>(
          builder: (context, state) {
            if (state.status == VaultSetupStatus.inProgress) {
              return const Center(child: CircularProgressIndicator());
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This password will be used to encrypt all your data. Store it safely, it cannot be recovered.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  // Password Text Field
                  TextField(
                    onChanged: (password) => context.read<VaultSetupBloc>().add(
                      PasswordChanged(password),
                    ),
                    obscureText: !state.isPasswordVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Master Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          state.isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => context.read<VaultSetupBloc>().add(
                          PasswordVisibilityToggled(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _PasswordStrengthIndicator(strength: state.strength),
                  const SizedBox(height: 24),
                  // Confirm Password Text Field
                  TextField(
                    onChanged: (password) => context.read<VaultSetupBloc>().add(
                      ConfirmPasswordChanged(password),
                    ),
                    obscureText: !state.isConfirmPasswordVisible,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      errorText:
                          state.errorMessage.isNotEmpty &&
                              state.confirmPassword.isNotEmpty
                          ? state.errorMessage
                          : null,
                      suffixIcon: IconButton(
                        icon: Icon(
                          state.isConfirmPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => context.read<VaultSetupBloc>().add(
                          ConfirmPasswordVisibilityToggled(),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Tombol Submit
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: state.isFormValid
                          ? () => context.read<VaultSetupBloc>().add(
                              VaultSubmitted(),
                            )
                          : null,
                      child: const Text(
                        'Create Vault',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.strength});
  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (index) {
        Color color = Colors.grey.shade800;
        if (strength == PasswordStrength.weak && index == 0) {
          color = Colors.red;
        } else if (strength == PasswordStrength.medium && index <= 1) {
          color = Colors.orange;
        } else if (strength == PasswordStrength.strong && index <= 2) {
          color = Colors.green;
        }
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
