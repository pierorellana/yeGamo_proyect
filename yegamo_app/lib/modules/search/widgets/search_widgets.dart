import 'package:flutter/material.dart';

import '../../../shared/design_system/yg_components.dart';
import '../../../shared/models/data_state.dart';

/// Tarjeta Desde/Hasta (`.od`): origen, separador y campo de destino. El
/// botón circular de la derecha ejecuta la búsqueda.
class SearchOriginDestination extends StatelessWidget {
  const SearchOriginDestination({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.originText,
    required this.onSubmit,
    this.onChanged,
    this.loading = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String originText;
  final VoidCallback onSubmit;
  final ValueChanged<String>? onChanged;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(YgRadius.card),
        border: Border.all(color: YgColors.border),
        boxShadow: YgShadows.card,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 52),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
                    child: Row(
                      children: [
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Desde',
                                style: YgText.meta.copyWith(
                                  fontSize: 11,
                                  height: 1.2,
                                  color: YgColors.text3,
                                ),
                              ),
                              Text(
                                originText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: YgText.sub.copyWith(height: 1.3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 42),
                  color: YgColors.fill,
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: YgColors.moss,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hasta',
                                style: YgText.meta.copyWith(
                                  fontSize: 11,
                                  height: 1.2,
                                  color: YgColors.text3,
                                ),
                              ),
                              TextField(
                                key: const ValueKey('search_query'),
                                controller: controller,
                                focusNode: focusNode,
                                textInputAction: TextInputAction.search,
                                onChanged: onChanged,
                                onSubmitted: (_) => onSubmit(),
                                cursorColor: YgColors.cypress,
                                style: YgText.sub.copyWith(
                                  height: 1.3,
                                  color: const Color(0xFF1E2419),
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  isCollapsed: true,
                                  filled: false,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Busca un lugar o dirección',
                                  hintStyle: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF959581),
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: Tooltip(
                message: 'Buscar',
                child: YgIconButton(
                  key: const ValueKey('search_submit'),
                  icon: YgIcons.buscar,
                  style: YgIconButtonStyle.secondary,
                  size: 36,
                  semanticLabel: 'Buscar',
                  onPressed: loading ? null : onSubmit,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de lugares rápidos (`.chips`) con desplazamiento horizontal a sangre.
class SearchQuickChips extends StatelessWidget {
  const SearchQuickChips({
    super.key,
    required this.labels,
    required this.onPick,
    this.keyPrefix = 'quick_',
  });

  final List<String> labels;
  final ValueChanged<String> onPick;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => YgChip(
          key: ValueKey('$keyPrefix${labels[i]}'),
          label: labels[i],
          onTap: () => onPick(labels[i]),
        ),
      ),
    );
  }
}

/// Estado sin resultados (E7): ilustración, título, ayuda y «Borrar búsqueda».
class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({
    super.key,
    required this.query,
    required this.onClear,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return YgEnter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 32, 8, 8),
        child: Column(
          children: [
            YgLoop(
              duration: const Duration(milliseconds: 2500),
              reverse: true,
              builder: (context, t, child) {
                final e = Curves.easeInOut.transform(t);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, -1 / 400)
                    ..translateByDouble(0, -4 * e, 0, 1)
                    ..rotateX(8 * e * 3.14159265 / 180)
                    ..rotateY(-8 * e * 3.14159265 / 180),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/ilustraciones/png/vacio-busqueda@3x.png',
                width: 200,
                height: 112,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                'No encontramos “$query”',
                textAlign: TextAlign.center,
                style: YgText.title,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                'Prueba con una calle, un barrio o un lugar conocido de '
                'Guayaquil.',
                textAlign: TextAlign.center,
                style: YgText.secondary.copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
            YgButton(
              key: const ValueKey('search_clear'),
              label: 'Borrar búsqueda',
              size: YgButtonSize.sm,
              variant: YgButtonVariant.secondary,
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }
}

class SearchProblem {
  const SearchProblem(
    this.title,
    this.message,
    this.icon,
    this.tone,
    this.retry,
  );

  final String title;
  final String message;
  final String icon;
  final YgBannerTone tone;
  final bool retry;
}

/// Copy de los estados de error de la búsqueda (sin resultados inventados).
SearchProblem? searchProblemFor(UxState state) => switch (state) {
  UxState.offline => const SearchProblem(
    'Sin conexión',
    'No pudimos buscar lugares sin red.',
    YgIcons.sinConexion,
    YgBannerTone.off,
    true,
  ),
  UxState.degraded => const SearchProblem(
    'Búsqueda no disponible',
    'No hay una fuente autorizada para buscar lugares ahora.',
    YgIcons.alerta,
    YgBannerTone.warn,
    true,
  ),
  UxState.stale => const SearchProblem(
    'Datos desactualizados',
    'Los resultados pueden haber cambiado.',
    YgIcons.reloj,
    YgBannerTone.warn,
    true,
  ),
  UxState.permission => const SearchProblem(
    'Ubicación necesaria',
    'Puedes buscar por nombre o usar un origen manual.',
    YgIcons.ubicacionDesactivada,
    YgBannerTone.warn,
    false,
  ),
  UxState.error => const SearchProblem(
    'No pudimos buscar',
    'Inténtalo de nuevo en unos segundos.',
    YgIcons.alerta,
    YgBannerTone.warn,
    true,
  ),
  _ => null,
};
