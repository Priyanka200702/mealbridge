import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewDialog extends StatefulWidget {
  final String targetId;
  final String targetName;
  final String foodId;
  final bool isReviewingNgo;
  final String reviewerId;
  final String reviewerName;

  const ReviewDialog({
    super.key,
    required this.targetId,
    required this.targetName,
    required this.foodId,
    required this.isReviewingNgo,
    required this.reviewerId,
    required this.reviewerName,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  void _submitReview() async {
    setState(() => _isSubmitting = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Create the review document in the target user's subcollection
      DocumentReference reviewRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetId)
          .collection('reviews')
          .doc(widget.foodId);
      
      batch.set(reviewRef, {
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'reviewerId': widget.reviewerId,
        'reviewerName': widget.reviewerName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update the target user's aggregated ratings
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(widget.targetId);
      batch.update(userRef, {
        'ratingCount': FieldValue.increment(1),
        'totalRating': FieldValue.increment(_rating),
      });

      // 3. Clear the pending flag on the donation history
      DocumentReference historyRef = FirebaseFirestore.instance.collection('donations_history').doc(widget.foodId);
      if (widget.isReviewingNgo) {
        batch.update(historyRef, {'orgReviewPending': false});
      } else {
        batch.update(historyRef, {'ngoReviewPending': false});
      }

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Review submitted successfully!"),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error submitting review: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _skipReview() async {
    setState(() => _isSubmitting = true);
    try {
      // Clear the pending flag without leaving a review
      DocumentReference historyRef = FirebaseFirestore.instance.collection('donations_history').doc(widget.foodId);
      if (widget.isReviewingNgo) {
        await historyRef.update({'orgReviewPending': false});
      } else {
        await historyRef.update({'ngoReviewPending': false});
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star, size: 40, color: Colors.green.shade600),
            ),
            const SizedBox(height: 20),
            Text(
              "Delivery Completed!",
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Rate your experience with ${widget.targetName}",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    size: 36,
                    color: Colors.amber.shade500,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: "Leave a review (optional)",
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green.shade500),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : _skipReview,
                    child: Text("Skip", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Submit", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
