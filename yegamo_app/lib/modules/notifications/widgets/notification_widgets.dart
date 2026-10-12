import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../models/notification_models.dart';

const _months = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Título del grupo por día: Hoy, Ayer o «12 oct».
String dayGroupTitle(DateTime date, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final d = date.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return '${d.day} ${_months[d.month - 1]}';
}

String timeLabel(DateTime date) {
  final d = date.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Agrupa avisos por día conservando el orden más reciente primero.
List<(String, List<NotificationItem>)> groupByDay(
  List<NotificationItem> items, {
  DateTime? now,
}) {
  final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final groups = <(String, List<NotificationItem>)>[];
  for (final item in sorted) {
    final title = dayGroupTitle(item.createdAt, now: now);
    if (groups.isNotEmpty && groups.last.$1 == title) {
      groups.last.$2.add(item);
    } else {
      groups.add((title, [item]));
    }
  }
  return groups;
}

(String, YgTileTone) _visual(NotificationKind kind) => switch (kind) {
  NotificationKind.leaveAlert => (YgIcons.reloj, YgTileTone.moss),
  NotificationKind.journey => (YgIcons.campana, YgTileTone.aloe),
  NotificationKind.privacy => (YgIcons.escudo, YgTileTone.normal),
  NotificationKind.service => (YgIcons.alerta, YgTileTone.aloe),
};

/// Fila de aviso (`.nt`): tile por tipo, título/hora, cuerpo y punto de no leído.
class NotificationRow extends StatelessWidget {
  const NotificationRow({super.key, required this.item, this.onTap});

  final NotificationItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = _visual(item.kind);
    final reduce = YgMotionScope.reduced(context);
    final d = reduce ? YgMotion.reduced : const Duration(milliseconds: 300);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YgTile(icon: icon, tone: tone, size: 32, iconSize: 17, radius: 9),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: YgText.secondary.copyWith(
                          fontSize: 13,
                          fontWeight: item.read
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: item.read ? YgColors.text2 : YgColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeLabel(item.createdAt),
                      style: YgText.meta.copyWith(color: YgColors.text3),
                    ),
                  ],
                ),
                if (item.message.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.message, style: YgText.meta),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: AnimatedScale(
              scale: item.read ? 0 : 1,
              duration: d,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: YgColors.cypress,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: '${item.title}. ${item.read ? 'Leído' : 'No leído'}',
      container: true,
      child: onTap == null || item.read
          ? row
          : YgPressable(onTap: onTap, child: row),
    );
  }
}
