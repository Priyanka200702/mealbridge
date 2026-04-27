import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ngofood/login.dart';
import 'package:ngofood/leaderboard.dart';
import 'package:ngofood/profile.dart';
import 'package:ngofood/ngodashboard.dart';
import 'package:ngofood/dashboard.dart';
import 'package:ngofood/widgets/notification_dialog.dart';
import 'package:ngofood/contact_us.dart';
import 'package:ngofood/faq.dart';
import 'package:ngofood/donation_history_page.dart';
import 'package:ngofood/main.dart'; // To access MyApp.of(context)

class SidebarLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final String activeMenu;

  const SidebarLayout({
    super.key,
    required this.child,
    required this.title,
    required this.activeMenu,
  });

  @override
  State<SidebarLayout> createState() => _SidebarLayoutState();
}

class _SidebarLayoutState extends State<SidebarLayout> {
  String orgName = "Loading...";
  String? role;
  String profileEmoji = "🏢";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        var data = doc.data();
        String newName = data?['name'] ?? "User";
        String? newRole = data?['role'];
        String newEmoji = data?['profileEmoji'] ?? (newRole == 'ngo' ? '🤝' : '🏢');
        
        if (orgName != newName || role != newRole || profileEmoji != newEmoji) {
          setState(() {
            orgName = newName;
            role = newRole;
            profileEmoji = newEmoji;
          });
        }
      }
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    bool isActive,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF22C55E), Color(0xFF4ADE80)],
              )
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: isActive
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContent(BuildContext context, bool isDark) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).scaffoldBackgroundColor,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Profile Section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      profileEmoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  orgName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                // GestureDetector(
                //   onTap: () {
                //     if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
                //     Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                //   },
                //   child: Text(
                //     "Edit Profile",
                //     style: GoogleFonts.inter(
                //       fontSize: 13,
                //       color: const Color(0xFF16A34A),
                //       fontWeight: FontWeight.w500,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMenuItem(
                  Icons.dashboard_outlined,
                  "Dashboard",
                  widget.activeMenu == "Dashboard",
                  () async {
                    if (widget.activeMenu != "Dashboard") {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        var doc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .get();
                        String role = doc.data()?['role'] ?? 'ngo';
                        if (!context.mounted) return;
                        if (role == 'ngo') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NGODashboard(),
                            ),
                          );
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Dashboard(),
                            ),
                          );
                        }
                      }
                    }
                  },
                  isDark,
                ),
                _buildMenuItem(
                  Icons.history_outlined,
                  "History",
                  widget.activeMenu == "History",
                  () {
                    if (widget.activeMenu != "History") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DonationHistoryPage(isNGO: role == 'ngo'),
                        ),
                      );
                    }
                  },
                  isDark,
                ),
                _buildMenuItem(
                  Icons.person_outline,
                  "Profile",
                  widget.activeMenu == "Profile",
                  () {
                    if (widget.activeMenu != "Profile") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    }
                  },
                  isDark,
                ),
                _buildMenuItem(
                  Icons.leaderboard_outlined,
                  "Leaderboard",
                  widget.activeMenu == "Leaderboard",
                  () {
                    if (widget.activeMenu != "Leaderboard") {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LeaderboardPage(),
                        ),
                      );
                    }
                  },
                  isDark,
                ),
                _buildMenuItem(
                  Icons.contact_support_outlined,
                  "Contact Us",
                  widget.activeMenu == "Contact Us",
                  () {
                    if (widget.activeMenu != "Contact Us") {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContactUsPage(),
                        ),
                      );
                    }
                  },
                  isDark,
                ),
                _buildMenuItem(
                  Icons.help_outline,
                  "FAQ",
                  widget.activeMenu == "FAQ",
                  () {
                    if (widget.activeMenu != "FAQ") {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const FAQPage()),
                      );
                    }
                  },
                  isDark,
                ),
              ],
            ),
          ),

          // Theme Toggle and Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  "Dark Mode",
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: MyApp.of(context).isDarkMode,
                  activeThumbColor: const Color(0xFF16A34A),
                  onChanged: (val) {
                    MyApp.of(context).toggleTheme();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
            child: _buildMenuItem(
              Icons.logout_outlined,
              "Logout",
              false,
              _logout,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth >= 800;

        PreferredSizeWidget header = AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: isDesktop
              ? null
              : Builder(
                  builder: (context) => IconButton(
                    icon: Icon(
                      Icons.menu,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
          title: Text(
            isDesktop
                ? "${role == 'organization' ? 'Organisation Dashboard' : role == 'ngo' ? 'NGO Dashboard' : 'Dashboard'} • Welcome, $orgName!"
                : "Welcome, $orgName!",
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: isDesktop ? 22 : 18,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
          actions: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .collection('notifications')
                  .where('isRead', isEqualTo: false)
                  .snapshots(),
              builder: (context, snapshot) {
                int unreadCount = snapshot.data?.docs.length ?? 0;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.notifications_none,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => const NotificationDialog(),
                        ).then((_) async {
                          final userId = FirebaseAuth.instance.currentUser?.uid;
                          if (userId != null) {
                            var unreadDocs = await FirebaseFirestore.instance
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
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: GoogleFonts.inter(
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
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: Icon(
                  Icons.account_circle,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
            ),
          ],
        );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                _buildSidebarContent(context, isDark),
                Expanded(
                  child: Scaffold(
                    backgroundColor: Colors.transparent,
                    appBar: header,
                    body: widget.child,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: header,
          drawer: Drawer(child: _buildSidebarContent(context, isDark)),
          body: widget.child,
        );
      },
    );
  }
}
