class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.label,
    this.subtitle,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String label;
  final String? subtitle;
  final double? latitude;
  final double? longitude;

  factory SavedPlace.fromJson(Map<String, Object?> json) {
    final location = json['location'] is Map
        ? Map<String, Object?>.from(json['location'] as Map)
        : const <String, Object?>{};
    return SavedPlace(
      id: json['id'] as String? ?? 'saved-${json['label'] ?? 'place'}',
      label: json['label'] as String? ?? json['name'] as String? ?? 'Lugar',
      subtitle: json['subtitle'] as String? ?? json['address'] as String?,
      latitude: ((location['lat'] ?? json['lat']) as num?)?.toDouble(),
      longitude: ((location['lon'] ?? json['lon']) as num?)?.toDouble(),
    );
  }

  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  /// Coordenadas válidas: requisito para sincronizar con la cuenta.
  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  /// El id lo asignó el API (UUID); los ids locales nunca se envían al servidor.
  bool get isRemote => _uuid.hasMatch(id);

  /// Cuerpo de `POST/PATCH /v1/favorites/places`: solo `label` y `location`
  /// (el API rechaza campos desconocidos). Requiere [hasLocation].
  Map<String, Object?> toApiJson() {
    assert(hasLocation, 'Un lugar sin coordenadas no puede sincronizarse.');
    return {
      'label': label,
      'location': {'lat': latitude, 'lon': longitude},
    };
  }

  /// Serialización de almacenamiento local.
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    if (subtitle != null) 'subtitle': subtitle,
    if (latitude != null && longitude != null)
      'location': {'lat': latitude, 'lon': longitude},
  };
}

class SavedPlacesState {
  const SavedPlacesState({this.items = const [], this.message});

  final List<SavedPlace> items;
  final String? message;
}
