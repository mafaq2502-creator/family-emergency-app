import 'package:shared_preferences/shared_preferences.dart';

class IntroPreferences {
  static const seenKey = 'intro_seen';

  /// Claim the first launch immediately, even if the user closes the intro.
  Future<bool> claimFirstLaunch() async {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(seenKey) == true) return false;
    if (!await preferences.setBool(seenKey, true)) {
      throw StateError('Could not save first-launch preference');
    }
    return true;
  }
}
