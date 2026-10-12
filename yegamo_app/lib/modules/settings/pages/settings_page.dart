import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/session/session_service.dart';
import '../../../shared/widgets/yg_page.dart';
import '../providers/settings_view_model.dart';
import '../widgets/settings_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsViewModel>().load();
    });
  }

  Future<void> _deleteData() async {
    final confirmed = await showYgConfirmSheet(
      context,
      title: 'Eliminar datos de yeGamo',
      message:
          'Se eliminarán los datos locales de este dispositivo. Si tienes cuenta, también se solicitará la eliminación de tu cuenta al API. Esta acción no borra datos de otras aplicaciones.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final vm = context.read<SettingsViewModel>();
    await vm.deleteData();
    if (!mounted) return;
    YgToast.show(context, vm.state?.message ?? 'Datos eliminados');
  }

  Future<void> _exportData() async {
    final vm = context.read<SettingsViewModel>();
    await vm.exportData();
    if (!mounted) return;
    final exported = vm.state?.lastExport;
    await showYgModalSheet<void>(
      context,
      builder: (sheetContext) => YgSheetBody(
        title: 'Exportación lista',
        rightLabel: 'Cerrar',
        onRight: () => Navigator.of(sheetContext).pop(),
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: YgColors.fill3,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                exported ?? '{}',
                style: YgText.meta.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SettingsViewModel>();
    final state = vm.state;
    final session = context.watch<SessionManager>();

    if (state == null) {
      return YgPage(
        children: [
          YgNavRow(leading: _back(context)),
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: YgSpinner(size: 28, width: 3)),
          ),
        ],
      );
    }

    return YgPage(
      bottomPadding: 48,
      children: [
        YgNavRow(leading: _back(context)),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Ajustes', style: YgText.largeTitle),
        ),
        YgEnter(
          child: SettingsAccountCard(
            guest: session.isGuest,
            onSignOut: session.isGuest ? null : vm.signOut,
          ),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 12),
          YgBanner(
            title: state.message!,
            icon: YgIcons.alerta,
            tone: YgBannerTone.warn,
          ),
        ],
        const YgGroupHeader('Privacidad'),
        YgGroup(
          children: [
            YgListRow(
              icon: YgIcons.ubicacion,
              title: 'Consentir ubicación precisa durante el viaje',
              subtitle:
                  'Es opcional y no se guarda en el dispositivo.',
              trailing: YgSwitch(
                value: state.locationConsent,
                semanticLabel: 'Consentir ubicación precisa durante el viaje',
                onChanged: vm.setLocationConsent,
              ),
            ),
            YgListRow(
              icon: YgIcons.descargar,
              title: 'Exportar mis datos locales',
              showChevron: true,
              onTap: _exportData,
            ),
            YgListRow(
              icon: YgIcons.eliminar,
              tone: YgTileTone.clay,
              title: 'Eliminar mis datos',
              titleStyle: YgText.body.copyWith(
                fontWeight: FontWeight.w500,
                color: YgColors.clay,
              ),
              onTap: vm.loading ? null : _deleteData,
            ),
          ],
        ),
        const YgGroupHeader('Accesibilidad'),
        YgGroup(
          children: [
            YgListRow(
              icon: YgIcons.reducirMovimiento,
              title: 'Reducir movimiento',
              subtitle: 'Sin cámara 3D ni animaciones decorativas.',
              value: state.reduceMotion ? 'Activado' : 'Sistema',
            ),
          ],
        ),
        if (state.demoCatalogEnabled) ...[
          const YgGroupHeader('Catálogo de estados de desarrollo'),
          const SettingsDemoCatalog(),
        ],
        const SettingsFooter(),
      ],
    );
  }

  Widget _back(BuildContext context) => YgIconButton(
    icon: YgIcons.atras,
    style: YgIconButtonStyle.secondary,
    semanticLabel: 'Volver',
    onPressed: () => Navigator.of(context).maybePop(),
  );
}
