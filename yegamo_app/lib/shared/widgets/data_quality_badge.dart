import 'package:flutter/material.dart';

import '../design_system/yg_components.dart';
import '../models/data_state.dart';

/// Etiqueta de calidad del dato con el lenguaje del prototipo:
/// `.live` (punto con pulso), `.est` (círculo punteado) y `.sched`
/// (cuadro sólido). «EN VIVO» solo aparece con dato actual, vehículo en
/// vivo, fuente autorizada y `observedAt`; nunca depende solo del color.
class DataQualityBadge extends StatelessWidget {
  const DataQualityBadge({
    super.key,
    required this.dataState,
    this.liveVehicle = false,
    this.observedAt,
    this.sourceAuthorized = false,
  });

  final DataState dataState;
  final bool liveVehicle;
  final DateTime? observedAt;
  final bool sourceAuthorized;

  bool get _canSayLive =>
      dataState == DataState.current &&
      liveVehicle &&
      sourceAuthorized &&
      observedAt != null;

  String get label {
    if (_canSayLive) return 'EN VIVO';
    return switch (dataState) {
      DataState.current => 'ACTUAL',
      DataState.stale => 'DESACTUALIZADO',
      DataState.degraded => 'DEGRADADO',
      DataState.offlineCache => 'OFFLINE_CACHE',
      DataState.unavailable => 'NO DISPONIBLE',
    };
  }

  Widget _marker() {
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .4,
    );
    if (_canSayLive) {
      return DefaultTextStyle.merge(
        style: style,
        child: YgLiveLabel(text: label),
      );
    }
    return switch (dataState) {
      DataState.current => _Icon(YgIcons.check, label, YgColors.cypress),
      DataState.stale => DefaultTextStyle.merge(
        style: style,
        child: YgEstLabel(text: label),
      ),
      DataState.degraded => _Icon(YgIcons.alerta, label, YgColors.text2),
      DataState.offlineCache => DefaultTextStyle.merge(
        style: style,
        child: YgSchedLabel(text: label),
      ),
      DataState.unavailable => _Icon(YgIcons.cerrar, label, YgColors.clay),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _canSayLive
              ? YgColors.cypress.withValues(alpha: .1)
              : YgColors.fill3,
          borderRadius: BorderRadius.circular(YgRadius.pill),
          border: Border.all(
            color: _canSayLive
                ? YgColors.cypress.withValues(alpha: .25)
                : YgColors.border,
          ),
        ),
        child: _marker(),
      ),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon(this.icon, this.text, this.color);

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        YgIcon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .4,
            color: color,
          ),
        ),
      ],
    );
  }
}
