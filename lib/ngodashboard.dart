import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ngofood/services/notification_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngofood/widgets/sidebar_layout.dart';
import 'package:intl/intl.dart';
import 'package:ngofood/widgets/route_preview_modal.dart';
import 'package:ngofood/widgets/ngo_delivery_panel.dart';
import 'package:ngofood/widgets/review_listener.dart';
import 'dart:math';

class NGODashboard extends StatefulWidget {
  const NGODashboard({super.key});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  double? userLat;
  double? userLng;
  String locationStatus = "Fetching location...";
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
    NotificationService().cleanupOldNotifications();
  }

  Future<void> _initLocation() async {
    await getLocation();
  }

  Future<void> getLocation() async {
    setState(() => locationStatus = "Requesting permissions...");
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => locationStatus = "Location permission denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(
          () => locationStatus = "Location permissions are permanently denied.",
        );
        return;
      }

      setState(() => locationStatus = "Getting current position...");
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          userLat = pos.latitude;
          userLng = pos.longitude;
          locationStatus =
              "Current Location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
        });

        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'lat': pos.latitude, 'lng': pos.longitude});
        }
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) {
        setState(() {
          locationStatus = "Failed to get location. Tap to retry.";
        });
      }
    }
  }

  void _claimFood(
    BuildContext context,
    String id,
    DateTime scheduledTime,
  ) async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);

    try {
      var foodDoc = await FirebaseFirestore.instance
          .collection('foods')
          .doc(id)
          .get();
      if (!foodDoc.exists ||
          (foodDoc.data() as Map<String, dynamic>)['status'] != 'available') {
        throw Exception("Food is no longer available.");
      }

      var foodData = foodDoc.data() as Map<String, dynamic>;
      String? orgId = foodData['orgId'];
      String foodName = foodData['food'] ?? 'Food';

      User? user = FirebaseAuth.instance.currentUser;
      String ngoName = "An NGO";
      if (user != null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        ngoName = userDoc.data()?['name'] ?? "An NGO";
      }

      String otp = (Random().nextInt(900000) + 100000).toString();

      await FirebaseFirestore.instance.collection('foods').doc(id).update({
        'status': 'claimed',
        'deliveryStatus': 'active',
        'otp': otp,
        'otpStatus': 'pending',
        'ngoId': user?.uid,
        'pickupTime': FieldValue.serverTimestamp(),
        'scheduledPickupTime': Timestamp.fromDate(scheduledTime),
      });

      // Update history document as well
      await FirebaseFirestore.instance
          .collection('donations_history')
          .doc(id)
          .set({
            'ngoId': user?.uid,
            'ngoName': ngoName,
            'orgId': orgId,
            if (foodData['orgName'] != null) 'orgName': foodData['orgName'],
            if (foodData['food'] != null) 'food': foodData['food'],
            if (foodData['quantity'] != null) 'quantity': foodData['quantity'],
          }, SetOptions(merge: true));

      // Increment totalReceived for the NGO
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'totalReceived': FieldValue.increment(1)});
      }
      await NotificationService().clearNotificationsForFood(id);

      if (orgId != null) {
        await NotificationService().notifyOrganizationOnClaim(
          orgId: orgId,
          ngoName: ngoName,
          foodName: foodName,
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Food claimed successfully! 🎉"),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isClaiming = false);
    }
  }

  void _showRoutePreviewModal(
    BuildContext context,
    String foodId,
    Map<String, dynamic> data,
  ) {
    if (userLat == null ||
        userLng == null ||
        data['lat'] == null ||
        data['lng'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Location data not available for routing."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? expiryTimeStr;
    if (data['expiryTime'] != null) {
      Timestamp expiryTimestamp = data['expiryTime'] as Timestamp;
      expiryTimeStr = DateFormat(
        'MMM dd, hh:mm a',
      ).format(expiryTimestamp.toDate());
    }

    showDialog(
      context: context,
      builder: (dialogContext) => RoutePreviewModal(
        foodId: foodId,
        foodName: data['food'] ?? 'Food',
        quantity: data['quantity']?.toString() ?? 'N/A',
        orgName: data['orgName'] ?? 'Organisation',
        expiryTime: expiryTimeStr,
        restaurantLat: (data['lat'] as num).toDouble(),
        restaurantLng: (data['lng'] as num).toDouble(),
        ngoLat: userLat!,
        ngoLng: userLng!,
        onConfirm: (id, scheduledTime) =>
            _claimFood(context, id, scheduledTime),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    List<Color> gradient,
    IconData icon,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient[1].withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveOrdersWidget(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 40,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            "No Active Orders",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Claim a listing to start a delivery",
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReviewListener(
      isNGO: true,
      child: SidebarLayout(
        title: "Dashboard",
        activeMenu: "Dashboard",
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STATISTIC CARDS
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String mealsCount = "0";
                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          mealsCount = (data['totalReceived'] ?? 0).toString();
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildStatCard(
                                    "Meals Received",
                                    mealsCount,
                                    const [
                                      Color(0xFF34D399),
                                      Color(0xFF10B981),
                                    ],
                                    Icons.restaurant,
                                  ),
                                  const SizedBox(height: 16),
                                  NgoDeliveryPanel(
                                    ngoId:
                                        FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid ??
                                        '',
                                    fallbackWidget: _buildNoActiveOrdersWidget(
                                      context,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    "Meals Received",
                                    mealsCount,
                                    const [
                                      Color(0xFF34D399),
                                      Color(0xFF10B981),
                                    ],
                                    Icons.restaurant,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: NgoDeliveryPanel(
                                    ngoId:
                                        FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid ??
                                        '',
                                    fallbackWidget: _buildNoActiveOrdersWidget(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // The NgoDeliveryPanel was moved to the stats row above.

                    // NEARBY FOOD LISTINGS HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            "Nearby Food Listings",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // MAP BOX
                    Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      constraints: const BoxConstraints(
                        minHeight: 200,
                        maxHeight: 350,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).shadowColor.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: userLat == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Waiting for location...",
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Stack(
                              children: [
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('foods')
                                      .where('status', isEqualTo: 'available')
                                      .snapshots(),
                                  builder: (context, snapshot) {
                                    Set<Marker> markers = {};
                                    markers.add(
                                      Marker(
                                        markerId: const MarkerId(
                                          "current_user",
                                        ),
                                        position: LatLng(userLat!, userLng!),
                                        infoWindow: const InfoWindow(
                                          title: "My NGO",
                                          snippet: "Current Location",
                                        ),
                                        icon:
                                            BitmapDescriptor.defaultMarkerWithHue(
                                              BitmapDescriptor.hueOrange,
                                            ),
                                      ),
                                    );

                                    if (snapshot.hasData) {
                                      for (var doc in snapshot.data!.docs) {
                                        var data =
                                            doc.data() as Map<String, dynamic>;
                                        if (data['lat'] != null &&
                                            data['lng'] != null) {
                                          markers.add(
                                            Marker(
                                              markerId: MarkerId(doc.id),
                                              position: LatLng(
                                                (data['lat'] as num).toDouble(),
                                                (data['lng'] as num).toDouble(),
                                              ),
                                              infoWindow: InfoWindow(
                                                title:
                                                    data['orgName'] ??
                                                    'Organization',
                                                snippet:
                                                    "Food: ${data['food'] ?? 'N/A'}",
                                              ),
                                              icon:
                                                  BitmapDescriptor.defaultMarkerWithHue(
                                                    BitmapDescriptor.hueRed,
                                                  ),
                                            ),
                                          );
                                        }
                                      }
                                    }

                                    return GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(userLat!, userLng!),
                                        zoom: 14,
                                      ),
                                      markers: markers,
                                      myLocationEnabled: false,
                                      zoomControlsEnabled: false,
                                      onMapCreated:
                                          (GoogleMapController controller) {
                                            controller.animateCamera(
                                              CameraUpdate.newLatLngZoom(
                                                LatLng(userLat!, userLng!),
                                                14,
                                              ),
                                            );
                                          },
                                    );
                                  },
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "Urgent Food Requests",
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('foods')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                var docs = snapshot.data?.docs ?? [];
                var availableDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['status'] != 'available') return false;
                  if (userLat != null &&
                      userLng != null &&
                      data['lat'] != null &&
                      data['lng'] != null) {
                    double itemLat = (data['lat'] as num).toDouble();
                    double itemLng = (data['lng'] as num).toDouble();
                    double distance = Geolocator.distanceBetween(
                      userLat!,
                      userLng!,
                      itemLat,
                      itemLng,
                    );
                    return distance <= 5000;
                  }
                  return true;
                }).toList();

                if (availableDocs.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.no_food_outlined,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            userLat == null
                                ? "Waiting for location..."
                                : "No food available within 5km",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Use LayoutBuilder for responsive grid vs list
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      var doc = availableDocs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      var timestamp = data['timestamp'] as Timestamp?;
                      String timeStr = timestamp != null
                          ? timeago.format(timestamp.toDate())
                          : 'Recently';

                      // Determine urgency randomly or based on expiry for UI demo
                      bool isUrgent = index % 2 == 0;

                      double distanceKm = 0.0;
                      if (userLat != null &&
                          userLng != null &&
                          data['lat'] != null &&
                          data['lng'] != null) {
                        distanceKm =
                            Geolocator.distanceBetween(
                              userLat!,
                              userLng!,
                              (data['lat'] as num).toDouble(),
                              (data['lng'] as num).toDouble(),
                            ) /
                            1000;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  image: const DecorationImage(
                                    image: NetworkImage(
                                      'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=150&q=80',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['orgName'] ??
                                          data['name'] ??
                                          'Restaurant',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${distanceKm.toStringAsFixed(1)} km • $timeStr",
                                          style: GoogleFonts.inter(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      data['food'] ?? 'Food Package',
                                      style: GoogleFonts.inter(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isUrgent
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF22C55E),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isUrgent ? "URGENT" : "NORMAL",
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () => _showRoutePreviewModal(
                                      context,
                                      doc.id,
                                      data,
                                    ),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            MediaQuery.of(context).size.width >
                                                360
                                            ? 16
                                            : 8,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF22C55E),
                                            Color(0xFF16A34A),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "View Details",
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize:
                                              MediaQuery.of(
                                                    context,
                                                  ).size.width >
                                                  360
                                              ? 12
                                              : 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }, childCount: availableDocs.length),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
