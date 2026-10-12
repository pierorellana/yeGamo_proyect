import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/models/data_state.dart';

/// Etiqueta de frescura de un dato (`live` / `est` / `sched` del prototipo).
///
/// Nunca devuelve «En vivo»: ninguna superficie de descubrimiento recibe una
/// posición de vehículo con fuente autorizada y timestamp, así que solo se
/// usan las variantes «estimado» y «programado».
class YgFreshnessLabel extends StatelessWidget {
  const YgFreshnessLabel(this.state, {super.key});

  final DataState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      DataState.current => const YgEstLabel(text: 'Datos actuales'),
      DataState.stale => const YgEstLabel(text: 'Desactualizado'),
      DataState.degraded => const YgEstLabel(text: 'Datos limitados'),
      DataState.offlineCache => const YgSchedLabel(text: 'Sin conexión'),
      DataState.unavailable => const YgSchedLabel(text: 'No disponible'),
    };
  }
}
