import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/onboarding/providers/onboarding_view_model.dart';
import 'package:yegamo_app/modules/onboarding/services/onboarding_repository.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

void main() {
  test('persists completion for first-start bootstrap', () async {
    final storage = InMemoryLocalStorage();
    final repository = OnboardingRepository(storage: storage);
    final vm = OnboardingViewModel(repository: repository);

    expect(await repository.isCompleted(), isFalse);
    await vm.complete();
    expect(await repository.isCompleted(), isTrue);
    expect(vm.saving, isFalse);
  });
}
