import '../../../shared/models/api_error.dart';
import '../../../shared/models/data_state.dart';

class HomeSnapshot {
  const HomeSnapshot({
    required this.state,
    this.error,
    this.hasNearbyData = false,
    this.hasSavedData = false,
    this.hasNotifications = false,
  });

  final UxState state;
  final ApiError? error;
  final bool hasNearbyData;
  final bool hasSavedData;
  final bool hasNotifications;
}
