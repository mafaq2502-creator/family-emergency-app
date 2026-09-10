import '../../models/circle_membership.dart';
import '../../models/circle_role.dart';

enum CircleLifecycleStatus { active, archived, deleted, unavailable }

class CircleNamePolicy {
  const CircleNamePolicy._();

  static const minLength = 2;
  static const maxLength = 60;
  static final _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');

  static String normalize(String? value) => value?.trim() ?? '';

  static String? validate(String? value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) return 'Please enter a family Circle name.';
    if (normalized.length < minLength) {
      return 'Circle name must contain at least $minLength characters.';
    }
    if (normalized.length > maxLength) {
      return 'Circle name must be $maxLength characters or fewer.';
    }
    if (_controlCharacters.hasMatch(normalized)) {
      return 'Please enter a valid Circle name.';
    }
    return null;
  }
}

class CirclePermissionPolicy {
  const CirclePermissionPolicy._();

  static bool canRename(CircleRole role) => role.canManageCircle;

  static bool canDelete(CircleRole role) => role.canDeleteCircle;

  static bool canLeave(CircleRole role) => role != CircleRole.owner;

  static bool canRemove({
    required CircleRole actorRole,
    required CircleMembership target,
    required String actorUserId,
  }) {
    if (!target.isActive || target.userId == actorUserId) return false;
    if (target.role == CircleRole.owner) return false;
    if (actorRole == CircleRole.owner) return true;
    if (actorRole == CircleRole.parent) {
      return target.role == CircleRole.adult || target.role == CircleRole.child;
    }
    return false;
  }
}
