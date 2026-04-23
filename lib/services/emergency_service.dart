import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyService {
  static Future<void> sendLiveLocation(BuildContext context) async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Acquiring live GPS coordinates...', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF2B1B4A),
        duration: Duration(seconds: 3),
      ),
    );

    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      // 2. Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      // 3. Get accurate current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      );

      // 4. Construct SMS message
      final String mapUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final String message = 'EMERGENCY: I need immediate medical help. My live GPS location is: $mapUrl';
      
      // Target contacts (These would come from User's profile in real app)
      const String contactsStr = '15551234567,15559876543,15555555555';
      
      // Construct the SMS URI (handles iOS vs Android differences)
      final String separator = Platform.isIOS ? '&' : '?';
      final Uri smsUri = Uri.parse('sms:$contactsStr${separator}body=${Uri.encodeComponent(message)}');
      
      // 5. Open SMS App
      // Always launch it via url_launcher to delegate to OS standard SMS messenger
      await launchUrl(smsUri);
      
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send location: ${e.toString()}'),
            backgroundColor: const Color(0xFFFF4949),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  static Future<void> dialNumber(BuildContext context, String phoneNumber) async {
    // Strip everything except plus and digits just in case
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri telUri = Uri.parse('tel:$cleanNumber');
    
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        throw Exception('Could not launch phone app.');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot dial $phoneNumber - ${e.toString()}'),
            backgroundColor: const Color(0xFFFF4949),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
