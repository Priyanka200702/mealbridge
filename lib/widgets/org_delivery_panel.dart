import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class OrgDeliveryPanel extends StatelessWidget {
  final String orgId;
  final Widget fallbackWidget;

  const OrgDeliveryPanel({
    super.key,
    required this.orgId,
    required this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('foods')
          .where('orgId', isEqualTo: orgId)
          .where('deliveryStatus', isEqualTo: 'active')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return fallbackWidget;
        }

        var doc = snapshot.data!.docs.first;
        var data = doc.data() as Map<String, dynamic>;

        String otp = data['otp'] ?? '------';
        String foodName = data['food'] ?? 'Food Package';
        String quantity = data['quantity']?.toString() ?? 'N/A';

        // Fetch NGO details dynamically since only ngoId is stored
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(data['ngoId']).get(),
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
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.white.withValues(alpha: 0.8), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              ngoName,
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
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.restaurant, color: Colors.white.withValues(alpha: 0.8), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "$foodName (Qty: $quantity)",
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
                ],
              ),
            );
          },
        );
      },
    );
  }
}
