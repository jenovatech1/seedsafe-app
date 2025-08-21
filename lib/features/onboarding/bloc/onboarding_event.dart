part of 'onboarding_bloc.dart';

// Kelas dasar abstrak untuk semua event
abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object> get props => [];
}

// Event saat pengguna menekan tombol "Create New Vault"
class CreateVaultTapped extends OnboardingEvent {}

// Event saat pengguna menekan tombol "Restore from Backup"
class RestoreFromBackupTapped extends OnboardingEvent {}

class OnboardingReset extends OnboardingEvent {}
