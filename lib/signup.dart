import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:ngofood/dashboard.dart';
import 'package:ngofood/ngodashboard.dart';
import 'package:ngofood/services/notification_service.dart';
import 'package:ngofood/main.dart'; // To access MyApp.of(context)

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  SignupPageState createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage> {
  bool isOrg = true;

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // --- Location / Address State ---
  bool _isDetectingLocation = false;
  double? _lat;
  double? _lng;
  String? _addressString;

  // ────────────────────────────────────────────────
  // Detect GPS location and reverse-geocode address
  // ────────────────────────────────────────────────
  Future<void> _detectLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Location permission permanently denied. Enable it in Settings."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String address = "${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}";
      try {
        final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'json',
          'lat': position.latitude.toString(),
          'lon': position.longitude.toString(),
          'addressdetails': '1',
        });
        final response = await http.get(
          uri,
          headers: {'Accept-Language': 'en', 'User-Agent': 'NGOFoodApp/1.0'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final displayName = data['display_name'] as String?;
          if (displayName != null && displayName.isNotEmpty) {
            address = displayName;
          }
        }
      } catch (_) {}

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _addressString = address;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to detect location: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  // ────────────────────────────────────────────────
  // Signup logic
  // ────────────────────────────────────────────────
  void signup() async {
    if (nameCtrl.text.isEmpty ||
        emailCtrl.text.isEmpty ||
        phoneCtrl.text.isEmpty ||
        passCtrl.text.isEmpty ||
        confirmCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_addressString == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please detect your location 📍"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (passCtrl.text != confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Passwords do not match"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailCtrl.text.trim(),
            password: passCtrl.text,
          );

      final Map<String, dynamic> userData = {
        'name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'phone': phoneCtrl.text.trim(),
        'role': isOrg ? 'organization' : 'ngo',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (isOrg) {
        userData['totalDonations'] = 0;
      }

      if (_addressString != null) {
        userData['address'] = _addressString;
        userData['lat'] = _lat;
        userData['lng'] = _lng;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set(userData);

      await NotificationService().updateToken();

      if (mounted) {
        if (isOrg) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const Dashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NGODashboard()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Signup failed"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [Colors.green.shade800, Colors.green.shade500, Colors.green.shade200],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                            ),
                            const Text(
                              "Create Account",
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Form Card
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(50),
                              topRight: Radius.circular(50),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30.0,
                              vertical: 40,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── Role Selector ──
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => isOrg = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: isOrg ? Colors.green : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "Organization",
                                                style: TextStyle(
                                                  color: isOrg ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => isOrg = false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: !isOrg ? Colors.green : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                "NGO",
                                                style: TextStyle(
                                                  color: !isOrg ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 30),

                                // ── Name ──
                                _buildTextField(
                                  controller: nameCtrl,
                                  label: isOrg ? "Organization Name" : "NGO Name",
                                  icon: Icons.business,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),

                                // ── Email ──
                                _buildTextField(
                                  controller: emailCtrl,
                                  label: "Email Address",
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),

                                // ── Phone ──
                                _buildTextField(
                                  controller: phoneCtrl,
                                  label: "Phone Number",
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),

                                // ── Password ──
                                _buildTextField(
                                  controller: passCtrl,
                                  label: "Password",
                                  icon: Icons.lock_outline,
                                  isPassword: true,
                                  obscureText: _obscurePass,
                                  onSuffixTap: () => setState(() => _obscurePass = !_obscurePass),
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 16),

                                // ── Confirm Password ──
                                _buildTextField(
                                  controller: confirmCtrl,
                                  label: "Confirm Password",
                                  icon: Icons.lock_reset,
                                  isPassword: true,
                                  obscureText: _obscureConfirm,
                                  onSuffixTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 20),

                                // ── Location picker ──
                                const SizedBox(height: 4),
                                _buildLocationSection(isDark),
                                const SizedBox(height: 20),

                                const SizedBox(height: 20),

                                // ── Sign Up button ──
                                _isLoading
                                    ? const Center(child: CircularProgressIndicator())
                                    : Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(15),
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.green.shade700,
                                              Colors.green.shade400,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(0.3),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: signup,
                                            borderRadius: BorderRadius.circular(15),
                                            child: const Center(
                                              child: Text(
                                                "Sign Up",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Already have an account?", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.black87)),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "Login",
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    MyApp.of(context).toggleTheme();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // Location section widget
  // ────────────────────────────────────────────────
  Widget _buildLocationSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Location Address",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        // Detected address display box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: _addressString != null
                  ? Colors.green.shade300
                  : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on,
                color: _addressString != null
                    ? Colors.green.shade600
                    : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _addressString != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _addressString!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "📍 ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        "No location detected yet",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Detect / Refresh button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isDetectingLocation ? null : _detectLocation,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              side: BorderSide(color: Colors.green.shade400),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _isDetectingLocation
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.green.shade700,
                    ),
                  )
                : const Text("📍", style: TextStyle(fontSize: 16)),
            label: Text(
              _isDetectingLocation
                  ? "Detecting..."
                  : _addressString == null
                  ? "Detect Location"
                  : "Refresh Location",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────
  // Reusable text field
  // ────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
    TextInputType keyboardType = TextInputType.text,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.transparent),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
          prefixIcon: Icon(icon, color: Colors.green.shade600),
          suffixIcon: isPassword
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }
}
