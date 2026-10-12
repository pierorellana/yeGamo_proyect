enum OnboardingStep { understand, compare, control }

class OnboardingCopy {
  const OnboardingCopy({
    required this.step,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.asset,
  });

  final OnboardingStep step;
  final String eyebrow;
  final String title;
  final String message;
  final String asset;
}

const onboardingCopies = <OnboardingCopy>[
  OnboardingCopy(
    step: OnboardingStep.understand,
    eyebrow: 'PLANIFICA CON CONFIANZA',
    title: 'Llega sin adivinar.',
    message: 'Compara opciones de movilidad con la calidad de datos siempre visible.',
    asset: 'assets/ilustraciones/png/onboarding-mini-ruta@3x.png',
  ),
  OnboardingCopy(
    step: OnboardingStep.compare,
    eyebrow: 'COMPARA LO IMPORTANTE',
    title: 'Tu tiempo, tus preferencias.',
    message: 'Elige entre menos caminata, menos transbordos o una salida más confiable.',
    asset: 'assets/ilustraciones/png/onboarding-mini-ruta@3x.png',
  ),
  OnboardingCopy(
    step: OnboardingStep.control,
    eyebrow: 'TÚ TIENES EL CONTROL',
    title: 'La ubicación es opcional.',
    message: 'Activa ubicación mientras usas la app o continúa con un origen manual.',
    asset: 'assets/ilustraciones/png/onboarding-mini-ruta@3x.png',
  ),
];
