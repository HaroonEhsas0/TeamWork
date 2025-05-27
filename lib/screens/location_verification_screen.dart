import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/geofence_provider.dart';
import '../providers/user_provider.dart';
import '../services/location_service.dart';
import '../services/service_locator.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class LocationVerificationScreen extends StatefulWidget {
  final bool isCheckIn;
  final Function(bool, String?) onVerificationComplete;
  
  const LocationVerificationScreen({
    Key? key,
    required this.isCheckIn,
    required this.onVerificationComplete,
  }) : super(key: key);

  @override
  _LocationVerificationScreenState createState() => _LocationVerificationScreenState();
}

class _LocationVerificationScreenState extends State<LocationVerificationScreen> {
  final LocationService _locationService = locator<LocationService>();
  
  bool _isLoading = true;
  bool _isLocationEnabled = false;
  bool _hasLocationPermission = false;
  bool _isWithinGeofence = false;
  String _statusMessage = 'Checking location services...';
  
  Position? _currentPosition;
  GoogleMapController? _mapController;
  Set<Circle> _geofenceCircles = {};
  
  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }
  
  Future<void> _checkLocationStatus() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking location services...';
    });
    
    try {
      // Check if location services are enabled
      final isEnabled = await _locationService.isLocationServiceEnabled();
      
      if (!isEnabled) {
        setState(() {
          _isLocationEnabled = false;
          _statusMessage = 'Location services are disabled. Please enable location services in your device settings.';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _isLocationEnabled = true;
        _statusMessage = 'Checking location permission...';
      });
      
      // Check location permission
      final permission = await _locationService.checkPermission();
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _hasLocationPermission = false;
          _statusMessage = permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Please enable it in app settings.'
              : 'Location permission denied. Please grant permission to verify your location.';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _hasLocationPermission = true;
        _statusMessage = 'Getting current location...';
      });
      
      // Get current location
      final position = await _locationService.getCurrentPosition();
      
      if (position == null) {
        setState(() {
          _statusMessage = 'Failed to get current location. Please try again.';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _currentPosition = position;
        _statusMessage = 'Checking if location is within allowed areas...';
      });
      
      // Check if within geofence
      await _checkGeofenceStatus();
      
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking location: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _checkGeofenceStatus() async {
    try {
      if (_currentPosition == null) {
        throw Exception('Current position is not available');
      }
      
      // Get current user's organization ID
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      final organizationId = currentUser.organizationId;
      final teamId = currentUser.teamId;
      
      if (organizationId == null) {
        throw Exception('User not associated with an organization');
      }
      
      // Load geofences
      final geofenceProvider = Provider.of<GeofenceProvider>(context, listen: false);
      await geofenceProvider.loadGeofences(organizationId);
      
      // Check if within any geofence
      final isWithin = await geofenceProvider.canUserCheckInAtCurrentLocation(
        currentUser.id,
        teamId,
      );
      
      // Get geofences for visualization
      final containingGeofences = geofenceProvider.getGeofencesContainingLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      
      // Create circles for all geofences
      _geofenceCircles = geofenceProvider.geofences.map((geofence) {
        final isUserInThisGeofence = containingGeofences.any((g) => g.id == geofence.id);
        
        return Circle(
          circleId: CircleId(geofence.id),
          center: LatLng(geofence.latitude, geofence.longitude),
          radius: geofence.radius,
          fillColor: isUserInThisGeofence
              ? Colors.green.withOpacity(0.3)
              : geofence.color.withOpacity(0.3),
          strokeColor: isUserInThisGeofence
              ? Colors.green
              : geofence.color,
          strokeWidth: 2,
        );
      }).toSet();
      
      setState(() {
        _isWithinGeofence = isWithin;
        _statusMessage = isWithin
            ? 'Location verified! You are within an allowed area.'
            : 'You are not within any allowed check-in areas.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error checking geofence: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting location permission...';
    });
    
    try {
      final permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        setState(() {
          _hasLocationPermission = false;
          _statusMessage = permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Please enable it in app settings.'
              : 'Location permission denied. Please grant permission to verify your location.';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _hasLocationPermission = true;
      });
      
      // Continue with location verification
      await _checkLocationStatus();
    } catch (e) {
      setState(() {
        _statusMessage = 'Error requesting location permission: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  void _completeVerification() {
    if (_currentPosition == null) {
      ErrorUtils.showErrorSnackBar(context, 'Current location not available');
      return;
    }
    
    final locationString = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    widget.onVerificationComplete(_isWithinGeofence, locationString);
    Navigator.of(context).pop();
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    
    if (_currentPosition != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isCheckIn ? 'Check-In Location' : 'Check-Out Location'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  if (!_isLocationEnabled)
                    _buildErrorState(
                      icon: Icons.location_off,
                      title: 'Location Services Disabled',
                      message: 'Please enable location services in your device settings to continue.',
                      buttonText: 'Open Settings',
                      onButtonPressed: () async {
                        await Geolocator.openLocationSettings();
                      },
                    )
                  else if (!_hasLocationPermission)
                    _buildErrorState(
                      icon: Icons.location_disabled,
                      title: 'Location Permission Required',
                      message: 'Please grant location permission to verify your location for attendance.',
                      buttonText: 'Grant Permission',
                      onButtonPressed: _requestLocationPermission,
                    )
                  else
                    Expanded(
                      child: Stack(
                        children: [
                          // Map
                          GoogleMap(
                            onMapCreated: _onMapCreated,
                            initialCameraPosition: CameraPosition(
                              target: _currentPosition != null
                                  ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                  : LatLng(0, 0), // Default position
                              zoom: 15,
                            ),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            mapToolbarEnabled: false,
                            circles: _geofenceCircles,
                            markers: _currentPosition != null
                                ? {
                                    Marker(
                                      markerId: MarkerId('current_location'),
                                      position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                      infoWindow: InfoWindow(
                                        title: 'Your Location',
                                      ),
                                    ),
                                  }
                                : {},
                          ),
                          
                          // Status overlay
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: _isWithinGeofence
                                                ? Colors.green.shade100
                                                : Colors.red.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _isWithinGeofence
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: _isWithinGeofence
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _isWithinGeofence
                                                    ? 'Location Verified'
                                                    : 'Outside Check-in Area',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                _isWithinGeofence
                                                    ? 'You are within an allowed check-in area'
                                                    : 'You must be within a designated area to check in',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_currentPosition != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12.0),
                                        child: Text(
                                          'Current coordinates: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Legend
                          Positioned(
                            bottom: 100,
                            right: 16,
                            child: Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Legend:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.3),
                                            border: Border.all(
                                              color: Colors.green,
                                              width: 2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'You are here',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.3),
                                            border: Border.all(
                                              color: Colors.blue,
                                              width: 2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Allowed areas',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Bottom action bar
                  if (_hasLocationPermission && _isLocationEnabled)
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade200,
                                foregroundColor: Colors.black,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text('Cancel'),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isWithinGeofence ? _completeVerification : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.blue.shade200,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(widget.isCheckIn ? 'Check In' : 'Check Out'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildErrorState({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onButtonPressed,
  }) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 80,
                color: Colors.red.shade300,
              ),
              SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: onButtonPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
