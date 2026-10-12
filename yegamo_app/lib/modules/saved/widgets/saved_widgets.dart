import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../models/saved_models.dart';

/// Clasificación visual de un lugar guardado (solo por etiqueta; no se
/// inventan direcciones ni distancias).
class SavedKind {
  const SavedKind._(this.icon, this.pinned, this.tone);

  final String icon;
  final bool pinned;
  final YgTileTone tone;

  static SavedKind of(SavedPlace place) {
    final l = place.label.trim().toLowerCase();
    if (l == 'casa' || l == 'hogar') {
      return const SavedKind._(YgIcons.casa, true, YgTileTone.moss);
    }
    if (l == 'trabajo') {
      return const SavedKind._(YgIcons.trabajo, true, YgTileTone.cypress);
    }
    if (l.contains('universidad') || l.contains('colegio')) {
      return const SavedKind._(YgIcons.universidad, false, YgTileTone.normal);
    }
    if (l.contains('gimnasio') || l.contains('gym')) {
      return const SavedKind._(YgIcons.gimnasio, false, YgTileTone.normal);
    }
    return const SavedKind._(YgIcons.guardado, false, YgTileTone.normal);
  }
}

/// Tarjeta de lugar fijo (`.pc`): tile 32 + nombre + descripción.
class SavedPinnedCard extends StatelessWidget {
  const SavedPinnedCard({super.key, required this.place, this.onRemove});

  final SavedPlace place;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final kind = SavedKind.of(place);
    return YgPressable(
      onTap: null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: YgColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                YgTile(
                  icon: kind.icon,
                  tone: kind.tone,
                  size: 32,
                  iconSize: 17,
                  radius: 9,
                ),
                if (onRemove != null)
                  YgIconButton(
                    icon: YgIcons.eliminar,
                    style: YgIconButtonStyle.plain,
                    size: 32,
                    iconSize: 16,
                    color: YgColors.text3,
                    semanticLabel: 'Eliminar ${place.label}',
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(place.label, style: YgText.sub),
            if (place.subtitle != null)
              Text(
                place.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YgText.meta,
              ),
          ],
        ),
      ),
    );
  }
}

/// Fila de lugar (`.li`) con acción de eliminar.
class SavedPlaceRow extends StatelessWidget {
  const SavedPlaceRow({super.key, required this.place, this.onRemove});

  final SavedPlace place;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final kind = SavedKind.of(place);
    return YgListRow(
      icon: kind.icon,
      title: place.label,
      subtitle: place.subtitle,
      trailing: YgIconButton(
        icon: YgIcons.eliminar,
        style: YgIconButtonStyle.plain,
        size: 36,
        iconSize: 16,
        color: YgColors.text3,
        semanticLabel: 'Eliminar ${place.label}',
        onPressed: onRemove,
      ),
    );
  }
}
