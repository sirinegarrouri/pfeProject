importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyC2tZnDw5v3i5EZg1CjAdXwQztGSYVWa50",
  authDomain: "alertsys-80d0e.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "alertsys-80d0e.appspot.com",
  messagingSenderId: "576374987805",
  appId: "1:576374987805:android:f4ca3a2c738916898ffaf4"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("🎯 Received background message: ", payload);

  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: "/firebase-logo.png",
  });
});
