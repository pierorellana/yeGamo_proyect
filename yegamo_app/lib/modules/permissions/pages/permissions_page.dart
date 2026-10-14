import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/map/yg_map_host.dart';
import '../../../shared/map/yg_map_view.dart';
import '../../../shared/navigation/app_routes.dart';
import '../../onboarding/widgets/entry_frame.dart';
import '../models/permission_models.dart';
import '../providers/permission_view_model.dart';
import '../widgets/permission_radar.dart';

/// 03-permisos: radar sobre el mapa atenuado y hoja inferior.
///
/// La acción principal delega directamente en el permiso nativo del sistema
/// operativo; esta pantalla solo explica el uso y ofrece el origen manual.
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  Future<void> _request() async {
    await context.read<PermissionViewModel>().request();
    if (!mounted) return;
    final state = context.read<PermissionViewModel>().state;
    if (state == PermissionUxState.granted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.root);
    }
  }

  void _continueManually() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.root);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PermissionViewModel>();
    final requesting = vm.state == PermissionUxState.requesting;
    final denied = vm.state == PermissionUxState.denied;
    final error = vm.state == PermissionUxState.error;
    final reduced = YgMotionScope.reduced(context);
    return YgMapBinding(
      // perm: vb = 844 − (8 + 424) − 16
      view: const YgMapView(mode: YgMapMode.perm, visibleBottom: 396),
      child: YgMapScaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // `.dim.on`: capa #F4F5F1 al 45 % sobre el mapa (0,6 s).
            IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: .45),
                duration: reduced
                    ? YgMotion.reduced
                    : const Duration(milliseconds: 600),
                builder: (context, v, _) =>
                    ColoredBox(color: YgColors.page.withValues(alpha: v)),
              ),
            ),
            YgEnter(
              kind: YgEnterKind.fade,
              child: ProtoFrame(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const PermissionRadar(),
                    const Positioned(
                      top: 56,
                      left: 16,
                      height: 44,
                      child: _BrandPill(),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      height: 456,
                      child: _Sheet(
                        denied: denied,
                        error: error,
                        requesting: requesting,
                        onAllow: _request,
                        onManual: _continueManually,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPill extends StatelessWidget {
  const _BrandPill();

  @override
  Widget build(BuildContext context) {
    return const YgGlass(
      radius: 22,
      height: 44,
      padding: EdgeInsets.fromLTRB(10, 0, 16, 0),
      child: EntryBrand(),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.denied,
    required this.error,
    required this.requesting,
    required this.onAllow,
    required this.onManual,
  });

  final bool denied;
  final bool error;
  final bool requesting;
  final VoidCallback onAllow;
  final VoidCallback onManual;

  static const _rows = [
    (YgIcons.reloj, 'Solo mientras usas yeGamo'),
    (YgIcons.escudo, 'Sin historial de ubicaciones por defecto'),
    (YgIcons.preferencias, 'Puedes cambiarlo cuando quieras'),
  ];

  @override
  Widget build(BuildContext context) {
    final reduced = YgMotionScope.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduced ? YgMotion.reduced : const Duration(milliseconds: 650),
      curve: const Cubic(.22, 1.06, .36, 1),
      builder: (context, v, child) => reduced
          ? Opacity(opacity: v.clamp(0.0, 1.0), child: child)
          : Transform.translate(
              offset: Offset(0, 456 * 1.05 * (1 - v)),
              child: child,
            ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(color: Color(0x142C3424), spreadRadius: .5),
            BoxShadow(
              color: Color(0x1F2C3424),
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xF7FFFFFF),
                    Color(0xF7FFFFFF),
                    Color(0xF7F6F8F2),
                  ],
                  stops: [0, .55, 1],
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 36,
                        height: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: YgColors.handle,
                            borderRadius: BorderRadius.all(Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: _body(),
                    ),
                  ),
                  _foot(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return YgStagger(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: YgColors.cypress,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: const YgIcon(YgIcons.navegar, size: 26, color: Colors.white),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
            '¿Usamos tu ubicación?',
            style: TextStyle(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -.44,
              color: YgColors.text,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'Para mostrarte paradas cercanas y calcular desde dónde sales.',
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              letterSpacing: -.15,
              color: YgColors.text2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 24),
          child: Column(
            children: [
              for (var i = 0; i < _rows.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 24),
                    child: Row(
                      children: [
                        YgIcon(_rows[i].$1, size: 20, color: YgColors.cypress),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _rows[i].$2,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              letterSpacing: -.14,
                              color: YgColors.moss,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (denied)
          const YgBanner(
            title: 'Puedes continuar con un origen manual.',
            icon: YgIcons.ubicacionDesactivada,
            tone: YgBannerTone.off,
          ),
        if (error)
          const YgBanner(
            title: 'No pudimos consultar el permiso. Puedes reintentar o continuar manualmente.',
            icon: YgIcons.alerta,
            tone: YgBannerTone.off,
          ),
      ],
    );
  }

  Widget _foot() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00FFFFFF), Color(0xE6FFFFFF)],
          stops: [0, .4],
        ),
      ),
      child: Column(
        children: [
          YgButton(
            key: const ValueKey('permission_allow'),
            label: requesting ? 'Solicitando…' : 'Permitir ubicación',
            semanticLabel: requesting
                ? 'Solicitando…'
                : 'Permitir mientras uso la app',
            expand: true,
            onPressed: requesting ? null : onAllow,
          ),
          const SizedBox(height: 8),
          Opacity(
            opacity: requesting ? .4 : 1,
            child: YgPressable(
              key: const ValueKey('permission_manual'),
              onTap: requesting ? null : onManual,
              semanticLabel: 'Continuar con origen manual',
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: const Text(
                  'Elegir origen manualmente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.15,
                    color: YgColors.cypress,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
