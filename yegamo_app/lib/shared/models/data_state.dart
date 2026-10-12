enum DataState { current, stale, degraded, offlineCache, unavailable }

enum UxState {
  ok,
  loading,
  empty,
  error,
  offline,
  stale,
  degraded,
  permission,
  noCoverage,
}

extension DataStateParsing on DataState {
  String get apiValue => switch (this) {
    DataState.current => 'CURRENT',
    DataState.stale => 'STALE',
    DataState.degraded => 'DEGRADED',
    DataState.offlineCache => 'OFFLINE_CACHE',
    DataState.unavailable => 'UNAVAILABLE',
  };

  static DataState? fromApiValue(Object? raw) {
    if (raw is! String) return null;
    return switch (raw.toUpperCase()) {
      'CURRENT' => DataState.current,
      'STALE' => DataState.stale,
      'DEGRADED' => DataState.degraded,
      'OFFLINE_CACHE' => DataState.offlineCache,
      'UNAVAILABLE' => DataState.unavailable,
      _ => null,
    };
  }
}

extension UxStateMapping on UxState {
  static UxState fromError({String? code, DataState? dataState}) {
    if (code == 'LOCATION_PERMISSION_REQUIRED') return UxState.permission;
    if (code == 'LOCATION_OUT_OF_COVERAGE') return UxState.noCoverage;
    if (dataState == DataState.offlineCache) return UxState.offline;
    if (dataState == DataState.stale) return UxState.stale;
    if (dataState == DataState.degraded || dataState == DataState.unavailable) {
      return UxState.degraded;
    }
    return UxState.error;
  }

  static UxState fromDataState(DataState state) => switch (state) {
    DataState.current => UxState.ok,
    DataState.stale => UxState.stale,
    DataState.degraded => UxState.degraded,
    DataState.offlineCache => UxState.offline,
    DataState.unavailable => UxState.degraded,
  };
}
