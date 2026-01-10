class FreelanceProjectModel {
  final String projectId;  // UUID as String
  final String title;
  final String companyName;
  final String? companyLogo;
  final DateTime postedAt;
  final String description;
  final List<String> skillsNeeded;
  final String duration;
  final DateTime deadline;
  final String? budgetRange;
  final String keyResponsibilities;
  final String? createdBy;  // UUID as String
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  FreelanceProjectModel({
    required this.projectId,
    required this.title,
    required this.companyName,
    this.companyLogo,
    required this.postedAt,
    required this.description,
    required this.skillsNeeded,
    required this.duration,
    required this.deadline,
    this.budgetRange,
    required this.keyResponsibilities,
    this.createdBy,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert from Supabase Map to Model
  factory FreelanceProjectModel.fromMap(Map<String, dynamic> map) {
    return FreelanceProjectModel(
      projectId: map['project_id'] as String,
      title: map['title'] as String,
      companyName: map['company_name'] as String,
      companyLogo: map['company_logo'] as String?,
      postedAt: DateTime.parse(map['posted_at'] as String),
      description: map['description'] as String,
      skillsNeeded: (map['skills_needed'] as List<dynamic>)
          .map((skill) => skill.toString())
          .toList(),
      duration: map['duration'] as String,
      deadline: DateTime.parse(map['deadline'] as String),
      budgetRange: map['budget_range'] as String?,
      keyResponsibilities: map['key_responsibilities'] as String,
      createdBy: map['created_by'] as String?,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : null,
    );
  }

  // Convert from Model to Supabase Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'company_name': companyName,
      'company_logo': companyLogo,
      'posted_at': postedAt.toIso8601String(),
      'description': description,
      'skills_needed': skillsNeeded,
      'duration': duration,
      'deadline': deadline.toIso8601String(),
      'budget_range': budgetRange,
      'key_responsibilities': keyResponsibilities,
      'created_by': createdBy,
      'is_active': isActive,
    };
  }

  // Copy with method for updates
  FreelanceProjectModel copyWith({
    String? projectId,
    String? title,
    String? companyName,
    String? companyLogo,
    DateTime? postedAt,
    String? description,
    List<String>? skillsNeeded,
    String? duration,
    DateTime? deadline,
    String? budgetRange,
    String? keyResponsibilities,
    String? createdBy,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FreelanceProjectModel(
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      companyName: companyName ?? this.companyName,
      companyLogo: companyLogo ?? this.companyLogo,
      postedAt: postedAt ?? this.postedAt,
      description: description ?? this.description,
      skillsNeeded: skillsNeeded ?? this.skillsNeeded,
      duration: duration ?? this.duration,
      deadline: deadline ?? this.deadline,
      budgetRange: budgetRange ?? this.budgetRange,
      keyResponsibilities: keyResponsibilities ?? this.keyResponsibilities,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}