import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification_settings.dart';
import 'profile_service.dart';

class NotificationSettingsService {
  NotificationSettingsService({ProfileService? profileService}) : _profileService = profileService ?? ProfileService();

  final ProfileService _profileService;

  Future<void> save(User user, NotificationSettings settings) => _profileService.saveNotificationSettings(user, settings);
}
