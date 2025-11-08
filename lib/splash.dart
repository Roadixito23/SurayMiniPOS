import 'package:flutter/material.dart';
import 'dart:async';
import 'responsive_helper.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 2), () {
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = ResponsiveHelper.getIconSize(context, 150);
    final titleFontSize = ResponsiveHelper.getResponsiveFontSize(context, 22);
    final footerFontSize = ResponsiveHelper.getResponsiveFontSize(context, 14);
    final poweredByFontSize = ResponsiveHelper.getResponsiveFontSize(context, 12);

    return Scaffold(
      backgroundColor: Colors.blue.shade700,
      body: Stack(
        children: [
          // Main content centered in the screen
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo centered in the middle of the screen
                Image.asset(
                  'assets/logocolorminipos.png',
                  width: logoSize,
                  height: logoSize,
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),
                // Title below logo
                Text(
                  'INICIANDO SISTEMA',
                  style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 12)),
                SizedBox(height: ResponsiveHelper.getResponsiveSpacing(context, 24)),
                CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),

          // Footer positioned at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: ResponsiveHelper.getResponsiveSpacing(context, 24),
            child: Column(
              children: [
                Text(
                  '© www.suray.cl',
                  style: TextStyle(
                    fontSize: footerFontSize,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'POWERED BY: RoadTech Studio',
                  style: TextStyle(
                    fontSize: poweredByFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}