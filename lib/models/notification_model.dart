enum CampusNotificationType { info, inProgress, resolved }

class CampusNotification {
  const CampusNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.type = CampusNotificationType.info,
  });

  final String id;
  final String title;
  final String message;
  final String category;
  final DateTime createdAt;
  final bool isRead;
  final CampusNotificationType type;

  CampusNotification copyWith({
    String? id,
    String? title,
    String? message,
    String? category,
    DateTime? createdAt,
    bool? isRead,
    CampusNotificationType? type,
  }) {
    return CampusNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}
