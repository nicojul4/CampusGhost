import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../enums/user_role.dart';

class UserRoleNotifier extends Notifier<UserRole> {
  @override
  UserRole build() => UserRole.student;

  void setRole(UserRole role) {
    state = role;
  }

  void toggleRole() {
    state = state == UserRole.student ? UserRole.technician : UserRole.student;
  }
}

final userRoleProvider =
    NotifierProvider<UserRoleNotifier, UserRole>(UserRoleNotifier.new);
