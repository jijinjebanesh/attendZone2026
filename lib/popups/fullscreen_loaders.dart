import 'package:attendzone_new/constants/image_strings.dart';
import 'package:attendzone_new/popups/loaders.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../helper_functions.dart';

/// A utility class for managing a full-screen loading dialog.
class EFullScreenLoader {
  static bool _isDialogOpen = false;

  /// Open a full-screen loading dialog with a given text and animation.
  static void openLoadingDialog(String text, BuildContext context) {
    // Prevent multiple dialogs from being opened
    if (_isDialogOpen) {
      return;
    }

    _isDialogOpen = true;

    // Use Future.microtask to ensure this runs after the current build phase
    Future.microtask(() {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => PopScope(
            canPop: false,
            child: Container(
              color: EHelperFunctions.isDarkMode(context)
                  ? Colors.black
                  : Colors.white,
              width: double.infinity,
              height: double.infinity,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EAnimationLoaderWidget(
                      text: text,
                      image: EHelperFunctions.isDarkMode(context)
                          ? EImages.darkLoadingAppLogo
                          : EImages.lightLoadingAppLogo,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).then((_) {
          _isDialogOpen = false;
        });
      } catch (e) {
        _isDialogOpen = false;
        debugPrint('Error opening loading dialog: $e');
      }
    });
  }

  static void stopLoading(BuildContext context) {
    try {
      if (_isDialogOpen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
        _isDialogOpen = false;
      }
    } catch (e) {
      debugPrint('Error stopping loading dialog: $e');
    }
  }
}
