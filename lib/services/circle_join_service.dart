import 'package:cloud_functions/cloud_functions.dart';

import '../features/auth/domain/auth_validators.dart';

abstract interface class CircleJoinActions {
  Future<String> joinWithCode(String code);
}

class CircleInviteResult {
  const CircleInviteResult({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}

class CircleJoinService implements CircleJoinActions {
  CircleJoinService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<String> joinWithCode(String code) async {
    final normalized = AuthValidators.normalizeInviteCode(code);
    final result = await _functions.httpsCallable('redeemCircleInvite').call(
      <String, dynamic>{'code': normalized},
    );
    final data = result.data;
    if (data is! Map || data['circleId'] is! String) {
      throw StateError('The invitation response was invalid.');
    }
    return data['circleId'] as String;
  }

  Future<CircleInviteResult> createInvite(
    String circleId, {
    String circleRole = 'adult',
  }) async {
    final result = await _functions.httpsCallable('createCircleInvite').call(
      <String, dynamic>{'circleId': circleId, 'circleRole': circleRole},
    );
    final data = result.data;
    if (data is! Map || data['code'] is! String || data['expiresAt'] is! num) {
      throw StateError('The invitation response was invalid.');
    }
    return CircleInviteResult(
      code: data['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (data['expiresAt'] as num).toInt(),
      ),
    );
  }
}
