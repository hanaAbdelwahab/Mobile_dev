class FreelanceProjectModel {
  final int projectId;
  final String title;
  final String companyName;
  final String companyLogo;
  final DateTime postedAt;
  final String description;
  final List<String> skillsNeeded;
  final String duration;
  final DateTime deadline;
  final String? budgetRange;
  final String keyResponsibilities;

  FreelanceProjectModel({
    required this.projectId,
    required this.title,
    required this.companyName,
    required this.companyLogo,
    required this.postedAt,
    required this.description,
    required this.skillsNeeded,
    required this.duration,
    required this.deadline,
    this.budgetRange,
    required this.keyResponsibilities,
  });
}