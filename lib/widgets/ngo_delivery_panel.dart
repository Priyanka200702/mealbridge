import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ngofood/services/notification_service.dart';

class NgoDeliveryPanel extends StatefulWidget {
  final String ngoId;
  final Widget fallbackWidget;

  const NgoDeliveryPanel({
    super.key,
    required this.ngoId,
    required this.fallbackWidget,
  });

  @override
  State<NgoDeliveryPanel> createState() => _NgoDeliveryPanelState();
}

class _NgoDeliveryPanelState extends State<NgoDeliveryPanel> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLocationVerified = false;
  bool _isCheckingLocation = false;
  String _locationStatus = "Pending Location Check";
  int _attempts = 0;
  bool _isSuccess = false;
  String? _lastFoodId;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _resetLocalState(String newId) {
    setState(() {
      _isSuccess = false;
      _isLocationVerified = false;
      _isCheckingLocation = false;
      _locationStatus = "Pending Location Check";
      _attempts = 0;
      _otpController.clear();
      _lastFoodId = newId;
    });
  }

  Future<void> _verifyLocation(double orgLat, double orgLng) async {
    setState(() {
      _isCheckingLocation = true;
      _locationStatus = "Getting current location...";
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          setState(() {
            _locationStatus = "Location Permission Denied";
            _isCheckingLocation = false;
          });
          return;
        }
      }

      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      double distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        orgLat,
        orgLng,
      );

      if (mounted) {
        setState(() {
          if (distance <= 100) {
            _isLocationVerified = true;
            _locationStatus = "Location Verified";
          } else {
            _isLocationVerified = false;
            _locationStatus = "Move closer to organisation (${distance.toStringAsFixed(0)}m away)";
          }
          _isCheckingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationStatus = "Failed to get location";
          _isCheckingLocation = false;
        });
      }
    }
  }

  void _verifyOTP(String correctOtp, String foodId) async {
    if (_attempts >= 3) return;

    if (_otpController.text.trim() == correctOtp) {
      setState(() {
        _isSuccess = true;
      });

      await FirebaseFirestore.instance.collection('foods').doc(foodId).update({
        'status': 'completed',
        'deliveryStatus': 'completed',
        'otpStatus': 'verified',
        'completionTime': FieldValue.serverTimestamp(),
      });

      // Increment totalDeliveries for the NGO
      await FirebaseFirestore.instance.collection('users').doc(widget.ngoId).update({
        'totalDeliveries': FieldValue.increment(1),
      });

      // Trigger review flags
      await FirebaseFirestore.instance.collection('donations_history').doc(foodId).update({
        'orgReviewPending': true,
        'ngoReviewPending': true,
      });
    } else {
      setState(() {
        _attempts++;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Invalid OTP. Attempts remaining: ${3 - _attempts}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelDelivery(BuildContext context, String foodId, String orgId, String foodName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Pickup?"),
        content: Text("Are you sure you want to cancel the pickup for $foodName? The item will become available for other NGOs."),
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
        
        // Revert to available
        batch.update(FirebaseFirestore.instance.collection('foods').doc(foodId), {
          'deliveryStatus': 'pending',
          'status': 'available',
          'ngoId': null,
          'otp': null,
          'scheduledPickupTime': null,
        });
        
        batch.update(FirebaseFirestore.instance.collection('donations_history').doc(foodId), {
          'deliveryStatus': 'pending',
          'ngoId': null,
          'ngoName': null,
        });

        await batch.commit();

        // Notify Org
        String ngoName = "An NGO";
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.ngoId).get();
        if (userDoc.exists) ngoName = userDoc.data()?['name'] ?? ngoName;

        await NotificationService().notifyOrgOnCancellation(
          orgId: orgId,
          ngoName: ngoName,
          foodName: foodName,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pickup cancelled. Item is back to available."), backgroundColor: Colors.orange),
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
          .where('ngoId', isEqualTo: widget.ngoId)
          .where('deliveryStatus', isEqualTo: 'active')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var doc = snapshot.data!.docs.first;
        var data = doc.data() as Map<String, dynamic>;

        String foodId = doc.id;
        if (_lastFoodId != foodId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _resetLocalState(foodId);
          });
          return const SizedBox.shrink();
        }
        String correctOtp = data['otp'] ?? '';
        String foodName = data['food'] ?? 'Food Package';
        String quantity = data['quantity']?.toString() ?? 'N/A';
        double orgLat = (data['lat'] as num?)?.toDouble() ?? 0.0;
        double orgLng = (data['lng'] as num?)?.toDouble() ?? 0.0;

        if (_isSuccess) {
          return _buildSuccessCard();
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
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Delivery Verification",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            FutureBuilder<DocumentSnapshot?>(
                              future: (data['orgId'] != null &&
                                      data['orgId'].toString().isNotEmpty)
                                  ? FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(data['orgId'])
                                      .get()
                                  : Future.value(null),
                              builder: (context, orgSnapshot) {
                                if (!orgSnapshot.hasData ||
                                    !orgSnapshot.data!.exists) {
                                  return const SizedBox.shrink();
                                }
                                var orgData =
                                    orgSnapshot.data!.data() as Map<String, dynamic>;
                                String orgName = orgData['name'] ?? 'Organisation';
                                int ratingCount = orgData['ratingCount'] ?? 0;
                                double totalRating =
                                    (orgData['totalRating'] ?? 0).toDouble();
                                double rating = ratingCount > 0
                                    ? totalRating / ratingCount
                                    : 0.0;

                                return Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        orgName,
                                        style: GoogleFonts.inter(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < rating.floor()
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 14,
                                        );
                                      }),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isCheckingLocation
                            ? null
                            : () => _verifyLocation(orgLat, orgLng),
                        icon: _isCheckingLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, color: Colors.white),
                        tooltip: "Refresh Location",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Food Details
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.restaurant, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$foodName (Qty: $quantity)",
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
                  ),
                  const SizedBox(height: 16),

                  // Step 1
                  Row(
                    children: [
                      Icon(
                        _isLocationVerified
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Step 1: Location Verification",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _locationStatus,
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Step 2
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isSuccess ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Step 2: Enter 6-digit OTP",
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TextField(
                                      controller: _otpController,
                                      enabled: _isLocationVerified && _attempts < 3,
                                      keyboardType: TextInputType.number,
                                      maxLength: 6,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 4,
                                      ),
                                      decoration: const InputDecoration(
                                        counterText: "",
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: (!_isLocationVerified || _attempts >= 3)
                                      ? null
                                      : () => _verifyOTP(correctOtp, foodId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF16A34A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 0,
                                    ),
                                    minimumSize: const Size(0, 40),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    "Verify",
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Cancellation Button
              Positioned(
                left: -10,
                bottom: -10,
                child: GestureDetector(
                  onTap: () => _cancelDelivery(
                    context,
                    foodId,
                    data['orgId'] as String? ?? '',
                    foodName,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                        ),
                      ],
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

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_turned_in_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              "No Active Orders",
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "When you claim a donation, the verification panel will appear here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: Container(
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      "Delivery Completed\nSuccessfully",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
