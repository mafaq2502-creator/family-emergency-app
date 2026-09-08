enum CircleRole {
  owner,
  parent,
  adult,
  child;

  String get value => name;

  bool get canManageCircle => this == owner || this == parent;
  bool get canManageMembers => this == owner || this == parent;
  bool get canDeleteCircle => this == owner;

  static CircleRole fromValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return CircleRole.values.firstWhere(
      (role) => role.value == normalized,
      orElse: () =>
          normalized == 'admin' ? CircleRole.parent : CircleRole.adult,
    );
  }
}
