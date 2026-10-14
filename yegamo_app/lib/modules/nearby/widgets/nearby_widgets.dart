import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../models/nearby_models.dart';
import 'freshness_label.dart';

String nearbyDistanceLabel(NearbyStop stop) => stop.distanceM == null
    ? 'Distancia no disponible'
    : stop.distanceM! >= 1000
    ? '${(stop.distanceM! / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
    : '${stop.distanceM!.round()} m';

String nearbySourceLabel(NearbyStop stop) =>
    stop.source == 'openstreetmap' ? 'OpenStreetMap' : 'Fuente no especificada';

/// Tarjeta de parada (`.scard`): cabecera seleccionable y una fila de
/// llegadas. Las llegadas solo se muestran si la fuente las entrega; el
/// contrato de paradas cercanas no incluye ETA, así que se dice con claridad.
class NearbyStopCard extends StatelessWidget {
  const NearbyStopCard({
    super.key,
    required this.stop,
    required this.selected,
    required this.onTap,
  });

  final NearbyStop stop;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(YgRadius.card),
        border: Border.all(
          color: selected ? YgColors.cypress : YgColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x0F2C3424),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ]
            : YgShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          YgPressable(
            onTap: onTap,
            semanticLabel: '${stop.name}, ${nearbyDistanceLabel(stop)}',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
              child: Row(
                children: [
                  YgTile(
                    icon: YgIcons.bus,
                    tone: selected ? YgTileTone.cypress : YgTileTone.normal,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: YgText.sub.copyWith(letterSpacing: -.15),
                        ),
                        const SizedBox(height: 2),
                        Text(nearbyDistanceLabel(stop), style: YgText.meta),
                        Text(
                          nearbySourceLabel(stop),
                          style: YgText.meta.copyWith(color: YgColors.text3),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const YgIcon(
                    YgIcons.chevronDerecha,
                    size: 16,
                    color: YgColors.text3,
                  ),
                ],
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: YgColors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Llegadas no disponibles',
                        style: YgText.secondary.copyWith(
                          fontWeight: FontWeight.w600,
                          color: YgColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      YgFreshnessLabel(stop.dataState),
                    ],
                  ),
                ),
                Text(
                  'Sin ETA',
                  style: YgText.eta.copyWith(
                    fontSize: 15,
                    color: YgColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Leyenda de etiquetas (`.legend`).
class NearbyLegend extends StatelessWidget {
  const NearbyLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          YgEstLabel(text: 'Estimado · datos con fecha'),
          YgSchedLabel(text: 'Programado · frecuencia'),
        ],
      ),
    );
  }
}
