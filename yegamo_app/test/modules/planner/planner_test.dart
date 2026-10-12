import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/planner/models/planner_models.dart';
import 'package:yegamo_app/modules/planner/providers/planner_view_model.dart';
import 'package:yegamo_app/modules/planner/services/journey_repository.dart';
import 'package:yegamo_app/shared/models/data_state.dart';

import '../test_support.dart';

void main() {
  test('sends canonical planning input and parses quality state', () async {
    final transportClient = testClient((request) async {
      expect(request.uri.path, '/v1/journeys/plan');
      expect(request.body, isA<Map<String, Object?>>());
      final body = request.body! as Map<String, Object?>;
      expect(body['timeMode'], 'LEAVE_NOW');
      expect(body['preference'], 'BALANCED');
      return jsonResponse(validPlanBody());
    });
    final vm = PlannerViewModel(
      repository: JourneyRepository(apiClient: transportClient),
    );
    vm.setPoints(
      origin: const JourneyPoint(latitude: -2.1, longitude: -79.9),
      destination: const JourneyPoint(latitude: -2.2, longitude: -79.8),
    );

    await vm.calculate();

    expect(vm.state.phase, PlannerPhase.ready);
    expect(
      vm.state.plan?.options.single.dataQuality.dataState,
      DataState.degraded,
    );
    expect(vm.state.plan?.options.single.dataQuality.sourceAuthorized, isFalse);
  });

  test('cancel prevents a late response from becoming a partial ETA', () async {
    var release = false;
    final vm = PlannerViewModel(
      repository: JourneyRepository(
        apiClient: testClient((_) async {
          while (!release) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
          return jsonResponse(validPlanBody());
        }),
      ),
    );
    vm.setPoints(
      origin: const JourneyPoint(latitude: -2.1, longitude: -79.9),
      destination: const JourneyPoint(latitude: -2.2, longitude: -79.8),
    );
    final future = vm.calculate();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    vm.cancel();
    release = true;
    await future;

    expect(vm.state.phase, PlannerPhase.cancelled);
    expect(vm.state.plan, isNull);
  });
}
