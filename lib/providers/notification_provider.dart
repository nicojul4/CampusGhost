import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_model.dart';

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<CampusNotification>>(
        NotificationsNotifier.new);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});

class NotificationsNotifier extends Notifier<List<CampusNotification>> {
  @override
  List<CampusNotification> build() => const [];

  void markAllAsRead() {
    state = [
      for (final item in state) item.copyWith(isRead: true),
    ];
  }

  void markAsRead(String id) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
  }

  void clearAll() {
    state = const [];
  }

  void addWelcomeNotification(String userName) {
    if (state.any((n) => n.id == 'notif-welcome')) return;
    final welcome = CampusNotification(
      id: 'notif-welcome',
      title: 'Selamat Datang, $userName!',
      message:
          'Pantau dan laporkan kondisi fasilitas kampus dengan mudah.',
      category: 'Kampus',
      createdAt: DateTime.now(),
      isRead: false,
      type: CampusNotificationType.info,
    );
    state = [welcome, ...state];
  }

  void addNotification({
    required String title,
    required String message,
    required String category,
    CampusNotificationType type = CampusNotificationType.info,
  }) {
    final newItem = CampusNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: message,
      category: category,
      createdAt: DateTime.now(),
      isRead: false,
      type: type,
    );
    state = [newItem, ...state];
  }
}
