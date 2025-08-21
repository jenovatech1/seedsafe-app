part of 'vault_setup_bloc.dart';

abstract class VaultSetupEvent extends Equatable {
  const VaultSetupEvent();
  @override
  List<Object> get props => [];
}

// Event saat input password berubah
class PasswordChanged extends VaultSetupEvent {
  const PasswordChanged(this.password);
  final String password;
  @override
  List<Object> get props => [password];
}

// Event saat input konfirmasi password berubah
class ConfirmPasswordChanged extends VaultSetupEvent {
  const ConfirmPasswordChanged(this.password);
  final String password;
  @override
  List<Object> get props => [password];
}

// Event untuk toggle visibilitas password
class PasswordVisibilityToggled extends VaultSetupEvent {}

// Event untuk toggle visibilitas konfirmasi password
class ConfirmPasswordVisibilityToggled extends VaultSetupEvent {}

// Event saat tombol submit ditekan
class VaultSubmitted extends VaultSetupEvent {}
