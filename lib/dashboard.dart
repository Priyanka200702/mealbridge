import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ngofood/add_food.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:google_fonts/google_fonts.dart';
import 'package:ngofood/widgets/sidebar_layout.dart';
import 'package:ngofood/widgets/org_delivery_panel.dart';
import 'package:ngofood/widgets/countdown_timer.dart';
import 'package:ngofood/services/notification_service.dart';
import 'package:ngofood/widgets/review_listener.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  double? userLat;
  double? userLng;

  Future<void> getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          userLat = pos.latitude;
          userLng = pos.longitude;
        });
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    getUserLocation();
    NotificationService().cleanupOldNotifications();
  }

  Widget _buildStatCard(String title, String value, List<Color> gradient, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: gradient[1].withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 5)),
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
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 48),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReviewListener(
      isNGO: false,
      child: SidebarLayout(
        title: "Dashboard",
      activeMenu: "Dashboard",
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
            boxShadow: [
              BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddFood()));
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            label: Text("DONATE FOOD", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
            icon: const Icon(Icons.add, color: Colors.white),
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
                    // Impact Cards
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                      builder: (context, snapshot) {
                        int count = 0;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          var data = snapshot.data!.data() as Map<String, dynamic>;
                          count = data['totalDonations'] ?? 0;
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              return Column(
                                children: [
                                  _buildStatCard("Total Donations", "$count", const [Color(0xFF34D399), Color(0xFF10B981)], Icons.favorite),
                                  const SizedBox(height: 16),
                                  OrgDeliveryPanel(
                                    orgId: FirebaseAuth.instance.currentUser?.uid ?? '',
                                    fallbackWidget: _buildStatCard("Active Listings", "View Below", const [Color(0xFF60A5FA), Color(0xFF3B82F6)], Icons.list_alt),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: _buildStatCard("Total Donations", "$count", const [Color(0xFF34D399), Color(0xFF10B981)], Icons.favorite)),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: OrgDeliveryPanel(
                                    orgId: FirebaseAuth.instance.currentUser?.uid ?? '',
                                    fallbackWidget: _buildStatCard("Active Listings", "View Below", const [Color(0xFF60A5FA), Color(0xFF3B82F6)], Icons.list_alt),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    Text(
                      "Nearby NGOs",
                      style: GoogleFonts.inter(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // MAP BOX
                    Container(
                      height: 260,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).shadowColor.withValues(alpha: 0.05), 
                            blurRadius: 15, 
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: userLat == null
                          ? const Center(child: CircularProgressIndicator())
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'ngo').snapshots(),
                              builder: (context, snapshot) {
                                Set<Marker> markers = {};
                                markers.add(
                                  Marker(
                                    markerId: const MarkerId("current_user"),
                                    position: LatLng(userLat!, userLng!),
                                    infoWindow: const InfoWindow(title: "My Organization", snippet: "Current Location"),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                                  ),
                                );

                                if (snapshot.hasData) {
                                  for (var doc in snapshot.data!.docs) {
                                    var data = doc.data() as Map<String, dynamic>;
                                    double? ngoLat = double.tryParse(data['lat']?.toString() ?? '');
                                    double? ngoLng = double.tryParse(data['lng']?.toString() ?? '');

                                    if (ngoLat != null && ngoLng != null) {
                                      markers.add(
                                        Marker(
                                          markerId: MarkerId(doc.id),
                                          position: LatLng(ngoLat, ngoLng),
                                          infoWindow: InfoWindow(title: data['name'] ?? 'NGO', snippet: data['address'] ?? 'No address'),
                                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                        ),
                                      );
                                    }
                                  }
                                }

                                return Stack(
                                  children: [
                                    GoogleMap(
                                      initialCameraPosition: CameraPosition(target: LatLng(userLat!, userLng!), zoom: 14),
                                      markers: markers,
                                      myLocationEnabled: false,
                                      zoomControlsEnabled: false,
                                      onMapCreated: (GoogleMapController controller) {
                                        controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(userLat!, userLng!), 14));
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      "Your Active Listings",
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
                  .where('orgId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }

                var docs = snapshot.data?.docs.toList() ?? [];
                docs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  var t1 = dataA['timestamp'] as Timestamp?;
                  var t2 = dataB['timestamp'] as Timestamp?;
                  if (t1 == null && t2 == null) return 0;
                  if (t1 == null) return 1;
                  if (t2 == null) return -1;
                  return t2.compareTo(t1);
                });

                var availableDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['status'] == 'available';
                }).toList();

                if (availableDocs.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            "You have no active listings.",
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurfaceVariant, 
                              fontSize: 16,
                            ),
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
                      String timeStr = timestamp != null ? timeago.format(timestamp.toDate()) : 'Recently';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor.withValues(alpha: 0.03), 
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
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.fastfood, color: Color(0xFF16A34A), size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(
                                        data['food'] ?? 'Food Package',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 16,
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                          Text(
                                            data['quantity'] ?? 'N/A',
                                            style: GoogleFonts.inter(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant, 
                                              fontSize: 13,
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.access_time, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 4),
                                          Text(
                                            timeStr,
                                            style: GoogleFonts.inter(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant, 
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (data['expiryTime'] != null) ...[
                                      const SizedBox(height: 6),
                                      CountdownTimer(
                                        expiryTime: (data['expiryTime'] as Timestamp).toDate(),
                                        onExpired: () async {
                                          await FirebaseFirestore.instance.collection('foods').doc(doc.id).delete();
                                          await NotificationService().clearNotificationsForFood(doc.id);
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  bool? confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Delete Food"),
                                      content: const Text("Are you sure you want to delete this food item?"),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await FirebaseFirestore.instance.collection('foods').doc(doc.id).delete();
                                    await NotificationService().clearNotificationsForFood(doc.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food deleted successfully")));
                                    }
                                  }
                                },
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
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    ));
  }
}
