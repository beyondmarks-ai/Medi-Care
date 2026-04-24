import 'package:flutter/material.dart';
import 'package:medicare_ai/services/emergency_service.dart';
import 'package:medicare_ai/theme/portal_extension.dart';

const _dangerLight = Color(0xFFFF8B8B);
const _danger = Color(0xFFFF4949);
const _success = Color(0xFF58B95E);

/// Reusable bottom SOS bar; adapts to light / dark theme.
class EmergencyDock extends StatelessWidget {
  const EmergencyDock({super.key});

  @override
  Widget build(BuildContext context) {
    final px = context.portalX;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: px.dock,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: px.dock.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _showSosModal(context),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_dangerLight, _danger],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: _danger.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.medical_services_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'SOS Connect',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                _darkDockIcon(context, Icons.call_rounded, () {
                  _showEmergencyContactsModal(context);
                }),
                const SizedBox(width: 8),
                _darkDockIcon(context, Icons.location_on_rounded, () {
                  EmergencyService.sendLiveLocation(context);
                }),
                const SizedBox(width: 8),
                _darkDockIcon(context, Icons.support_agent_rounded, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Opening 24/7 Medical Support Chat...'),
                      backgroundColor: px.dock,
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _darkDockIcon(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    final o = context.portalX.onDockIcon;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.transparent,
        child: Icon(icon, color: o, size: 26),
      ),
    );
  }

  static void _showEmergencyContactsModal(BuildContext context) {
    final cs = context.medicareColorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 5,
              width: 44,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Call Emergency Contact',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a trusted contact from your network to ring immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _contactCard(context, 'Mother', '+91 98765 43210'),
            const SizedBox(height: 12),
            _contactCard(context, 'Husband', '+91 87654 32109'),
            const SizedBox(height: 12),
            _contactCard(context, 'Brother', '+91 76543 21098'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static Widget _contactCard(
      BuildContext context, String relation, String phone) {
    final cs = context.medicareColorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        EmergencyService.dialNumber(context, phone);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: cs.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    relation,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call, color: _success, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  static void _showSosModal(BuildContext context) {
    final cs = context.medicareColorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: _danger.withValues(alpha: 0.2),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_outlined,
                color: _danger,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Ambulance SOS',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You are about to contact the nearest ambulance dispatch and hospital emergency unit.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                EmergencyService.dialNumber(context, '108');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_dangerLight, _danger],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: _danger.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Dial Ambulance Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel Alarm',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
