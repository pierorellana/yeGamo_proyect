import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/widgets/yg_page.dart';
import '../models/commute_models.dart';

const _dayLetters = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _dayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _dayShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

String formatHm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

/// Texto de «próxima alerta» de una rutina (hora local del dispositivo).
String nextAlertText(CommuteRoutine routine, {DateTime? now}) {
  if (routine.isPaused) return 'En pausa · sin avisos';
  final current = (now ?? DateTime.now()).toLocal();
  final next = routine.nextAlertUtc(now: current).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(next.year, next.month, next.day);
  final diff = day.difference(today).inDays;
  final when = switch (diff) {
    0 => 'Hoy',
    1 => 'Mañana',
    _ => _dayShort[next.weekday - 1],
  };
  return '$when · aviso ${formatHm(next.hour, next.minute)}';
}

/// Día de la semana (`.dd`): 28 px, o 40 px en la hoja de edición.
class RoutineDay extends StatelessWidget {
  const RoutineDay({
    super.key,
    required this.letter,
    required this.on,
    this.big = false,
    this.onTap,
    this.semanticLabel,
  });

  final String letter;
  final bool on;
  final bool big;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduce = YgMotionScope.reduced(context);
    final s = big ? 40.0 : 28.0;
    final dot = AnimatedContainer(
      duration: reduce ? YgMotion.reduced : const Duration(milliseconds: 300),
      curve: const Cubic(.34, 1.5, .6, 1),
      width: s,
      height: s,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: on ? YgColors.moss : YgColors.fill3,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: big ? 13 : 11,
          fontWeight: FontWeight.w600,
          color: on ? Colors.white : YgColors.text3,
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(label: semanticLabel, selected: on, child: dot);
    }
    return YgPressable(onTap: onTap, semanticLabel: semanticLabel, child: dot);
  }
}

/// Fila de 7 días `.days` (L M X J V S D).
class RoutineDays extends StatelessWidget {
  const RoutineDays({super.key, required this.days, this.big = false, this.onToggle});

  final List<int> days;
  final bool big;
  final ValueChanged<int>? onToggle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: big
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.start,
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0 && !big) const SizedBox(width: 4),
          RoutineDay(
            letter: _dayLetters[i],
            big: big,
            on: days.contains(i + 1),
            semanticLabel: _dayNames[i],
            onTap: onToggle == null ? null : () => onToggle!(i + 1),
          ),
        ],
      ],
    );
  }
}

/// Tarjeta de rutina (`.rcard`).
class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    required this.onToggle,
    required this.onEdit,
  });

  final CommuteRoutine routine;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final paused = routine.isPaused;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: paused ? .6 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: YgColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(routine.label, style: YgText.sub),
                      const SizedBox(height: 2),
                      Text(
                        '${routine.origin} → ${routine.destination}',
                        style: YgText.meta,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                YgSwitch(
                  value: !paused,
                  semanticLabel: 'Activar rutina ${routine.label}',
                  onChanged: onToggle,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RoutineDays(days: routine.days),
                YgLink('Editar', onTap: onEdit),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: YgColors.divider),
            YgPressable(
              onTap: onEdit,
              semanticLabel: 'Editar ${routine.label}',
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const YgIcon(YgIcons.reloj, size: 16, color: YgColors.text2),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nextAlertText(routine),
                        style: YgText.secondary.copyWith(
                          color: const Color(0xFF5B624F),
                        ),
                      ),
                    ),
                    const YgIcon(
                      YgIcons.chevronDerecha,
                      size: 16,
                      color: YgColors.text3,
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

/// Resultado de la hoja de edición.
class RoutineEditResult {
  const RoutineEditResult.save(this.routine) : delete = false;
  const RoutineEditResult.delete() : routine = null, delete = true;

  final CommuteRoutine? routine;
  final bool delete;
}

/// Abre la hoja «Editar rutina» (o «Nueva rutina» si [routine] es nulo).
Future<RoutineEditResult?> showRoutineEditor(
  BuildContext context, {
  CommuteRoutine? routine,
}) {
  return showYgModalSheet<RoutineEditResult>(
    context,
    builder: (_) => _RoutineEditor(routine: routine),
  );
}

class _RoutineEditor extends StatefulWidget {
  const _RoutineEditor({this.routine});

  final CommuteRoutine? routine;

  @override
  State<_RoutineEditor> createState() => _RoutineEditorState();
}

class _RoutineEditorState extends State<_RoutineEditor> {
  late final TextEditingController _label = TextEditingController(
    text: widget.routine?.label,
  );
  late final TextEditingController _origin = TextEditingController(
    text: widget.routine?.origin,
  );
  late final TextEditingController _destination = TextEditingController(
    text: widget.routine?.destination,
  );
  late Set<int> _days = {...(widget.routine?.days ?? const [1, 2, 3, 4, 5])};
  late int _minutes = widget.routine == null
      ? DateTime.now().hour * 60 + DateTime.now().minute
      : widget.routine!.hour * 60 + widget.routine!.minute;

  bool get _isNew => widget.routine == null;

  @override
  void dispose() {
    _label.dispose();
    _origin.dispose();
    _destination.dispose();
    super.dispose();
  }

  void _step(int delta) =>
      setState(() => _minutes = (_minutes + delta + 1440) % 1440);

  void _toggleDay(int day) => setState(() {
    _days = {..._days};
    if (!_days.add(day)) _days.remove(day);
  });

  void _save() {
    final now = DateTime.now();
    final base = widget.routine;
    final name = _label.text.trim();
    if (_isNew && name.isEmpty) return;
    final days = (_days.toList()..sort());
    Navigator.of(context).pop(
      RoutineEditResult.save(
        CommuteRoutine(
          id: base?.id ?? 'local-${now.microsecondsSinceEpoch}',
          label: base?.label ?? name,
          origin: base?.origin ??
              (_origin.text.trim().isEmpty ? 'Origen manual' : _origin.text.trim()),
          destination: base?.destination ??
              (_destination.text.trim().isEmpty
                  ? 'Destino manual'
                  : _destination.text.trim()),
          hour: _minutes ~/ 60,
          minute: _minutes % 60,
          days: days.isEmpty ? const [1, 2, 3, 4, 5] : days,
          status: base?.status ?? CommuteStatus.active,
          timeZoneName: base?.timeZoneName ?? now.timeZoneName,
          timeZoneOffsetMinutes:
              base?.timeZoneOffsetMinutes ?? now.timeZoneOffset.inMinutes,
          // Coordenadas solo si se escribieron como «lat, lon»: nunca se inventan.
          originPoint:
              base?.originPoint ?? CommuteRoutine.parsePoint(_origin.text),
          destinationPoint:
              base?.destinationPoint ??
              CommuteRoutine.parsePoint(_destination.text),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routine = widget.routine;
    return YgSheetBody(
      title: routine?.label ?? 'Nueva rutina',
      leftLabel: 'Cancelar',
      onLeft: () => Navigator.of(context).pop(),
      rightLabel: 'Guardar',
      onRight: _save,
      children: [
        if (_isNew) ...[
          YgTextInput(controller: _label, label: 'Nombre', autofocus: true),
          const SizedBox(height: 8),
          YgTextInput(controller: _origin, label: 'Desde'),
          const SizedBox(height: 8),
          YgTextInput(controller: _destination, label: 'Hasta'),
        ] else
          _OriginDestination(from: routine!.origin, to: routine.destination),
        const _Label('Días'),
        RoutineDays(days: _days.toList(), big: true, onToggle: _toggleDay),
        const _Label('Hora del aviso'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              YgIconButton(
                icon: YgIcons.menos,
                style: YgIconButtonStyle.secondary,
                semanticLabel: '5 minutos antes',
                onPressed: () => _step(-5),
              ),
              Text(
                formatHm(_minutes ~/ 60, _minutes % 60),
                style: YgText.display.copyWith(fontSize: 36, letterSpacing: -1.4),
              ),
              YgIconButton(
                icon: YgIcons.mas,
                style: YgIconButtonStyle.secondary,
                semanticLabel: '5 minutos después',
                onPressed: () => _step(5),
              ),
            ],
          ),
        ),
        if (!_isNew) ...[
          const SizedBox(height: 24),
          YgButton(
            label: 'Eliminar rutina',
            expand: true,
            variant: YgButtonVariant.danger,
            onPressed: () => Navigator.of(
              context,
            ).pop(const RoutineEditResult.delete()),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
    child: YgOverline(text),
  );
}

class _OriginDestination extends StatelessWidget {
  const _OriginDestination({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget dot, String small, String value) => Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          dot,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  small,
                  style: YgText.overline.copyWith(
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
                Text(value, style: YgText.sub),
              ],
            ),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: YgColors.border),
      ),
      child: Column(
        children: [
          row(
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: YgColors.cypress,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: YgColors.cypress.withValues(alpha: .18),
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
            'Desde',
            from,
          ),
          const YgRowDivider(indent: 38),
          row(
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: YgColors.moss,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            'Hasta',
            to,
          ),
        ],
      ),
    );
  }
}
