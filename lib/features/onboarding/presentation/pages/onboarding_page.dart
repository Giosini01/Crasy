import 'package:app_incontri/core/errors/error_message_mapper.dart';
import 'package:app_incontri/core/theme/app_colors.dart';
import 'package:app_incontri/core/theme/app_radius.dart';
import 'package:app_incontri/core/theme/app_spacing.dart';
import 'package:app_incontri/features/auth/presentation/providers/auth_providers.dart';
import 'package:app_incontri/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:app_incontri/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  DateTime? _birthDate;
  GenderIdentity? _gender;
  InterestPreference? _interestedIn;
  int _step = 0;

  static const int _stepsCount = 5;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 25, now.month, now.day);
    final firstDate = DateTime(now.year - 100);
    final lastDate = now;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selectedDate != null) {
      setState(() {
        _birthDate = selectedDate;
      });
    }
  }

  String? _validateCurrentStep() {
    switch (_step) {
      case 0:
        return OnboardingValidators.validateName(_nameController.text);
      case 1:
        return OnboardingValidators.validateBirthDate(_birthDate);
      case 2:
        return OnboardingValidators.validateGender(_gender);
      case 3:
        return OnboardingValidators.validateInterest(_interestedIn);
      case 4:
        return OnboardingValidators.validateCity(_cityController.text);
    }

    return null;
  }

  Future<void> _goNext() async {
    final validationMessage = _validateCurrentStep();

    if (validationMessage != null) {
      _showValidationError(validationMessage);
      return;
    }

    if (_step < _stepsCount - 1) {
      setState(() {
        _step++;
      });
      return;
    }

    final authState = ref.read(authStateProvider);

    if (authState is! AuthenticatedAuthState) {
      _showValidationError('Sessione non valida. Accedi di nuovo.');
      return;
    }

    await ref
        .read(onboardingControllerProvider.notifier)
        .completeOnboarding(
          userId: authState.user.id,
          name: _nameController.text.trim(),
          birthDate: _birthDate!,
          gender: _gender!,
          interestedIn: _interestedIn!,
          city: _cityController.text.trim(),
        );
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onboardingAction = ref.watch(onboardingControllerProvider);
    final isLoading = onboardingAction.isLoading;
    final errorText = onboardingAction.hasError
        ? ErrorMessageMapper.map(onboardingAction.error!)
        : null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.background, AppColors.surfaceMuted],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SizedBox(
                    height: 480,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_step + 1} / $_stepsCount',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          LinearProgressIndicator(
                            value: (_step + 1) / _stepsCount,
                            minHeight: 4,
                            color: AppColors.accent,
                            backgroundColor: AppColors.surfaceMuted,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: KeyedSubtree(
                                key: ValueKey(_step),
                                child: _OnboardingStepContent(
                                  step: _step,
                                  nameController: _nameController,
                                  birthDate: _birthDate,
                                  gender: _gender,
                                  interestedIn: _interestedIn,
                                  cityController: _cityController,
                                  onBirthDateTap: _pickBirthDate,
                                  onGenderChanged: (value) {
                                    setState(() {
                                      _gender = value;
                                    });
                                  },
                                  onInterestedInChanged: (value) {
                                    setState(() {
                                      _interestedIn = value;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              errorText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              if (_step > 0)
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            setState(() {
                                              _step--;
                                            });
                                          },
                                    child: const Text('Indietro'),
                                  ),
                                ),
                              if (_step > 0)
                                const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _goNext,
                                  child: Text(
                                    isLoading
                                        ? 'Salvataggio...'
                                        : _step == _stepsCount - 1
                                        ? 'Completa'
                                        : 'Avanti',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingStepContent extends StatelessWidget {
  const _OnboardingStepContent({
    required this.step,
    required this.nameController,
    required this.birthDate,
    required this.gender,
    required this.interestedIn,
    required this.cityController,
    required this.onBirthDateTap,
    required this.onGenderChanged,
    required this.onInterestedInChanged,
  });

  final int step;
  final TextEditingController nameController;
  final DateTime? birthDate;
  final GenderIdentity? gender;
  final InterestPreference? interestedIn;
  final TextEditingController cityController;
  final VoidCallback onBirthDateTap;
  final ValueChanged<GenderIdentity?> onGenderChanged;
  final ValueChanged<InterestPreference?> onInterestedInChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    switch (step) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Come ti chiami?', style: theme.textTheme.displayMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Usa il nome con cui vuoi farti riconoscere oggi.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quando sei nato?', style: theme.textTheme.displayMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Daily e riservata ai maggiorenni.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            InkWell(
              onTap: onBirthDateTap,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Data di nascita'),
                child: Text(
                  birthDate == null
                      ? 'Seleziona una data'
                      : MaterialLocalizations.of(
                          context,
                        ).formatMediumDate(birthDate!),
                ),
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Come ti identifichi?', style: theme.textTheme.displayMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Scegli l\'opzione che ti rappresenta meglio.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: GenderIdentity.values
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value.label),
                      selected: gender == value,
                      onSelected: (_) => onGenderChanged(value),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chi vuoi conoscere?', style: theme.textTheme.displayMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Impostiamo solo la preferenza iniziale.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: InterestPreference.values
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value.label),
                      selected: interestedIn == value,
                      onSelected: (_) => onInterestedInChanged(value),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dove vivi?', style: theme.textTheme.displayMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Ci basta una citta o una zona, non la posizione precisa.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'Citta o zona'),
            ),
          ],
        );
    }

    return const SizedBox.shrink();
  }
}
