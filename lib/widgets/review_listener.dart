import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ngofood/widgets/review_dialog.dart';

class ReviewListener extends StatefulWidget {
  final Widget child;
  final bool isNGO;

  const ReviewListener({
    super.key,
    required this.child,
    required this.isNGO,
  });

  @override
  State<ReviewListener> createState() => _ReviewListenerState();
}

class _ReviewListenerState extends State<ReviewListener> {
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      var doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _currentUserName = doc.data()?['name'] ?? "User";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) return widget.child;

    return Stack(
      children: [
        widget.child,
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('donations_history')
              .where(widget.isNGO ? 'ngoId' : 'orgId', isEqualTo: _currentUserId)
              .where(widget.isNGO ? 'ngoReviewPending' : 'orgReviewPending', isEqualTo: true)
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  var doc = snapshot.data!.docs.first;
                  var data = doc.data() as Map<String, dynamic>;
                  
                  // Avoid showing if dialog is already open
                  if (ModalRoute.of(context)?.isCurrent == true) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => ReviewDialog(
                        targetId: widget.isNGO ? (data['orgId'] as String? ?? '') : (data['ngoId'] as String? ?? ''),
                        targetName: widget.isNGO ? (data['orgName'] as String? ?? "Organisation") : (data['ngoName'] as String? ?? "NGO"),
                        foodId: doc.id,
                        isReviewingNgo: !widget.isNGO,
                        reviewerId: _currentUserId!,
                        reviewerName: _currentUserName ?? "User",
                        reviewerRole: widget.isNGO ? 'ngo' : 'organization',
                      ),
                    );
                  }
                }
              });
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
