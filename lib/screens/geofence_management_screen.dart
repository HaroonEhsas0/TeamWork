import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/geofence_model.dart';
import '../providers/geofence_provider.dart';
import '../providers/team_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class GeofenceManagementScreen extends StatefulWidget {
  const GeofenceManagementScreen({Key? key}) : super(key: key);

  @override
  _GeofenceManagementScreenState createState() => _GeofenceManagementScreenState();
}

class _GeofenceManagementScreenState extends State<GeofenceManagementScreen> {
  bool _isLoading = true;
  String? _organizationId;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  GoogleMapController? _mapController;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current user's organization ID
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not logged in');
      }
      
      _organizationId = currentUser.organizationId;
      
      if (_organizationId == null) {
        throw Exception('User not associated with an organization');
      }
      
      // Load geofences
      final geofenceProvider = Provider.of<GeofenceProvider>(context, listen: false);
      await geofenceProvider.loadGeofences(_organizationId!);
      
      // Update map markers and circles
      _updateMapOverlays(geofenceProvider.geofences);
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading geofences: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _updateMapOverlays(List<GeofenceModel> geofences) {
    _markers = {};
    _circles = {};
    
    for (final geofence in geofences) {
      // Add marker
      _markers.add(
        Marker(
          markerId: MarkerId(geofence.id),
          position: LatLng(geofence.latitude, geofence.longitude),
          infoWindow: InfoWindow(
            title: geofence.name,
            snippet: geofence.address ?? 'Radius: ${geofence.radius.toInt()} meters',
          ),
          onTap: () => _showGeofenceOptions(geofence),
        ),
      );
      
      // Add circle
      _circles.add(
        Circle(
          circleId: CircleId(geofence.id),
          center: LatLng(geofence.latitude, geofence.longitude),
          radius: geofence.radius,
          fillColor: geofence.color.withOpacity(0.3),
          strokeColor: geofence.color,
          strokeWidth: 2,
        ),
      );
    }
    
    setState(() {});
  }
  
  void _showAddGeofenceDialog() {
    if (_organizationId == null) {
      ErrorUtils.showErrorSnackBar(context, 'Organization ID not found');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => GeofenceFormDialog(
        organizationId: _organizationId!,
        onSave: () {
          // Refresh the geofences
          final geofenceProvider = Provider.of<GeofenceProvider>(context, listen: false);
          geofenceProvider.loadGeofences(_organizationId!).then((_) {
            _updateMapOverlays(geofenceProvider.geofences);
          });
        },
      ),
    );
  }
  
  void _showGeofenceOptions(GeofenceModel geofence) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              geofence.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            subtitle: Text(geofence.address ?? 'No address'),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit Geofence'),
            onTap: () {
              Navigator.pop(context);
              _showEditGeofenceDialog(geofence);
            },
          ),
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red),
            title: Text('Delete Geofence', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteGeofenceConfirmation(geofence);
            },
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  void _showEditGeofenceDialog(GeofenceModel geofence) {
    if (_organizationId == null) {
      ErrorUtils.showErrorSnackBar(context, 'Organization ID not found');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => GeofenceFormDialog(
        organizationId: _organizationId!,
        geofence: geofence,
        onSave: () {
          // Refresh the geofences
          final geofenceProvider = Provider.of<GeofenceProvider>(context, listen: false);
          geofenceProvider.loadGeofences(_organizationId!).then((_) {
            _updateMapOverlays(geofenceProvider.geofences);
          });
        },
      ),
    );
  }
  
  Future<void> _showDeleteGeofenceConfirmation(GeofenceModel geofence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Geofence'),
        content: Text('Are you sure you want to delete the geofence "${geofence.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || _organizationId == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final geofenceProvider = Provider.of<GeofenceProvider>(context, listen: false);
      final success = await geofenceProvider.deleteGeofence(geofence.id);
      
      if (success) {
        ErrorUtils.showSuccessSnackBar(context, 'Geofence deleted successfully');
        _updateMapOverlays(geofenceProvider.geofences);
      } else {
        ErrorUtils.showErrorSnackBar(context, 'Failed to delete geofence');
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error deleting geofence: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Geofence Management'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Consumer<GeofenceProvider>(
                builder: (context, geofenceProvider, _) {
                  return Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(37.7749, -122.4194), // Default to San Francisco
                          zoom: 12,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        markers: _markers,
                        circles: _circles,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _centerMapOnCurrentLocation();
                        },
                      ),
                      if (geofenceProvider.geofences.isEmpty)
                        Center(
                          child: Card(
                            margin: EdgeInsets.all(16),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_off,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No geofences found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add geofences to restrict attendance check-ins to specific locations',
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _showAddGeofenceDialog,
                                    icon: Icon(Icons.add),
                                    label: Text('Add Geofence'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade700,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddGeofenceDialog,
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          child: Icon(Icons.add_location_alt),
          tooltip: 'Add Geofence',
        ),
      ),
    );
  }
  
  Future<void> _centerMapOnCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          15,
        ),
      );
    } catch (e) {
      print('Error centering map on current location: $e');
    }
  }
}

class GeofenceFormDialog extends StatefulWidget {
  final String organizationId;
  final GeofenceModel? geofence;
  final VoidCallback onSave;
  
  const GeofenceFormDialog({
    Key? key,
    required this.organizationId,
    this.geofence,
    required this.onSave,
  }) : super(key: key);

  @override
  _GeofenceFormDialogState createState() => _GeofenceFormDialogState();
}

class _GeofenceFormDialogState extends State<GeofenceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _radiusController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  double _latitude = 0.0;
  double _longitude = 0.0;
  List<String> _selectedTeamIds = [];
  Color _selectedColor = Colors.blue;
  
  bool _isLoading = false;
  bool _isSearchingLocation = false;
  
  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];
  
  @override
  void initState() {
    super.initState();
    
    // If editing an existing geofence, populate the form
    if (widget.geofence != null) {
      _nameController.text = widget.geofence!.name;
      _radiusController.text = widget.geofence!.radius.toString();
      _latitude = widget.geofence!.latitude;
      _longitude = widget.geofence!.longitude;
      _selectedTeamIds = widget.geofence!.teamIds ?? [];
      _selectedColor = widget.geofence!.color;
      
      if (widget.geofence!.address != null) {
        _addressController.text = widget.geofence!.address!;
      }
      
      if (widget.geofence!.description != null) {
        _descriptionController.text = widget.geofence!.description!;
      }
    } else {
      // Default radius of 100 meters
      _radiusController.text = '100';
      
      // Get current location
      _getCurrentLocation();
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      
      // Get address for the location
      await _getAddressFromCoordinates();
    } catch (e) {
      print('Error getting current location: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _getAddressFromCoordinates() async {
    setState(() {
      _isSearchingLocation = true;
    });
    
    try {
      final placemarks = await placemarkFromCoordinates(_latitude, _longitude);
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.postalCode,
          placemark.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');
        
        setState(() {
          _addressController.text = address;
        });
      }
    } catch (e) {
      print('Error getting address from coordinates: $e');
    } finally {
      setState(() {
        _isSearchingLocation = false;
      });
    }
  }
  
  Future<void> _getCoordinatesFromAddress() async {
    if (_addressController.text.trim().isEmpty) return;
    
    setState(() {
      _isSearchingLocation = true;
    });
    
    try {
      final locations = await locationFromAddress(_addressController.text);
      
      if (locations.isNotEmpty) {
        setState(() {
          _latitude = locations.first.latitude;
          _longitude = locations.first.longitude;
        });
      }
    } catch (e) {
      print('Error getting coordinates from address: $e');
      ErrorUtils.showErrorSnackBar(context, 'Could not find location. Please try a different address.');
    } finally {
      setState(() {
        _isSearchingLocation = false;
      });
    }
  }
  
  Future<void> _saveGeofence() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final geofenceProvider = Provider.of<GeofenceProvider>(context, listen: false);
      
      final now = DateTime.now();
      final radius = double.parse(_radiusController.text);
      
      if (widget.geofence == null) {
        // Create new geofence
        final newGeofence = GeofenceModel(
          id: '', // Will be generated by Firestore
          name: _nameController.text,
          latitude: _latitude,
          longitude: _longitude,
          radius: radius,
          organizationId: widget.organizationId,
          teamIds: _selectedTeamIds.isEmpty ? null : _selectedTeamIds,
          createdBy: '', // Will be set by the provider
          createdAt: now,
          color: _selectedColor,
          address: _addressController.text.isNotEmpty ? _addressController.text : null,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        );
        
        final success = await geofenceProvider.createGeofence(newGeofence);
        
        if (success) {
          Navigator.of(context).pop();
          widget.onSave();
          ErrorUtils.showSuccessSnackBar(context, 'Geofence created successfully');
        } else {
          ErrorUtils.showErrorSnackBar(context, 'Failed to create geofence');
        }
      } else {
        // Update existing geofence
        final updatedGeofence = widget.geofence!.copyWith(
          name: _nameController.text,
          latitude: _latitude,
          longitude: _longitude,
          radius: radius,
          teamIds: _selectedTeamIds.isEmpty ? null : _selectedTeamIds,
          updatedAt: now,
          color: _selectedColor,
          address: _addressController.text.isNotEmpty ? _addressController.text : null,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        );
        
        final success = await geofenceProvider.updateGeofence(updatedGeofence);
        
        if (success) {
          Navigator.of(context).pop();
          widget.onSave();
          ErrorUtils.showSuccessSnackBar(context, 'Geofence updated successfully');
        } else {
          ErrorUtils.showErrorSnackBar(context, 'Failed to update geofence');
        }
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error saving geofence: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.geofence == null ? 'Add Geofence' : 'Edit Geofence'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Geofence Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                  suffixIcon: _isSearchingLocation
                      ? Container(
                          height: 20,
                          width: 20,
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: Icon(Icons.search),
                          onPressed: _getCoordinatesFromAddress,
                          tooltip: 'Search Address',
                        ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: _latitude.toString()),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(text: _longitude.toString()),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _radiusController,
                decoration: InputDecoration(
                  labelText: 'Radius (meters)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a radius';
                  }
                  try {
                    final radius = double.parse(value);
                    if (radius <= 0) {
                      return 'Radius must be greater than 0';
                    }
                  } catch (e) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 16),
              Text(
                'Geofence Color',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _colorOptions.map((color) {
                  final isSelected = _selectedColor.value == color.value;
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              Text(
                'Applicable Teams (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Consumer<TeamProvider>(
                builder: (context, teamProvider, _) {
                  if (teamProvider.isLoading) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  if (teamProvider.teams.isEmpty) {
                    return Text('No teams available');
                  }
                  
                  return Wrap(
                    spacing: 8,
                    children: teamProvider.teams.map((team) {
                      final isSelected = _selectedTeamIds.contains(team.id);
                      
                      return FilterChip(
                        label: Text(team.name),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTeamIds.add(team.id);
                            } else {
                              _selectedTeamIds.remove(team.id);
                            }
                          });
                        },
                        selectedColor: Colors.blue.shade100,
                        checkmarkColor: Colors.blue.shade700,
                      );
                    }).toList(),
                  );
                },
              ),
              SizedBox(height: 8),
              Text(
                'If no teams are selected, this geofence will apply to all teams in the organization.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveGeofence,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(widget.geofence == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
