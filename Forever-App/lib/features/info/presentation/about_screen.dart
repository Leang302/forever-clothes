import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import 'info_page.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget value(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: const TextStyle(
                      color: AppColors.muted,
                      height: 1.45,
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
      title: 'About Forever',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.asset('assets/images/about_img.png', fit: BoxFit.cover),
        ),
        const SizedBox(height: 22),
        const Text(
          'We are passionate about delivering high-quality fashion and exceptional service. Our team is committed to building lasting relationships with our customers, and your satisfaction is at the heart of everything we do.',
          style: TextStyle(height: 1.55, fontSize: 15.5),
        ),
        const SizedBox(height: 14),
        const Text(
          'Our mission is to empower our customers with reliable, innovative products that make a positive impact.',
          style: TextStyle(
            height: 1.55,
            fontSize: 15.5,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 28),
        Text('Why choose us', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        value(
          Icons.verified_outlined,
          'Quality assurance',
          'Rigorous checks make sure every product meets the highest standard.',
        ),
        value(
          Icons.bolt_rounded,
          'Convenience',
          'A streamlined experience that saves you time and effort.',
        ),
        value(
          Icons.support_agent_rounded,
          'Customer service',
          'A friendly, responsive team that is here to help at every step.',
        ),
      ],
    );
  }
}
