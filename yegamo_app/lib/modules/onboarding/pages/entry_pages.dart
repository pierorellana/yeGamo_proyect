import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../env/config/app_config.dart';
import '../../../shared/design_system/yg_components.dart';
import '../../../shared/navigation/app_navigator.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../../shared/storage/local_storage.dart';
import '../providers/onboarding_view_model.dart';
import '../services/onboarding_repository.dart';
import '../widgets/entry_frame.dart';
import '../widgets/onboarding_scenes.dart';
import '../widgets/scene_clock.dart';
import '../widgets/splash_scene.dart';

class TaskFiveRootPage extends StatefulWidget {
  const TaskFiveRootPage({super.key});

  @override
  State<TaskFiveRootPage> createState() => _TaskFiveRootPageState();
}

class _TaskFiveRootPageState extends State<TaskFiveRootPage> {
  late final Future<bool> _completion;

  @override
  void initState() {
    super.initState();
    _completion = OnboardingRepository(storage: context.read<LocalStorage>())
        .isCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completion,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: YgBackground());
        }
        return snapshot.data!
            ? const AppNavigator()
            : const EntryBootstrapPage();
      },
    );
  }
}

class EntryBootstrapPage extends StatefulWidget {
  const EntryBootstrapPage({super.key});

  @override
  State<EntryBootstrapPage> createState() => _EntryBootstrapPageState();
}

class _EntryBootstrapPageState extends State<EntryBootstrapPage> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final completed = await OnboardingRepository(
      storage: context.read<LocalStorage>(),
    ).isCompleted();
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacementNamed(completed ? AppRoutes.home : AppRoutes.splash);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: YgBackground());
  }
}

/// 01-splash: 3,5 s de tipografía; se salta con un toque.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;
  bool _armed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armed) return;
    _armed = true;
    final reduce =
        context.read<AppConfig>().reduceMotion || YgMotionScope.reduced(context);
    _timer = Timer(
      reduce ? Duration.zero : const Duration(milliseconds: 3500),
      _continue,
    );
  }

  void _continue() {
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final demo = context.read<AppConfig>().demoDataEnabled;
    return Scaffold(
      body: YgBackground(
        child: Semantics(
          button: true,
          label: 'yeGamo · toca para continuar',
          child: GestureDetector(
            key: const ValueKey('splash_continue'),
            behavior: HitTestBehavior.opaque,
            onTap: _continue,
            child: ProtoFrame(
              child: SceneClockHost(
                builder: (context, clock) => SplashScene(
                  clock: clock,
                  // Pie solo si los datos son de demostración; en otro caso se omite.
                  footer: demo ? 'Guayaquil · datos de demostración' : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 02a/b/c-onboarding: tres páginas deslizables con carril de 0,7 s.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;

  static const _last = 2;

  bool get _reduceMotion =>
      context.read<AppConfig>().reduceMotion || YgMotionScope.reduced(context);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    await context.read<OnboardingViewModel>().complete();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.permissions);
  }

  void _goTo(int page) {
    context.read<OnboardingViewModel>().setPage(page);
    if (_reduceMotion) {
      _pageController.jumpToPage(page);
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 700),
      curve: YgMotion.easeOut,
    );
  }

  void _next() {
    final vm = context.read<OnboardingViewModel>();
    if (vm.page >= _last) {
      _complete();
      return;
    }
    _goTo(vm.page + 1);
  }

  void _prev() {
    final vm = context.read<OnboardingViewModel>();
    if (vm.page > 0) _goTo(vm.page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnboardingViewModel>();
    final page = vm.page;
    final first = page == 0;
    final last = page == _last;
    final reduced = _reduceMotion;
    final quick = reduced ? YgMotion.reduced : const Duration(milliseconds: 500);
    return Scaffold(
      body: YgBackground(
        child: YgEnter(
          kind: YgEnterKind.fade,
          child: ProtoFrame(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                      key: const ValueKey('onboarding_pages'),
                      controller: _pageController,
                      itemCount: obSlides.length,
                      onPageChanged: context.read<OnboardingViewModel>().setPage,
                      itemBuilder: (context, index) =>
                          ObPage(index: index, active: page == index),
                    ),
                  ),
                  Positioned(
                    top: 56,
                    left: 16,
                    right: 16,
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const EntryBrand(),
                        AnimatedOpacity(
                          opacity: last ? 0 : 1,
                          duration: reduced
                              ? YgMotion.reduced
                              : const Duration(milliseconds: 300),
                          child: AnimatedSlide(
                            offset: Offset(0, last ? -6 / 36 : 0),
                            duration: reduced
                                ? YgMotion.reduced
                                : const Duration(milliseconds: 300),
                            child: IgnorePointer(
                              ignoring: last,
                              child: _SkipButton(
                                key: const ValueKey('onboarding_skip'),
                                onTap: _complete,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < obSlides.length; index++)
                          Padding(
                            padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
                            child: AnimatedContainer(
                              duration: reduced
                                  ? YgMotion.reduced
                                  : const Duration(milliseconds: 450),
                              curve: const Cubic(.34, 1.4, .5, 1),
                              width: index == page ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: index == page
                                    ? YgColors.moss
                                    : YgColors.handle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 40,
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: quick,
                          curve: YgMotion.easeOut,
                          width: first ? 0 : 56,
                          height: 56,
                          child: AnimatedOpacity(
                            opacity: first ? 0 : 1,
                            duration: reduced
                                ? YgMotion.reduced
                                : const Duration(milliseconds: 300),
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.centerLeft,
                                minWidth: 56,
                                maxWidth: 56,
                                child: IgnorePointer(
                                  ignoring: first,
                                  child: _BackButton(
                                    key: const ValueKey('onboarding_back'),
                                    onTap: _prev,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: quick,
                          curve: YgMotion.easeOut,
                          width: first ? 0 : 12,
                        ),
                        Expanded(
                          child: _NextButton(
                            key: const ValueKey('onboarding_next'),
                            label: last ? 'Empezar' : 'Continuar',
                            onTap: vm.saving ? null : _next,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YgPressable(
      onTap: onTap,
      semanticLabel: 'Saltar',
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: YgColors.border),
        ),
        child: const Text(
          'Saltar',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -.14,
            color: YgColors.cypress,
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YgPressable(
      onTap: onTap,
      semanticLabel: 'Anterior',
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: YgColors.borderStrong),
          boxShadow: const [
            BoxShadow(color: Color(0x0F2C3424), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: const YgIcon(YgIcons.flechaAtras, size: 20, color: YgColors.moss),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? .4 : 1,
      child: YgPressable(
        onTap: onTap,
        semanticLabel: label,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: YgColors.moss,
            borderRadius: BorderRadius.circular(28),
            boxShadow: onTap == null ? null : YgShadows.pri,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const YgIcon(YgIcons.flechaAdelante, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
