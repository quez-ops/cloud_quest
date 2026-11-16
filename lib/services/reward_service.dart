import 'package:cloud_functions/cloud_functions.dart';

class RewardService {
  final HttpsCallable _completeToday =
      FirebaseFunctions.instance.httpsCallable('completeToday');

  Future<Map<String, dynamic>> completeChallenge() async {
    final result = await _completeToday.call({'challengeId': 'today'});
    return Map<String, dynamic>.from(result.data as Map);
  }
}
