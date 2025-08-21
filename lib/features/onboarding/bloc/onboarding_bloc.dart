import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

// Mengimpor file state dan event yang kita buat tadi
part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingNavigateToRestore extends OnboardingState {}

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(OnboardingInitial()) {
    on<CreateVaultTapped>(_onCreateVaultTapped);
    on<RestoreFromBackupTapped>(_onRestoreFromBackupTapped);

    on<OnboardingReset>((event, emit) {
      // Reset state ke initial
      emit(OnboardingInitial());
    });
  }

  void _onCreateVaultTapped(
    CreateVaultTapped event,
    Emitter<OnboardingState> emit,
  ) {
    emit(OnboardingNavigateToCreateVault());
  }

  void _onRestoreFromBackupTapped(
    RestoreFromBackupTapped event,
    Emitter<OnboardingState> emit,
  ) {
    emit(OnboardingNavigateToRestore());
  }
}
