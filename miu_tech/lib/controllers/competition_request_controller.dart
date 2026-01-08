import 'announcement_controller.dart';
import '../../models/competition_request_model.dart';
class CompetitionRequestController {
  static Future<List<CompetitionRequestModel>> fetchAllRequests() async {
  final data = await supabase
      .from('competition_requests')
      .select()
      .order('created_at', ascending: false);

  return (data as List)
      .map((e) => CompetitionRequestModel.fromMap(e))
      .toList();
}

  static Future<List<CompetitionRequestModel>> fetchRequests(
      int competitionId) async {
    final data = await supabase
        .from('competition_requests')
        .select()
        .eq('competition_id', competitionId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => CompetitionRequestModel.fromMap(e))
        .toList();
  }

  static Future<void> createRequest({
    required int competitionId,
    required int userId,
    required String title,
    required String description,
    required String neededSkills,
    required int teamSize,
  }) async {
    await supabase.from('competition_requests').insert({
      'competition_id': competitionId,
      'user_id': userId,
      'title': title,
      'description': description,
      'needed_skills': neededSkills,
      'team_size': teamSize,
    });
  }
}

