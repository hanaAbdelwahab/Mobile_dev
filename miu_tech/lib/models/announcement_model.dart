class AnnouncementModel {
  final int annId;
  final String title;
  final String description;
  final DateTime eventDateTime; // date + time
  final DateTime createdAt;
  final int categoryId;

  AnnouncementModel({
    required this.annId,
    required this.title,
    required this.description,
    required this.eventDateTime,
    required this.createdAt,
    required this.categoryId,
  });

  factory AnnouncementModel.fromMap(Map<String, dynamic> map) {
    final date = DateTime.parse(map['date']);
    final timeParts = map['time'].toString().split(':');

    final eventDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    return AnnouncementModel(
      annId: map['ann_id'],
      title: map['title'],
      description: map['description'],
      eventDateTime: eventDateTime,
      createdAt: DateTime.parse(map['created_at']),
      categoryId: map['category_id'],
    );
  }
}
