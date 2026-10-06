import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

class Notifications {
  static const _topic = 'new-stars';

  static Future<void> start({required ValueChanged<String?> onOpened, required VoidCallback onArrived}) async {
    if (kIsWeb) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.subscribeToTopic(_topic);

      FirebaseMessaging.onMessage.listen((_) => onArrived());
      FirebaseMessaging.onMessageOpenedApp.listen((message) => onOpened(message.data['starId']));
      final first = await messaging.getInitialMessage();
      if (first != null) onOpened(first.data['starId']);
    } catch (error) {
      debugPrint('Notifications are off: $error');
    }
  }
}
