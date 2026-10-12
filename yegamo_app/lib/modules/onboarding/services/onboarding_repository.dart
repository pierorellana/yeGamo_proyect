import '../../../shared/storage/local_storage.dart';

class OnboardingRepository {
  OnboardingRepository({required LocalStorage storage}) : this._(storage);

  OnboardingRepository._(this._storage);

  static const completionKey = 'onboarding_completed';
  final LocalStorage _storage;

  Future<bool> isCompleted() async {
    return (await _storage.read(completionKey)) == 'true';
  }

  Future<void> markCompleted() => _storage.write(completionKey, 'true');
}
