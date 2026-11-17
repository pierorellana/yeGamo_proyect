import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yegamo_app/modules/search/providers/search_view_model.dart';
import 'package:yegamo_app/modules/search/services/search_repository.dart';
import 'package:yegamo_app/shared/services/api_client.dart';
import 'package:yegamo_app/shared/storage/local_storage.dart';

import '../test_support.dart';
import '../../support/fakes.dart';

void main() {
  test('ignores a result from an older search request', () async {
    final pending = <String, Completer<TransportResponse>>{};
    final repository = SearchRepository(
      apiClient: testClient((request) {
        final query = request.uri.queryParameters['q']!;
        final completer = Completer<TransportResponse>();
        pending[query] = completer;
        return completer.future;
      }),
      connectivity: FakeConnectivityService(),
      storage: InMemoryLocalStorage(),
    );
    final viewModel = SearchViewModel(repository: repository);

    final oldRequest = viewModel.search('terminal');
    await Future<void>.delayed(Duration.zero);
    final currentRequest = viewModel.search('malecón');
    await Future<void>.delayed(Duration.zero);

    pending['terminal']!.complete(
      jsonResponse(<Object?>[
        <String, Object?>{
          'id': 'terminal',
          'label': 'Terminal antigua',
          'location': <String, Object?>{'lat': -2.2, 'lon': -79.9},
        },
      ]),
    );
    await oldRequest;

    expect(viewModel.snapshot.results, isEmpty);
    expect(viewModel.loading, isTrue);

    pending['malecón']!.complete(
      jsonResponse(<Object?>[
        <String, Object?>{
          'id': 'malecon',
          'label': 'Malecón vigente',
          'location': <String, Object?>{'lat': -2.19, 'lon': -79.88},
        },
      ]),
    );
    await currentRequest;

    expect(viewModel.snapshot.results.single.name, 'Malecón vigente');
    expect(viewModel.loading, isFalse);
  });
}
