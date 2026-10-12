import 'package:flutter/material.dart';

class AppRouteDefinition {
  const AppRouteDefinition({
    required this.name,
    required this.title,
    required this.icon,
  });

  final String name;
  final String title;
  final IconData icon;
}

abstract final class AppRoutes {
  static const root = '/';
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const permissions = '/permissions';
  static const home = '/home';
  static const search = '/search';
  static const nearby = '/nearby';
  static const planner = '/planner';
  static const loading = '/loading';
  static const alternatives = '/alternatives';
  static const departure = '/departure';
  static const stepByStep = '/step-by-step';
  static const activeJourney = '/active-journey';
  static const getOffAlert = '/get-off-alert';
  static const saved = '/saved';
  static const commutes = '/commutes';
  static const notifications = '/notifications';
  static const settings = '/settings';

  static const baseline = <AppRouteDefinition>[
    AppRouteDefinition(
      name: splash,
      title: 'Splash',
      icon: Icons.hourglass_empty,
    ),
    AppRouteDefinition(
      name: onboarding,
      title: 'Onboarding',
      icon: Icons.swipe,
    ),
    AppRouteDefinition(
      name: permissions,
      title: 'Permisos',
      icon: Icons.location_on,
    ),
    AppRouteDefinition(name: home, title: 'Inicio', icon: Icons.home_outlined),
    AppRouteDefinition(name: search, title: 'Buscar', icon: Icons.search),
    AppRouteDefinition(name: nearby, title: 'Cercano', icon: Icons.near_me),
    AppRouteDefinition(name: planner, title: 'Planificador', icon: Icons.route),
    AppRouteDefinition(
      name: loading,
      title: 'Cargando',
      icon: Icons.hourglass_empty,
    ),
    AppRouteDefinition(
      name: alternatives,
      title: 'Alternativas',
      icon: Icons.alt_route,
    ),
    AppRouteDefinition(
      name: departure,
      title: 'Hora de salida',
      icon: Icons.schedule,
    ),
    AppRouteDefinition(
      name: stepByStep,
      title: 'Paso a paso',
      icon: Icons.format_list_numbered,
    ),
    AppRouteDefinition(
      name: activeJourney,
      title: 'Viaje activo',
      icon: Icons.navigation,
    ),
    AppRouteDefinition(
      name: getOffAlert,
      title: 'Alerta de bajada',
      icon: Icons.notifications_none,
    ),
    AppRouteDefinition(
      name: saved,
      title: 'Guardados',
      icon: Icons.bookmark_border,
    ),
    AppRouteDefinition(name: commutes, title: 'Rutinas', icon: Icons.repeat),
    AppRouteDefinition(
      name: notifications,
      title: 'Avisos',
      icon: Icons.notifications_none,
    ),
    AppRouteDefinition(
      name: settings,
      title: 'Ajustes',
      icon: Icons.settings_outlined,
    ),
  ];

  static List<String> get baselineNames =>
      List<String>.unmodifiable(baseline.map((definition) => definition.name));

  static AppRouteDefinition definitionFor(String name) => baseline.firstWhere(
    (definition) => definition.name == name,
    orElse: () => const AppRouteDefinition(
      name: root,
      title: 'yeGamo',
      icon: Icons.map_outlined,
    ),
  );
}
