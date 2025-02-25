import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Demander la permission de recevoir des notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("✅ Permission accordée !");

      // Obtenir le token FCM
      String? token = await _firebaseMessaging.getToken();
      print("🔑 Token FCM : $token");

      // Gérer les messages en arrière-plan
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Gérer les messages quand l'app est en foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print("📩 Nouveau message : ${message.notification?.title}");
        _showNotification(message);
      });
    } else {
      print("❌ Permission refusée !");
    }
  }

  // Fonction pour afficher la notification localement
  static void _showNotification(RemoteMessage message) {
    // Tu peux personnaliser ici l'affichage de la notification
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("📩 Message reçu en arrière-plan : ${message.notification?.title}");
  }
}
