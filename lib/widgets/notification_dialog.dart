import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationDialog extends StatelessWidget {
  const NotificationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              )
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('notifications')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data?.docs ?? [];
              
              // Filter out notifications where the food has expired or are legacy
              var activeNotifications = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                
                // Allow "claim" type notifications even without foodId
                if (data['type'] == 'claim') return true;

                // For other notifications, require foodId and check expiry
                if (!data.containsKey('foodId') || data['foodId'] == null) {
                  return false;
                }

                final expiry = data['expiryTime'] as Timestamp?;
                if (expiry != null) {
                  return expiry.toDate().isAfter(DateTime.now());
                }
                
                return true; 
              }).toList();

              if (activeNotifications.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      "no new notification",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: activeNotifications.length,
                  itemBuilder: (context, index) {
                    var data = activeNotifications[index].data() as Map<String, dynamic>;
                    var timestamp = data['timestamp'] as Timestamp?;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: data['isRead'] == true 
                            ? Colors.grey.shade50 
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: data['isRead'] == true
                              ? Colors.grey.shade200
                              : Colors.green.shade100,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                data['type'] == 'claim' 
                                    ? Icons.check_circle_outline 
                                    : Icons.food_bank,
                                color: data['type'] == 'claim'
                                    ? Colors.blue.shade700
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  data['title'] ?? 'Alert',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            data['body'] ?? '',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            timestamp != null 
                                ? timeago.format(timestamp.toDate())
                                : 'Just now',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
