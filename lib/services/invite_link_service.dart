import 'package:app_links/app_links.dart';

abstract interface class InviteLinkSource {
  Future<Uri?> getInitialLink();
  Stream<Uri> get linkStream;
}

class InviteLinkService implements InviteLinkSource {
  InviteLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}
