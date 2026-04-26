import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ngofood/widgets/sidebar_layout.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
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
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: const Color(0xFF16A34A),
          collapsedIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
          title: Text(
            question,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              answer,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SidebarLayout(
      title: "FAQ",
      activeMenu: "FAQ",
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            "Frequently Asked Questions",
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Find answers to common questions about using our platform.",
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
          
          _buildFAQItem(
            context,
            "How to donate food?",
            "If you represent a restaurant or organisation, simply navigate to the Dashboard and click 'Add New Food'. Fill out the food details, quantity, and urgency. Your donation will instantly be broadcasted to nearby NGOs.",
          ),
          _buildFAQItem(
            context,
            "How does pickup work?",
            "Once an NGO claims your food donation, you will receive a notification. The NGO will use the map to find your location and come for pickup. You can view ETA and coordinate through the app.",
          ),
          _buildFAQItem(
            context,
            "What are the food safety rules?",
            "All donated food must be prepared and stored according to standard health regulations. Do not donate food that has been left at room temperature for more than 4 hours. You can specify expiry times for sensitive items.",
          ),
          _buildFAQItem(
            context,
            "How do NGOs receive food?",
            "NGOs can see available food donations on their map within a 5km radius. They can browse details, check urgency, and click 'Claim' to secure a donation. Notifications are sent automatically to confirm.",
          ),
          _buildFAQItem(
            context,
            "Is there a limit to how much I can claim/donate?",
            "There are currently no strict limits on donations. However, NGOs should only claim what they can distribute before the food's expiry to avoid wastage.",
          ),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              "Still have questions?",
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () {
                // In actual flow, you'd navigate to Contact Us or switch Active Menu
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                foregroundColor: const Color(0xFF16A34A),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                "Contact Support",
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
