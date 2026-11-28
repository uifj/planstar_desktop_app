import 'dart:convert';
import 'dart:typed_data';

import 'package:core/network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar_desktop_app/features/auth/network/planstar_network_interceptor.dart';
import 'package:planstar_desktop_app/features/auth/network/planstar_request_context.dart';
import 'package:planstar_desktop_app/features/catalog/data/planstar_catalog_api.dart';
import 'package:planstar_desktop_app/features/catalog/domain/show_summary.dart';

final class _Reply {
  const _Reply(this.data, {this.status = 200});

  final Object? data;
  final int status;
}

final class _Adapter implements HttpClientAdapter {
  _Adapter(this.replies);

  final List<_Reply> replies;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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
  _Fixture(List<_Reply> replies) {
    adapter = _Adapter(replies);
    final dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test/'));
    dio.httpClientAdapter = adapter;
    dio.interceptors.add(
      PlanstarNetworkInterceptor(
        context: PlanstarRequestContext(),
        userAgent: 'PlanstarTest/1',
      ),
    );
    api = PlanstarCatalogApi(client: ApiClient(dio));
  }

  late final _Adapter adapter;
  late final PlanstarCatalogApi api;
}

void main() {
  test(
    'categories accept bare and wrapped lists and keep active categories',
    () async {
      final fixture = _Fixture(<_Reply>[
        _Reply(<Object?>[
          <String, Object?>{
            'id': '1',
            'name': '剧场',
            'enName': 'Theatre',
            'pinyin': 'juchang',
            'status': 1,
            'subCategoryTags': <Object?>[
              <String, Object?>{
                'subCategoryId': 9,
                'categoryId': 1,
                'name': '音乐剧',
              },
            ],
          },
          <String, Object?>{'id': 2, 'name': '停用分类', 'status': 0},
        ]),
        _Reply(<String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 3,
              'name': '线上企划',
              'enName': 'Online',
              'status': '1',
            },
          ],
        }),
      ]);

      final bare = await fixture.api.categories();
      expect(bare.requireData.single.id, 1);
      expect(bare.requireData.single.subTags.single.id, 9);
      expect(bare.requireData.single.subTags.single.categoryId, 1);
      expect(fixture.adapter.requests.single.path, 'v1/categories');

      final wrapped = await fixture.api.categories();
      expect(wrapped.requireData.single.id, 3);
    },
  );

  test(
    'projects send server filters and parse exact cents and detail sections',
    () async {
      final fixture = _Fixture(<_Reply>[
        _Reply(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'projectId': 'show-7',
              'name': '星海音乐会',
              'creator': <String, Object?>{'displayName': 'Ada'},
              'categoryId': '2',
              'categoryName': '音乐',
              'city': '上海',
              'venueName': '星海剧场',
              'showTime': '2026-12-01T12:00:00',
              'minSupportAmount': '68000',
              'goalAmount': 100000,
              'raisedAmount': 128000,
              'supporterCount': '24',
              'deadline': 1795000000000,
              'fundingStatus': 'ongoing',
              'cover': 'https://example.test/cover.png',
              'rewardTiers': <Object?>[
                <String, Object?>{
                  'tierName': '早鸟票',
                  'supportAmount': 68000,
                  'remainingNum': 3,
                  'deliveryTime': '演出前邮寄',
                },
              ],
            },
            <String, Object?>{'id': '', 'name': 'invalid'},
          ],
        }),
      ]);

      final result = await fixture.api.projects(
        categoryId: 2,
        sort: ProjectSort.achievement,
        page: 3,
        pageSize: 20,
      );
      final show = result.requireData.single;
      final request = fixture.adapter.requests.single;
      expect(request.path, 'v1/projects');
      expect(request.queryParameters, <String, Object?>{
        'page': 3,
        'pageSize': 20,
        'categoryId': 2,
        'sort': 'achievement',
      });
      expect(show.id, 'show-7');
      expect(show.artist, 'Ada');
      expect(show.priceFrom.minorUnits, 68000);
      expect(show.goalAmount?.minorUnits, 100000);
      expect(show.raisedAmount?.minorUnits, 128000);
      expect(show.achievementPermille, 1280);
      expect(show.tiers.single.price.minorUnits, 68000);
      expect(show.tiers.single.remaining, 3);
      expect(show.tiers.single.estimatedDeliveryTime, '演出前邮寄');
    },
  );

  test(
    'detail accepts nested payload and rejects missing ids as a failure',
    () async {
      final fixture = _Fixture(<_Reply>[
        _Reply(<String, Object?>{
          'data': <String, Object?>{
            'activityId': 88,
            'title': '详情企划',
            'intro': '完整故事',
            'faq': <Object?>[
              <String, Object?>{'question': '如何支持？', 'answer': '查看档位'},
            ],
          },
        }),
        _Reply(<String, Object?>{'title': '缺少 ID'}),
      ]);

      final detail = await fixture.api.projectDetail('88');
      expect(detail.requireData.id, '88');
      expect(detail.requireData.faqs.single.question, '如何支持？');
      expect(fixture.adapter.requests.first.path, 'v1/projects/88');

      final missingId = await fixture.api.projectDetail('missing');
      expect(missingId.isFailure, isTrue);
    },
  );

  test(
    'catalog HTTP failures remain in Result and invoke global logout',
    () async {
      var unauthorizedCalls = 0;
      final adapter = _Adapter(<_Reply>[
        _Reply(<String, Object?>{'message': 'expired'}, status: 401),
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'https://api.planstar.test/'));
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(
        PlanstarNetworkInterceptor(
          context: PlanstarRequestContext(psSession: 'expired')
            ..onUnauthorized = () => unauthorizedCalls++,
          userAgent: 'PlanstarTest/1',
        ),
      );
      final api = PlanstarCatalogApi(client: ApiClient(dio));

      final result = await api.projects();
      expect(result.isFailure, isTrue);
      expect(result.failure?.statusCode, 401);
      expect(unauthorizedCalls, 1);
    },
  );
}
