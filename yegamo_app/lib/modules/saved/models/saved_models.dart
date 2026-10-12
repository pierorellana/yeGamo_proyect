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
