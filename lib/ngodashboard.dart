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
import 'package:google_fonts/google_fonts.dart';
import 'package:ngofood/widgets/sidebar_layout.dart';

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
        setState(() => locationStatus = "Location permissions are permanently denied.");
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
          locationStatus = "Current Location: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
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

  void _claimFood(BuildContext context, String id) async {
    try {
      var foodDoc = await FirebaseFirestore.instance.collection('foods').doc(id).get();
      var foodData = foodDoc.data() as Map<String, dynamic>;
      String? orgId = foodData['orgId'];
      String foodName = foodData['food'] ?? 'Food';

      User? user = FirebaseAuth.instance.currentUser;
      String ngoName = "An NGO";
      if (user != null) {
        var userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        ngoName = userDoc.data()?['name'] ?? "An NGO";
      }

      await FirebaseFirestore.instance.collection('foods').doc(id).delete();
      await NotificationService().clearNotificationsForFood(id);

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

  Widget _buildStatCard(String title, String value, List<Color> gradient, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: gradient[1].withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(icon, color: Colors.white.withOpacity(0.2), size: 48),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SidebarLayout(
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 600) {
                        return Column(
                          children: [
                            _buildStatCard("Meals Received", "256", const [Color(0xFF34D399), Color(0xFF10B981)], Icons.restaurant),
                            const SizedBox(height: 16),
                            _buildStatCard("Deliveries Completed", "124", const [Color(0xFFFBBF24), Color(0xFFF97316)], Icons.delivery_dining),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: _buildStatCard("Meals Received", "256", const [Color(0xFF34D399), Color(0xFF10B981)], Icons.restaurant)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildStatCard("Deliveries Completed", "124", const [Color(0xFFFBBF24), Color(0xFFF97316)], Icons.delivery_dining)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // NEARBY FOOD LISTINGS HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Nearby Food Listings",
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF10B981)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.route, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Optimize Route",
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // MAP BOX
                  Container(
                    height: 260,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
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
                                Text("Waiting for location...", style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('foods').where('status', isEqualTo: 'available').snapshots(),
                                builder: (context, snapshot) {
                                  Set<Marker> markers = {};
                                  markers.add(
                                    Marker(
                                      markerId: const MarkerId("current_user"),
                                      position: LatLng(userLat!, userLng!),
                                      infoWindow: const InfoWindow(title: "My NGO", snippet: "Current Location"),
                                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                                    ),
                                  );

                                  if (snapshot.hasData) {
                                    for (var doc in snapshot.data!.docs) {
                                      var data = doc.data() as Map<String, dynamic>;
                                      if (data['lat'] != null && data['lng'] != null) {
                                        markers.add(
                                          Marker(
                                            markerId: MarkerId(doc.id),
                                            position: LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()),
                                            infoWindow: InfoWindow(title: data['orgName'] ?? 'Organization', snippet: "Food: ${data['food'] ?? 'N/A'}"),
                                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                          ),
                                        );
                                      }
                                    }
                                  }

                                  return GoogleMap(
                                    initialCameraPosition: CameraPosition(target: LatLng(userLat!, userLng!), zoom: 14),
                                    markers: markers,
                                    myLocationEnabled: false,
                                    zoomControlsEnabled: false,
                                    onMapCreated: (GoogleMapController controller) {
                                      controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(userLat!, userLng!), 14));
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
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('foods').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }

              var docs = snapshot.data?.docs ?? [];
              var availableDocs = docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['status'] != 'available') return false;
                if (userLat != null && userLng != null && data['lat'] != null && data['lng'] != null) {
                  double itemLat = (data['lat'] as num).toDouble();
                  double itemLng = (data['lng'] as num).toDouble();
                  double distance = Geolocator.distanceBetween(userLat!, userLng!, itemLat, itemLng);
                  return distance <= 5000;
                }
                return true;
              }).toList();

              if (availableDocs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.no_food_outlined, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          userLat == null ? "Waiting for location..." : "No food available within 5km",
                          style: const TextStyle(color: Colors.grey),
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
                    String timeStr = timestamp != null ? timeago.format(timestamp.toDate()) : 'Recently';

                    // Determine urgency randomly or based on expiry for UI demo
                    bool isUrgent = index % 2 == 0; 
                    
                    double distanceKm = 0.0;
                    if (userLat != null && userLng != null && data['lat'] != null && data['lng'] != null) {
                      distanceKm = Geolocator.distanceBetween(
                        userLat!, userLng!, 
                        (data['lat'] as num).toDouble(), 
                        (data['lng'] as num).toDouble()
                      ) / 1000;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
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
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                image: const DecorationImage(
                                  image: NetworkImage('https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=150&q=80'),
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
                                    data['orgName'] ?? data['name'] ?? 'Restaurant',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${distanceKm.toStringAsFixed(1)} km • $timeStr",
                                        style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data['food'] ?? 'Food Package',
                                    style: GoogleFonts.inter(color: Colors.black87, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isUrgent ? "URGENT" : "NORMAL",
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                InkWell(
                                  onTap: () => _showClaimDialog(context, doc.id, data['food'] ?? 'Food', data['orgName'] ?? 'Organisation'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "View Details",
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
    );
  }
}
