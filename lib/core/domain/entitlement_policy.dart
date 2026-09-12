class CircleEntitlementPolicy {
  const CircleEntitlementPolicy._();

  static const freeOwnedLimit = 1;
  static const freeJoinedLimit = 1;
  static const freeMemberLimit = 3;
  static const premiumMemberLimit = 11;

  static bool canCreate({required bool premium, required int owned}) =>
      premium || owned < freeOwnedLimit;

  static bool canJoin({required bool premium, required int joined}) =>
      premium || joined < freeJoinedLimit;

  static int memberLimit({required bool premium}) =>
      premium ? premiumMemberLimit : freeMemberLimit;

  static bool canReserveInvite({
    required bool premium,
    required int activeMembers,
    required int activeInvites,
  }) =>
      activeMembers + activeInvites < memberLimit(premium: premium);
}
