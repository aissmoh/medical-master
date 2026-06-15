import 'package:flutter/material.dart';

import '../models/onboarding_item.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingController() : pageController = PageController();

  final PageController pageController;

  final List<OnboardingItem> items = const [
    OnboardingItem(
      title: 'Suivi intelligent des malades',
      description:
          'Une solution IoT et mobile pour centraliser les donnees essentielles et mieux accompagner chaque patient.',
      imageAsset: 'assets/onBoarding/onBoarding1.png',
    ),
    OnboardingItem(
      title: 'Surveillance medicale connectee',
      description:
          'Un systeme intelligent pour suivre en continu les patients et faciliter les decisions cliniques au quotidien.',
      imageAsset: 'assets/onBoarding/onBoarding2.png',
    ),
    OnboardingItem(
      title: 'Telesurveillance medicale embarquee',
      description:
          'Une plateforme embarquee et mobile pour garder un lien medical fiable, moderne et accessible partout.',
      imageAsset: 'assets/onBoarding/onBoarding3.png',
    ),
  ];

  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  bool get isLastPage => _currentIndex == items.length - 1;

  void onPageChanged(int index) {
    if (_currentIndex == index) {
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }

  Future<void> nextPage() async {
    if (isLastPage) {
      return;
    }

    await pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> skipToLastPage() async {
    if (isLastPage) {
      return;
    }

    await pageController.animateToPage(
      items.length - 1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }
}
