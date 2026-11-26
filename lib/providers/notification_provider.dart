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
  List<CampusNotification> build() {
    final now = DateTime.now();
    return [
      CampusNotification(
        id: 'notif-welcome',
        title: 'Selamat Datang di CampusGhost!',
        message:
            'Pantau kendala dan laporkan fasilitas kampus Pradita University dengan cepat dan mudah.',
        category: 'Kampus',
        createdAt: now,
        isRead: false,
        type: CampusNotificationType.info,
      ),
      CampusNotification(
        id: 'notif-1',
        title: 'AC Gedung 2 Ruang 202 Sedang Diperbaiki',
        message:
            'Teknisi Sarpras/GA telah menerima laporan Anda dan sedang melakukan perbaikan di lokasi.',
        category: 'Ac',
        createdAt: now.subtract(const Duration(minutes: 15)),
        isRead: false,
        type: CampusNotificationType.inProgress,
      ),
      CampusNotification(
        id: 'notif-2',
        title: 'Investigasi Wi-Fi Gedung 1 Lantai 3',
        message:
            'Tiket #ICT-402 telah diteruskan ke tim jaringan Pradita untuk pengecekan access point.',
        category: 'Wifi',
        createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        isRead: false,
        type: CampusNotificationType.info,
      ),
      CampusNotification(
        id: 'notif-3',
        title: 'Perbaikan Lift Gedung Utama Selesai',
        message:
            'Lift penumpang 01 telah selesai diperbaiki dan siap digunakan kembali secara normal.',
        category: 'Lift',
        createdAt: now.subtract(const Duration(hours: 3)),
        isRead: true,
        type: CampusNotificationType.resolved,
      ),
    ];
  }

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
