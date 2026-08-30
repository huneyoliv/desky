import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../constants/app_constants.dart';

typedef _GetCurrentPackageFamilyNameC = Int32 Function(
  Pointer<Uint32> packageFamilyNameLength,
  Pointer<Utf16> packageFamilyName,
);
typedef _GetCurrentPackageFamilyNameDart = int Function(
  Pointer<Uint32> packageFamilyNameLength,
  Pointer<Utf16> packageFamilyName,
);

class PackageHelper {
  PackageHelper._();

  static bool? isStoreOrMsixOverride;

  /// Returns true if the application is running packaged in a Windows Store / MSIX container
  /// or if the in-app updater is disabled at compile time.
  static bool get isStoreOrMsix {
    if (isStoreOrMsixOverride != null) {
      return isStoreOrMsixOverride!;
    }

    // If disabled at compile-time (e.g. via --dart-define=ENABLE_IN_APP_UPDATER=false),
    // always treat as Store/packaged environment.
    if (!AppConstants.enableInAppUpdater) {
      return true;
    }

    if (!Platform.isWindows) return false;

    // Check Windows Win32 Kernel Package API
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final getPkgFamilyName = kernel32.lookupFunction<
          _GetCurrentPackageFamilyNameC,
          _GetCurrentPackageFamilyNameDart>('GetCurrentPackageFamilyName');
      final lengthPtr = calloc<Uint32>();
      lengthPtr.value = 0;
      final result = getPkgFamilyName(lengthPtr, nullptr);
      calloc.free(lengthPtr);

      // APPMODEL_ERROR_NO_PACKAGE = 15700 (0x3D54)
      // ERROR_SUCCESS = 0
      // ERROR_INSUFFICIENT_BUFFER = 122 (0x7A)
      if (result != 15700) {
        return true;
      }
    } catch (_) {}

    // Fallback heuristic checks
    try {
      final exe = Platform.resolvedExecutable.toLowerCase();
      if (exe.contains('windowsapps') ||
          Platform.environment.containsKey('APPX_PACKAGE_NAME') ||
          Platform.environment.containsKey('PACKAGE_FAMILY_NAME')) {
        return true;
      }
    } catch (_) {}

    return false;
  }
}
