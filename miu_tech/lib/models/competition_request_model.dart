class CompetitionRequestModel {
  final int requestId;
  final int competitionId;
  final int userId;
  final String title;
  final String description;
  final String neededSkills;
  final int teamSize;
  final DateTime createdAt;

  CompetitionRequestModel({
    required this.requestId,
    required this.competitionId,
    required this.userId,
    required this.title,
    required this.description,
    required this.neededSkills,
    required this.teamSize,
    required this.createdAt,
  });

  factory CompetitionRequestModel.fromMap(Map<String, dynamic> map) {
    return CompetitionRequestModel(
      requestId: map['request_id'],
      competitionId: map['competition_id'],
      userId: map['user_id'],
      title: map['title'],
      description: map['description'] ?? '',
      neededSkills: map['needed_skills'] ?? '',
      teamSize: map['team_size'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}
