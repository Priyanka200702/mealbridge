// Firebase Cloud Messaging Service Worker
// This file is required for FCM push notifications on the web platform.

importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCmiZQFQPV6A0v_bzoS0OJrbWN_6S3B3Qk",
  authDomain: "extrafood-f6deb.firebaseapp.com",
  projectId: "extrafood-f6deb",
  storageBucket: "extrafood-f6deb.firebasestorage.app",
  messagingSenderId: "927525905040",
  appId: "1:927525905040:web:89a9c223cfe31a9370ee15",
  measurementId: "G-VE24028MY3",
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log("[firebase-messaging-sw.js] Background message received:", payload);

  const notificationTitle = payload.notification?.title ?? "New Food Alert!";
  const notificationOptions = {
    body: payload.notification?.body ?? "Someone has added a food donation nearby.",
    icon: "/icons/Icon-192.png",
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
