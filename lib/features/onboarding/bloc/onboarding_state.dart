part of 'onboarding_bloc.dart';

// Kelas dasar untuk state halaman onboarding
abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object> get props => [];
}

class OnboardingInitial extends OnboardingState {}

class OnboardingNavigateToCreateVault extends OnboardingState {}
