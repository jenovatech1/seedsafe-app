import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/security/security_service.dart';

part 'vault_setup_event.dart';
part 'vault_setup_state.dart';

class VaultSetupBloc extends Bloc<VaultSetupEvent, VaultSetupState> {
  final SecurityService _securityService;

  VaultSetupBloc({required SecurityService securityService})
    : _securityService = securityService,
      super(const VaultSetupState()) {
    on<PasswordChanged>(_onPasswordChanged);
    on<ConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<PasswordVisibilityToggled>(
      (event, emit) =>
          emit(state.copyWith(isPasswordVisible: !state.isPasswordVisible)),
    );
    on<ConfirmPasswordVisibilityToggled>(
      (event, emit) => emit(
        state.copyWith(
          isConfirmPasswordVisible: !state.isConfirmPasswordVisible,
        ),
      ),
    );
    on<VaultSubmitted>(_onVaultSubmitted);
  }

  void _validate(Emitter<VaultSetupState> emit) {
    final strength = _checkPasswordStrength(state.password);
    String errorMessage = '';

    if (state.password.isNotEmpty && state.confirmPassword.isNotEmpty) {
      if (state.password != state.confirmPassword) {
        errorMessage = 'Passwords do not match.';
      }
    }

    final isFormValid =
        state.password.isNotEmpty &&
        state.confirmPassword.isNotEmpty &&
        errorMessage.isEmpty &&
        strength != PasswordStrength.weak &&
        strength != PasswordStrength.none;

    emit(
      state.copyWith(
        strength: strength,
        errorMessage: errorMessage,
        isFormValid: isFormValid,
      ),
    );
  }

  PasswordStrength _checkPasswordStrength(String password) {
    if (password.length < 8) return PasswordStrength.weak;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasDigits = password.contains(RegExp(r'[0-9]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasSpecialCharacters = password.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );

    int score = 0;
    if (hasUppercase) score++;
    if (hasDigits) score++;
    if (hasLowercase) score++;
    if (hasSpecialCharacters) score++;

    if (score >= 3 && password.length >= 12) return PasswordStrength.strong;
    if (score >= 2 && password.length >= 8) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  void _onPasswordChanged(
    PasswordChanged event,
    Emitter<VaultSetupState> emit,
  ) {
    emit(state.copyWith(password: event.password));
    _validate(emit);
  }

  void _onConfirmPasswordChanged(
    ConfirmPasswordChanged event,
    Emitter<VaultSetupState> emit,
  ) {
    emit(state.copyWith(confirmPassword: event.password));
    _validate(emit);
  }

  Future<void> _onVaultSubmitted(
    VaultSubmitted event,
    Emitter<VaultSetupState> emit,
  ) async {
    if (!state.isFormValid) return;

    emit(state.copyWith(status: VaultSetupStatus.inProgress));
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      // Panggil service untuk membuat vault
      await _securityService.createVault(state.password);
      emit(
        state.copyWith(status: VaultSetupStatus.success),
      ); // <-- Emit state sukses
    } catch (e) {
      emit(
        state.copyWith(
          status: VaultSetupStatus.failure,
          errorMessage: e.toString(),
        ),
      ); // <-- Emit state gagal
    }
  }
}
