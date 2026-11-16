import 'package:cloud_functions/cloud_functions.dart';

class CoachService {
  final HttpsCallable _askQuestCoach =
      FirebaseFunctions.instance.httpsCallable('askQuestCoach');

  Future<String> getQuestHint(String question) async {
    final trimmed = question.trim();
    final safeQuestion =
        trimmed.length > 300 ? trimmed.substring(0, 300) : trimmed;

    final result = await _askQuestCoach.call({'question': safeQuestion});
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['reply'] as String;
  }
}
