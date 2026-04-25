import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DonationHistoryPage extends StatefulWidget {
  const DonationHistoryPage({super.key});

  @override
  State<DonationHistoryPage> createState() => _DonationHistoryPageState();
}

class _DonationHistoryPageState extends State<DonationHistoryPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  String _filter = "All Time";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text("Donation History"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            icon: const Icon(Icons.filter_list),
            itemBuilder: (context) => [
              const PopupMenuItem(value: "All Time", child: Text("All Time")),
              const PopupMenuItem(value: "This Week", child: Text("This Week")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filter != "All Time")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
              child: Row(
                children: [
                  Chip(
                    label: Text(_filter, style: const TextStyle(color: Colors.white)),
                    backgroundColor: Colors.green.shade700,
                    onDeleted: () {
                      setState(() {
                        _filter = "All Time";
                      });
                    },
                    deleteIconColor: Colors.white,
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text(
                          "No donations yet",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Your contributions will appear here.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var donation = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    return _buildDonationCard(donation, index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    var query = FirebaseFirestore.instance
        .collection('donations_history')
        .where('orgId', isEqualTo: user?.uid)
        .orderBy('timestamp', descending: true);

    if (_filter == "This Week") {
      DateTime lastWeek = DateTime.now().subtract(const Duration(days: 7));
      query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeek));
    }

    return query.snapshots();
  }

  Widget _buildDonationCard(Map<String, dynamic> donation, int index) {
    DateTime? timestamp = (donation['timestamp'] as Timestamp?)?.toDate();
    String formattedDate = timestamp != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp) : 'Unknown';
    
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getFoodIcon(donation['food'] ?? ''),
              color: Colors.green.shade700,
              size: 24,
            ),
          ),
          title: Text(
            donation['food'] ?? 'Unknown Food',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                "Quantity: ${donation['quantity'] ?? 'N/A'}",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade100.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "Shared",
              style: TextStyle(
                color: Colors.green,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFoodIcon(String foodName) {
    foodName = foodName.toLowerCase();
    if (foodName.contains('apple') || foodName.contains('fruit')) return Icons.apple;
    if (foodName.contains('bread') || foodName.contains('bakery')) return Icons.bakery_dining;
    if (foodName.contains('rice') || foodName.contains('biryani') || foodName.contains('meal')) return Icons.restaurant;
    if (foodName.contains('milk') || foodName.contains('drink')) return Icons.local_drink;
    return Icons.fastfood;
  }
}
