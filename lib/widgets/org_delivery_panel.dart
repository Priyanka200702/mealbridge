import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:ngofood/services/notification_service.dart';

class OrgDeliveryPanel extends StatefulWidget {
  final String orgId;
  final Widget fallbackWidget;

  const OrgDeliveryPanel({
    super.key,
    required this.orgId,
    required this.fallbackWidget,
  });

  @override
  State<OrgDeliveryPanel> createState() => _OrgDeliveryPanelState();
}

class _OrgDeliveryPanelState extends State<OrgDeliveryPanel> {
  void _cancelDelivery(BuildContext context, String foodId, String ngoId, String foodName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Pickup?"),
        content: Text("Are you sure you want to cancel the pickup for $foodName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Yes, Cancel"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        
        // Mark as cancelled
        batch.update(FirebaseFirestore.instance.collection('foods').doc(foodId), {
          'deliveryStatus': 'cancelled',
          'status': 'cancelled',
        });
        
        batch.update(FirebaseFirestore.instance.collection('donations_history').doc(foodId), {
          'deliveryStatus': 'cancelled',
        });

        await batch.commit();

        // Notify NGO
        String orgName = "An Organisation";
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.orgId).get();
        if (userDoc.exists) orgName = userDoc.data()?['name'] ?? orgName;

        await NotificationService().notifyNgoOnCancellation(
          ngoId: ngoId,
          orgName: orgName,
          foodName: foodName,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pickup cancelled successfully."), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('foods')
          .where('orgId', isEqualTo: widget.orgId)
          .where('deliveryStatus', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return widget.fallbackWidget;
        }

        // Sort by scheduledPickupTime
        var docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          Timestamp? t1 = (a.data() as Map<String, dynamic>)['scheduledPickupTime'];
          Timestamp? t2 = (b.data() as Map<String, dynamic>)['scheduledPickupTime'];
          if (t1 == null) return 1;
          if (t2 == null) return -1;
          return t1.compareTo(t2);
        });

        var mainDoc = docs.first;
        var mainData = mainDoc.data() as Map<String, dynamic>;
        var otherOrders = docs.skip(1).toList();

        return Column(
          children: [
            _buildMainCard(context, mainDoc.id, mainData),
            if (otherOrders.isNotEmpty) ...[
              const SizedBox(height: 8),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    "Show ${otherOrders.length} more active orders",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  children: otherOrders.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildConciseCard(context, doc.id, data);
                  }).toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMainCard(BuildContext context, String foodId, Map<String, dynamic> data) {
    String otp = data['otp'] ?? '------';
    String foodName = data['food'] ?? 'Food Package';
    String quantity = data['quantity']?.toString() ?? 'N/A';
    DateTime? scheduledTime;
    if (data['scheduledPickupTime'] != null) {
      scheduledTime = (data['scheduledPickupTime'] as Timestamp).toDate();
    }

    return FutureBuilder<DocumentSnapshot?>(
      future: (data['ngoId'] != null && data['ngoId'].toString().isNotEmpty)
          ? FirebaseFirestore.instance.collection('users').doc(data['ngoId']).get()
          : Future.value(null),
      builder: (context, ngoSnapshot) {
        String ngoName = "Loading...";
        if (ngoSnapshot.hasData && ngoSnapshot.data!.exists) {
          ngoName = (ngoSnapshot.data!.data() as Map<String, dynamic>)['name'] ?? "NGO";
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Delivery Verification",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildIconText(Icons.person, ngoName),
                  const SizedBox(height: 4),
                  _buildIconText(Icons.restaurant, "$foodName (Qty: $quantity)"),
                  const SizedBox(height: 16),
                  Text(
                    "Share this OTP with NGO",
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      otp,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                  if (scheduledTime != null) ...[
                    const SizedBox(height: 8),
                    _CountdownTimer(scheduledTime: scheduledTime),
                  ],
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Icon(
                  Icons.shield_outlined,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 48,
                ),
              ),
              // Cancellation Button
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: () => _cancelDelivery(context, foodId, data['ngoId'] as String? ?? '', foodName),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConciseCard(BuildContext context, String foodId, Map<String, dynamic> data) {
    String otp = data['otp'] ?? '------';
    String foodName = data['food'] ?? 'Food';
    DateTime? scheduledTime;
    if (data['scheduledPickupTime'] != null) {
      scheduledTime = (data['scheduledPickupTime'] as Timestamp).toDate();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foodName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (scheduledTime != null)
                  Text(
                    "Pickup: ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}",
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              otp,
              style: GoogleFonts.inter(
                color: const Color(0xFF16A34A),
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _cancelDelivery(context, foodId, data['ngoId'] as String? ?? '', foodName),
            child: const Icon(Icons.cancel, color: Colors.red, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 16),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime scheduledTime;
  const _CountdownTimer({required this.scheduledTime});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  void _updateTime() {
    setState(() {
      _timeLeft = widget.scheduledTime.difference(DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_timeLeft.isNegative) {
      return Text(
        "Pickup time passed",
        style: GoogleFonts.inter(
          color: const Color(0xFFFFB2B2),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    String hours = _timeLeft.inHours > 0 ? '${_timeLeft.inHours.toString().padLeft(2, '0')}:' : '';
    String minutes = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    String seconds = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        Icon(Icons.timer_outlined, color: Colors.white.withValues(alpha: 0.8), size: 14),
        const SizedBox(width: 4),
        Text(
          "Pickup in: $hours$minutes:$seconds",
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
