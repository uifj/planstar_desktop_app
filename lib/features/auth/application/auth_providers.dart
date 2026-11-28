library;

import 'package:core/network.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/core_providers.dart';
import '../data/auth_session_store.dart';
import '../data/planstar_account_api.dart';
import '../data/remote_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../network/planstar_request_context.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

final planstarRequestContextProvider = Provider<PlanstarRequestContext>(
  (Ref ref) => PlanstarRequestContext(),
);

final planstarApiClientProvider = Provider<ApiClient>(
  (Ref ref) => throw UnimplementedError('planstarApiClientProvider 未注入'),
);

final authSessionStoreProvider = Provider<AuthSessionStore>(
  (Ref ref) => AuthSessionStore(
    store: ref.watch(appStoreProvider),
    context: ref.watch(planstarRequestContextProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  ),
);

final planstarAccountApiProvider = Provider<PlanstarAccountApi>(
  (Ref ref) => PlanstarAccountApi(
    client: ref.watch(planstarApiClientProvider),
    clientType:
        ref.watch(appConfigProvider).section('planstar').getInt('clientType') ??
        11,
  ),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => RemoteAuthRepository(
    api: ref.watch(planstarAccountApiProvider),
    store: ref.watch(authSessionStoreProvider),
    context: ref.watch(planstarRequestContextProvider),
  ),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
