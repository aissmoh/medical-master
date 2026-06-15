import '../models/splash_content.dart';

class SplashController {
  const SplashController({this.displayDuration = const Duration(seconds: 5)});

  final Duration displayDuration;

  SplashContent get content => const SplashContent(
    title: 'Medical Master',
    subtitle: 'Votre assistant sante quotidien',
    description:
        'Centralisez vos informations medicales, suivez vos habitudes et accedez rapidement aux fonctionnalites essentielles.',
    animationAsset: 'assets/lottie/splash.json',
  );

  Future<void> start({required void Function() onCompleted}) async {
    await Future<void>.delayed(displayDuration);
    onCompleted();
  }
}
