class SettingsState {
  const SettingsState({
    required this.locationConsent,
    required this.reduceMotion,
    required this.demoCatalogEnabled,
    this.lastExport,
    this.message,
  });

  final bool locationConsent;
  final bool reduceMotion;
  final bool demoCatalogEnabled;
  final String? lastExport;
  final String? message;
}

class DemoStateEntry {
  const DemoStateEntry({required this.name, required this.description});

  final String name;
  final String description;
}

const demoStateCatalog = <DemoStateEntry>[
  DemoStateEntry(name: 'ok', description: 'Datos actuales con calidad visible.'),
  DemoStateEntry(name: 'offline', description: 'Cache local con frescura explícita.'),
  DemoStateEntry(name: 'stale', description: 'Datos que deben revisarse antes de salir.'),
  DemoStateEntry(name: 'degraded', description: 'Fuente disponible con calidad reducida.'),
  DemoStateEntry(name: 'permission', description: 'Ubicación opcional pendiente de permiso.'),
  DemoStateEntry(name: 'nocoverage', description: 'La fuente no cubre la ubicación consultada.'),
];
