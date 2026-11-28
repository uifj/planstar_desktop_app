import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:core/network.dart';
import 'package:core/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/features/auth/network/planstar_network_interceptor.dart';
import 'package:planstar_desktop_app/features/auth/network/planstar_request_context.dart';
import 'package:planstar_desktop_app/features/project_idea/data/planstar_project_idea_api.dart';
import 'package:planstar_desktop_app/features/project_idea/domain/project_idea.dart';

final class _Reply {
  const _Reply(this.data, {this.status = 200});

  final Object? data;
  final int status;
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.replies);

  final List<_Reply> replies;
  final List<RequestOptions> requests = <RequestOptions>[];
  final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      if (bytes.isNotEmpty) {
        bodies.add(
          (jsonDecode(utf8.decode(bytes)) as Map).map(
            (Object? key, Object? value) =>
                MapEntry<String, Object?>('$key', value),
          ),
        );
      }
    }
    if (replies.isEmpty) {
      throw StateError('missing response for ${options.path}');
    }
    final reply = replies.removeAt(0);
    return ResponseBody.fromString(
      reply.data is String ? reply.data as String : jsonEncode(reply.data),
      reply.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final class _Fixture {
  _Fixture(List<_Reply> replies, {PlanstarRequestContext? context}) {
    adapter = _Adapter(replies);
    dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test/'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      PlanstarNetworkInterceptor(
        context: context ?? PlanstarRequestContext(),
        userAgent: 'PlanstarTest/1',
      ),
    );
    api = PlanstarProjectIdeaApi(client: ApiClient(dio));
  }

  late final _Adapter adapter;
  late final Dio dio;
  late final PlanstarProjectIdeaApi api;
}

void main() {
  test(
    'feed uses cursor pagination and parses tolerant bare or wrapped data',
    () async {
      final fixture = _Fixture(<_Reply>[
        _Reply(<String, Object?>{
          'data': <String, Object?>{
            'items': <Object?>[
              <String, Object?>{
                'ideaId': '42',
                'title': '桌面企划',
                'summary': 'summary',
                'creatorName': 'Ada',
                'supportCount': '8',
                'createdAt': 1700000000000,
              },
              <String, Object?>{'ideaId': 0, 'title': 'invalid'},
            ],
            'nextCursor': 'cursor-2',
            'hasMore': true,
          },
        }),
        _Reply(<String, Object?>{
          'list': <Object?>[
            <String, Object?>{'ideaId': 43, 'title': 'second'},
          ],
          'cursor': 'cursor-3',
        }),
      ]);

      final first = await fixture.api.feed(cursor: 'cursor-1', size: 10);
      expect(first.isSuccess, isTrue);
      final page = first.requireData;
      expect(page.items.single.ideaId, 42);
      expect(page.items.single.supportCount, 8);
      expect(page.items.single.creatorName, 'Ada');
      expect(page.nextCursor, 'cursor-2');
      expect(page.hasMore, isTrue);
      expect(
        fixture.adapter.requests.first.path,
        PlanstarProjectIdeaApi.feedPath,
      );
      expect(fixture.adapter.requests.first.queryParameters, <String, Object?>{
        'size': 10,
        'cursor': 'cursor-1',
      });

      final second = await fixture.api.feed(cursor: page.nextCursor);
      expect(second.requireData.items.single.ideaId, 43);
      expect(second.requireData.nextCursor, 'cursor-3');
      expect(second.requireData.hasMore, isTrue);
    },
  );

  test(
    'detail parses my vote, tier distribution and reason aggregates',
    () async {
      final fixture = _Fixture(<_Reply>[
        _Reply(<String, Object?>{
          'ideaId': 42,
          'title': '详情',
          'description': 'full description',
          'gallery': <Object?>['https://example.test/a.png', null, ''],
          'supportRate': '0.75',
          'myVote': <String, Object?>{'voteType': 1, 'coinTier': 10},
          'tierDistribution': <String, Object?>{'5': 2, '10': 3, '20': 1},
          'reasonCounts': <Object?>[
            <String, Object?>{'reasonCode': 'not_interested', 'count': '4'},
            <String, Object?>{'reasonCode': 'ignored', 'count': 0},
          ],
        }),
      ]);

      final result = await fixture.api.detail(42);
      expect(result.isSuccess, isTrue);
      final detail = result.requireData;
      expect(fixture.adapter.requests.single.path, 'v1/projectIdeas/42');
      expect(detail.myVote?.voteType, IdeaVote.support);
      expect(detail.myVote?.coinTier, 10);
      expect(detail.tierDistribution.total, 6);
      expect(detail.reasonCounts, <String, int>{'not_interested': 4});
      expect(detail.gallery, <String>['https://example.test/a.png']);
      expect(detail.supportRate, 0.75);
    },
  );

  test(
    'support and opposition vote bodies match the backend contract',
    () async {
      final context = PlanstarRequestContext(
        dvid: 'device-1',
        psSession: 'session',
      );
      final fixture = _Fixture(<_Reply>[
        _Reply(<String, Object?>{
          'supportCount': 9,
          'opposeCount': 2,
          'alreadyVoted': false,
          'myVote': <String, Object?>{'voteType': 1, 'coinTier': 10},
          'tierDistribution': <String, Object?>{'5': 1, '10': 4, '20': 2},
          'supportRate': 0.82,
          'reasonCounts': <String, Object?>{'not_interested': 2},
        }),
        _Reply(<String, Object?>{
          'supportCount': 9,
          'opposeCount': 3,
          'alreadyVoted': true,
          'myVote': <String, Object?>{
            'voteType': 2,
            'reasonCode': 'other',
            'reasonText': '需要更多信息',
          },
        }),
      ], context: context);

      final support = await fixture.api.vote(
        42,
        voteType: IdeaVote.support,
        coinTier: 10,
        reasonText: '愿意参与',
      );
      expect(support.requireData.supportCount, 9);
      expect(support.requireData.myVote?.coinTier, 10);
      expect(support.requireData.tierDistribution?.ten, 4);
      expect(support.requireData.supportRate, 0.82);
      expect(support.requireData.reasonCounts, <String, int>{
        'not_interested': 2,
      });
      expect(fixture.adapter.requests[0].method, 'POST');
      expect(fixture.adapter.requests[0].path, 'v1/projectIdeas/42/vote');
      expect(fixture.adapter.bodies.single, <String, Object?>{
        'voteType': 1,
        'coinTier': 10,
        'reasonText': '愿意参与',
      });
      expect(fixture.adapter.requests[0].headers['dvid'], 'device-1');
      expect(
        fixture.adapter.requests[0].headers['Cookie'],
        contains('psSession=session'),
      );

      final oppose = await fixture.api.vote(
        42,
        voteType: IdeaVote.oppose,
        reasonCode: 'other',
        reasonText: '需要更多信息',
      );
      expect(oppose.requireData.alreadyVoted, isTrue);
      expect(oppose.requireData.myVote?.reasonCode, 'other');
      expect(fixture.adapter.bodies.last, <String, Object?>{
        'voteType': 2,
        'reasonCode': 'other',
        'reasonText': '需要更多信息',
      });
    },
  );

  test(
    'HTTP and parser failures stay in Result and 401 invokes logout',
    () async {
      var unauthorizedCalls = 0;
      final context = PlanstarRequestContext(psSession: 'expired')
        ..onUnauthorized = () => unauthorizedCalls++;
      final fixture = _Fixture(<_Reply>[
        _Reply(<String, Object?>{'message': 'expired'}, status: 401),
        _Reply('{broken'),
      ], context: context);

      final unauthorized = await fixture.api.detail(42);
      expect(unauthorized.isFailure, isTrue);
      expect(unauthorized.failure?.statusCode, 401);
      expect(unauthorizedCalls, 1);

      final malformed = await fixture.api.detail(42);
      expect(malformed.isFailure, isTrue);
      expect(malformed.failure?.type, FailureType.server);
    },
  );
}
