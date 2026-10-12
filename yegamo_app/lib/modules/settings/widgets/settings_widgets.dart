import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../models/settings_models.dart';

/// Tarjeta de cuenta (`.acct`): avatar 48 + estado de sesión.
class SettingsAccountCard extends StatelessWidget {
  const SettingsAccountCard({super.key, required this.guest, this.onSignOut});

  final bool guest;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: YgColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: YgColors.aloe,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const YgIcon(YgIcons.usuario, size: 24, color: YgColors.moss),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guest ? 'Modo invitado' : 'Cuenta conectada',
                    style: YgText.sub,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    guest
                        ? 'Datos locales en este dispositivo. Crea una cuenta para sincronizar guardados y rutinas.'
                        : 'Tus guardados y rutinas se sincronizan.',
                    style: YgText.meta,
                  ),
                ],
              ),
            ),
            if (onSignOut != null) ...[
              const SizedBox(width: 12),
              YgButton(
                label: 'Cerrar sesión',
                size: YgButtonSize.sm,
                variant: YgButtonVariant.secondary,
                onPressed: onSignOut,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chips del catálogo de estados; solo se monta con `demoCatalogEnabled`.
class SettingsDemoCatalog extends StatelessWidget {
  const SettingsDemoCatalog({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in demoStateCatalog)
            Semantics(
              label: '${entry.name}. ${entry.description}',
              excludeSemantics: true,
              child: Tooltip(
                message: entry.description,
                child: YgChip(label: entry.name),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pie (`.foot`): símbolo de marca y nota de datos de demostración.
class SettingsFooter extends StatelessWidget {
  const SettingsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 32),
      child: Column(
        children: [
          YgMark(size: 32),
          SizedBox(height: 8),
          Text(
            'yeGamo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: YgColors.text,
            ),
          ),
          SizedBox(height: 8),
          SizedBox(
            width: 280,
            child: Text(
              'Los datos de demostración solo pueden activarse explícitamente en desarrollo o pruebas; nunca representan disponibilidad productiva.',
              textAlign: TextAlign.center,
              style: YgText.meta,
            ),
          ),
        ],
      ),
    );
  }
}
