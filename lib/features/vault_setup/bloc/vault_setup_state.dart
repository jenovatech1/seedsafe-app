part of 'vault_setup_bloc.dart';

enum PasswordStrength { none, weak, medium, strong }

enum VaultSetupStatus { initial, inProgress, success, failure }

class VaultSetupState extends Equatable {
  const VaultSetupState({
    this.status = VaultSetupStatus.initial,
    this.password = '',
    this.confirmPassword = '',
    this.isPasswordVisible = false,
    this.isConfirmPasswordVisible = false,
    this.strength = PasswordStrength.none,
    this.errorMessage = '',
    this.isFormValid = false,
  });

  final VaultSetupStatus status;
  final String password;
  final String confirmPassword;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final PasswordStrength strength;
  final String errorMessage;
  final bool isFormValid;

  VaultSetupState copyWith({
    VaultSetupStatus? status,
    String? password,
    String? confirmPassword,
    bool? isPasswordVisible,
    bool? isConfirmPasswordVisible,
    PasswordStrength? strength,
    String? errorMessage,
    bool? isFormValid,
  }) {
    return VaultSetupState(
      status: status ?? this.status,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
      isConfirmPasswordVisible:
          isConfirmPasswordVisible ?? this.isConfirmPasswordVisible,
      strength: strength ?? this.strength,
      errorMessage: errorMessage ?? this.errorMessage,
      isFormValid: isFormValid ?? this.isFormValid,
    );
  }

  @override
  List<Object> get props => [
    status,
    password,
    confirmPassword,
    isPasswordVisible,
    isConfirmPasswordVisible,
    strength,
    errorMessage,
    isFormValid,
  ];
}
