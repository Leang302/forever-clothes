import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snackbar.dart';
import 'info_page.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return InfoPage(
      title: 'Contact us',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset(
            'assets/images/contact_img.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 22),
        row(
          Icons.storefront_outlined,
          'Our store',
          'Phnom Penh, Bak Tuk, Cambodia',
        ),
        row(Icons.call_outlined, 'Phone', '+855 12 122 391'),
        row(Icons.mail_outline_rounded, 'Email', 'admin@forever.com'),
        const SizedBox(height: 12),
        Text(
          'Careers at Forever',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        const Text(
          'Learn more about our team and openings.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => AppSnackbar.info(context, 'No openings right now'),
          child: const Text('Explore jobs'),
        ),
      ],
    );
  }
}
