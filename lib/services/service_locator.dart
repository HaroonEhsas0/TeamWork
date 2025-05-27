import 'package:get_it/get_it.dart';
import 'auth_service.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'location_service.dart';
import 'biometric_service.dart';
import '../database_helper.dart';

final GetIt locator = GetIt.instance;

void setupServiceLocator() {
  // Register services
  locator.registerLazySingleton<DatabaseHelper>(() => DatabaseHelper());
  locator.registerLazySingleton<AuthService>(() => AuthService());
  locator.registerLazySingleton<StorageService>(() => StorageService());
  locator.registerLazySingleton<NotificationService>(() => NotificationService());
  locator.registerLazySingleton<LocationService>(() => LocationService());
  locator.registerLazySingleton<BiometricService>(() => BiometricService());
}
