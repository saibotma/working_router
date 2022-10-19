import 'package:flutter/foundation.dart';

bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

bool get isMacOs => defaultTargetPlatform == TargetPlatform.macOS;

bool get isDesktop => !isAndroid && !isIos;

bool get isApple => isIos || isMacOs;

bool get isMobile => isAndroid || isIos;
