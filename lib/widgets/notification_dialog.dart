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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
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
              Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
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
                
                // Allow typed notifications (claim, cancellation, etc.)
                if (data.containsKey('type') && data['type'] != null) return true;

                // For other notifications (like new food), require foodId and check expiry
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
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      "No new notifications",
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                    var doc = activeNotifications[index];
                    var data = doc.data() as Map<String, dynamic>;
                    var timestamp = data['timestamp'] as Timestamp?;
                    
                    bool isCancellation = data['type'] == 'cancellation_urgent' || data['type'] == 'ngo_cancellation';
                    bool isClaim = data['type'] == 'claim';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: data['isRead'] == true 
                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)
                            : (isCancellation ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: data['isRead'] == true
                              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
                              : (isCancellation ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isClaim 
                                    ? Icons.check_circle_outline 
                                    : (isCancellation ? Icons.cancel_outlined : Icons.food_bank),
                                color: isClaim
                                    ? Colors.blue.shade700
                                    : (isCancellation ? Colors.red.shade700 : Colors.green.shade700),
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
                              GestureDetector(
                                onTap: () {
                                  doc.reference.delete();
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            data['body'] ?? '',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            timestamp != null 
                                ? timeago.format(timestamp.toDate())
                                : 'Just now',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
