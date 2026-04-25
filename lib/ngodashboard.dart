import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ngofood/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ngofood/widgets/notification_dialog.dart';
import 'package:ngofood/services/notification_service.dart';
import 'package:ngofood/org_profile_view.dart';
import 'package:ngofood/widgets/countdown_timer.dart';

class NGODashboard extends StatefulWidget {
  const NGODashboard({super.key});

  @override
  State<NGODashboard> createState() => _NGODashboardState();
}

class _NGODashboardState extends State<NGODashboard> {
  double? userLat;
  double? userLng;
  String locationStatus = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Clean up notifications older than 1 day
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          userLat = pos.latitude;
          userLng = pos.longitude;
          locationStatus =
              "Current Location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
        });

        // Save location to user profile for nearby notifications
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

  void _claimFood(BuildContext context, String id) async {
    try {
      // 1. Get food details BEFORE updating status
      var foodDoc = await FirebaseFirestore.instance
          .collection('foods')
          .doc(id)
          .get();
      var foodData = foodDoc.data() as Map<String, dynamic>;
      String? orgId = foodData['orgId'];
      String foodName = foodData['food'] ?? 'Food';

      // 2. Get current NGO name
      User? user = FirebaseAuth.instance.currentUser;
      String ngoName = "An NGO";
      if (user != null) {
        var userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        ngoName = userDoc.data()?['name'] ?? "An NGO";
      }

      // 3. Delete the food document (Autodeletion on claim)
      await FirebaseFirestore.instance.collection('foods').doc(id).delete();

      // 4. Clear notifications for this food across all NGOs
      await NotificationService().clearNotificationsForFood(id);

      // 5. Notify the organization
      if (orgId != null) {
        await NotificationService().notifyOrganizationOnClaim(
          orgId: orgId,
          ngoName: ngoName,
          foodName: foodName,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Food claimed successfully! 🎉"),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showClaimDialog(BuildContext context, String foodId, String foodName, String orgName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Confirm Claim"),
        content: Text("Are you sure you want to claim $foodName from $orgName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No", style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _claimFood(context, foodId);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                "NGO Dashboard",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            actions: [
              // NOTIFICATION BELL (Moved to the left of Logout)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser?.uid)
                      .collection('notifications')
                      .where('isRead', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    int unreadCount = snapshot.data?.docs.length ?? 0;
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => const NotificationDialog(),
                              ).then((_) async {
                                // Mark all as read when closed
                                final userId =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (userId != null) {
                                  var unreadDocs = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(userId)
                                      .collection('notifications')
                                      .where('isRead', isEqualTo: false)
                                      .get();
                                  for (var doc in unreadDocs.docs) {
                                    doc.reference.update({'isRead': true});
                                  }
                                }
                              });
                            },
                            icon: Icon(
                              unreadCount > 0
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              // LOGOUT BUTTON (Moved to far right)
              Padding(
                padding: const EdgeInsets.only(right: 16, left: 8, top: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () async {
                      try {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error logging out: $e")),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Logout',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Explore Nearby Food",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // MAP BOX
                  Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
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
                                  style: TextStyle(color: Colors.grey.shade600),
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

                                  // Current User Marker (NGO)
                                  markers.add(
                                    Marker(
                                      markerId: const MarkerId("current_user"),
                                      position: LatLng(userLat!, userLng!),
                                      infoWindow: const InfoWindow(
                                        title: "My NGO",
                                        snippet: "Current Location",
                                      ),
                                      icon: BitmapDescriptor.defaultMarkerWithHue(
                                        BitmapDescriptor.hueOrange,
                                      ),
                                    ),
                                  );

                                  if (snapshot.hasData) {
                                    for (var doc in snapshot.data!.docs) {
                                      var data = doc.data() as Map<String, dynamic>;
                                      if (data['lat'] != null && data['lng'] != null) {
                                        markers.add(
                                          Marker(
                                            markerId: MarkerId(doc.id),
                                            position: LatLng(
                                              (data['lat'] as num).toDouble(),
                                              (data['lng'] as num).toDouble(),
                                            ),
                                            infoWindow: InfoWindow(
                                              title: data['orgName'] ?? 'Organization',
                                              snippet: "Food: ${data['food'] ?? 'N/A'}",
                                            ),
                                            icon: BitmapDescriptor.defaultMarkerWithHue(
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
                                    onMapCreated: (GoogleMapController controller) {
                                      // Smooth camera focus
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
                              // Overlay label
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.volunteer_activism, color: Colors.red, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Nearby Donations",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    "Available for Claiming",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              var docs = snapshot.data?.docs ?? [];

              // Filter by availability AND 5km radius
              var availableDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['status'] != 'available') return false;

                // Distance filtering (5km radius)
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
                  return distance <= 5000; // 5km
                }
                return true; // Show all available food if NGO location is still loading
              }).toList();

              if (availableDocs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
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
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (userLat != null)
                          TextButton(
                            onPressed: () => getLocation(),
                            child: const Text("Refresh Location"),
                          ),
                      ],
                    ),
                  ),
                );
              }

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

                    return GestureDetector(
                      onTap: () {
                        final orgId = data['orgId'] as String?;
                        if (orgId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrgProfileView(orgId: orgId),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Organisation info not available"),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 55,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  Icons.fastfood,
                                  color: Colors.green.shade600,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['food'] ?? 'Food',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Qty: ${data['quantity']}",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (data['expiryTime'] != null) ...[
                                      const SizedBox(height: 6),
                                      CountdownTimer(
                                        expiryTime:
                                            (data['expiryTime'] as Timestamp)
                                                .toDate(),
                                        onExpired: () async {
                                          await FirebaseFirestore.instance
                                              .collection('foods')
                                              .doc(doc.id)
                                              .delete();
                                          // Clear notifications for this food
                                          await NotificationService()
                                              .clearNotificationsForFood(
                                                doc.id,
                                              );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _showClaimDialog(
                                  context,
                                  doc.id,
                                  data['food'] ?? 'Food',
                                  data['orgName'] ?? data['name'] ?? 'this organisation',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade600,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "CLAIM",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}
