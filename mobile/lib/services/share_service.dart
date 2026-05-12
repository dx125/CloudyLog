import 'package:share_plus/share_plus.dart';

abstract class ShareService {
  Future<void> shareText(String text, {String? subject});
}

class SharePlusShareService implements ShareService {
  const SharePlusShareService();

  @override
  Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}
