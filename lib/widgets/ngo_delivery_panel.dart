import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';

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

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
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
          return widget.fallbackWidget;
        }

        var doc = snapshot.data!.docs.first;
        var data = doc.data() as Map<String, dynamic>;

        String foodId = doc.id;
        String correctOtp = data['otp'] ?? '';
        double orgLat = (data['lat'] as num).toDouble();
        double orgLng = (data['lng'] as num).toDouble();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Delivery Verification",
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: _isCheckingLocation ? null : () => _verifyLocation(orgLat, orgLng),
                    icon: _isCheckingLocation 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh, color: Colors.white),
                    tooltip: "Refresh Location",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Step 1
              Row(
                children: [
                  Icon(
                    _isLocationVerified ? Icons.check_circle : Icons.radio_button_unchecked,
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
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          _locationStatus,
                          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
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
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
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
                                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 4),
                                  decoration: const InputDecoration(
                                    counterText: "",
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                minimumSize: const Size(0, 40),
                                elevation: 0,
                              ),
                              child: Text("Verify", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
        );
      },
    );
  }

  Widget _buildSuccessCard() {
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
    );
  }
}
