class UserModel {
  final int userId;
  final String name;
  final String email;
  final String role;
  final String? profileImage;
  final String? department;
  final String? bio;
  final DateTime createdAt;
  final String? location;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.profileImage,
    this.department,
    this.bio,
    required this.createdAt,
    this.location,
  });

  // Convert Supabase map (from query) to UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['user_id'] as int,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'Student',
      profileImage: map['profile_image'],
      department: map['department'],
      bio: map['bio'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      location: map['location'],
    );
  }

  // Convert UserModel to Map (for inserting/updating in Supabase)
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'role': role,
      'profile_image': profileImage,
      'department': department,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
      'location': location,
    };
  }

  // Optional: copyWith for updating fields immutably
  UserModel copyWith({
    int? userId,
    String? name,
    String? email,
    String? role,
    String? profileImage,
    String? department,
    String? bio,
    DateTime? createdAt,
    String? location,
  }) {
    return UserModel(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImage: profileImage ?? this.profileImage,
      department: department ?? this.department,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
    );
  }
}