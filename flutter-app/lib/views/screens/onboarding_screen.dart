import 'package:flutter/material.dart';

import '../../controllers/onboarding_controller.dart';
import '../widgets/onboarding/onboarding_action_bar.dart';
import '../widgets/onboarding/onboarding_page_card.dart';
import '../widgets/onboarding/onboarding_progress_indicator.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OnboardingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openNextScreen() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final horizontalPadding = constraints.maxWidth < 420
                    ? 20.0
                    : 28.0;
                final cardHeight = (constraints.maxHeight * 0.72).clamp(
                  340.0,
                  640.0,
                );

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    20,
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: SizedBox(
                              height: cardHeight,
                              child: PageView.builder(
                                controller: _controller.pageController,
                                itemCount: _controller.items.length,
                                onPageChanged: _controller.onPageChanged,
                                itemBuilder: (context, index) {
                                  return OnboardingPageCard(
                                    item: _controller.items[index],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OnboardingProgressIndicator(
                        itemCount: _controller.items.length,
                        currentIndex: _controller.currentIndex,
                      ),
                      const SizedBox(height: 22),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: OnboardingActionBar(
                          isLastPage: _controller.isLastPage,
                          onSkip: _controller.skipToLastPage,
                          onNext: _controller.nextPage,
                          onFinish: _openNextScreen,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
