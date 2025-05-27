import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/shift_model.dart';
import '../providers/shift_provider.dart';
import '../providers/team_provider.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({Key? key}) : super(key: key);

  @override
  _ShiftManagementScreenState createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  bool _isLoading = true;
  String? _selectedTeamId;
  
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
      // Load teams
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      await teamProvider.loadTeams();
      
      if (teamProvider.teams.isNotEmpty && _selectedTeamId == null) {
        _selectedTeamId = teamProvider.teams.first.id;
        
        // Load shifts for the selected team's organization
        final team = teamProvider.teams.first;
        if (team.organizationId != null) {
          final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
          await shiftProvider.loadShifts(team.organizationId!);
        }
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading data: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _onTeamChanged(String? teamId) async {
    if (teamId == null) return;
    
    setState(() {
      _selectedTeamId = teamId;
      _isLoading = true;
    });
    
    try {
      // Get the selected team
      final teamProvider = Provider.of<TeamProvider>(context, listen: false);
      final team = teamProvider.getTeamById(teamId);
      
      // Load shifts for the team's organization
      if (team != null && team.organizationId != null) {
        final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
        await shiftProvider.loadShifts(team.organizationId!);
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading shifts: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showAddShiftDialog() {
    // Get the selected team's organization ID
    final teamProvider = Provider.of<TeamProvider>(context, listen: false);
    final team = teamProvider.getTeamById(_selectedTeamId!);
    
    if (team == null || team.organizationId == null) {
      ErrorUtils.showErrorSnackBar(context, 'No organization found for the selected team');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => ShiftFormDialog(
        organizationId: team.organizationId!,
        onSave: () {
          // Refresh the shifts list
          final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
          shiftProvider.loadShifts(team.organizationId!);
        },
      ),
    );
  }
  
  void _showEditShiftDialog(ShiftModel shift) {
    showDialog(
      context: context,
      builder: (context) => ShiftFormDialog(
        organizationId: shift.organizationId,
        shift: shift,
        onSave: () {
          // Refresh the shifts list
          final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
          shiftProvider.loadShifts(shift.organizationId);
        },
      ),
    );
  }
  
  Future<void> _deleteShift(ShiftModel shift) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Shift'),
        content: Text('Are you sure you want to delete the shift "${shift.name}"? This action cannot be undone.'),
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
    
    if (confirmed != true) return;
    
    // Delete the shift
    setState(() {
      _isLoading = true;
    });
    
    try {
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      final success = await shiftProvider.deleteShift(shift.id);
      
      if (success) {
        ErrorUtils.showSuccessSnackBar(context, 'Shift deleted successfully');
      } else {
        ErrorUtils.showErrorSnackBar(context, 'Failed to delete shift');
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error deleting shift: ${ErrorUtils.formatErrorMessage(e)}');
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
          title: Text('Shift Management'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Team selector
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Consumer<TeamProvider>(
                      builder: (context, teamProvider, _) {
                        return DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Select Team',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          value: _selectedTeamId,
                          items: teamProvider.teams.map((team) {
                            return DropdownMenuItem<String>(
                              value: team.id,
                              child: Text(team.name),
                            );
                          }).toList(),
                          onChanged: _onTeamChanged,
                        );
                      },
                    ),
                  ),
                  
                  // Shifts list
                  Expanded(
                    child: Consumer<ShiftProvider>(
                      builder: (context, shiftProvider, _) {
                        if (shiftProvider.isLoading) {
                          return Center(child: CircularProgressIndicator());
                        }
                        
                        if (shiftProvider.shifts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No shifts found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _showAddShiftDialog,
                                  icon: Icon(Icons.add),
                                  label: Text('Add Shift'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade700,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: shiftProvider.shifts.length,
                          itemBuilder: (context, index) {
                            final shift = shiftProvider.shifts[index];
                            return _buildShiftCard(shift);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddShiftDialog,
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          child: Icon(Icons.add),
          tooltip: 'Add Shift',
        ),
      ),
    );
  }
  
  Widget _buildShiftCard(ShiftModel shift) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showEditShiftDialog(shift),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: shift.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shift.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, size: 20),
                    onPressed: () => _showEditShiftDialog(shift),
                    tooltip: 'Edit Shift',
                  ),
                  IconButton(
                    icon: Icon(Icons.delete, size: 20),
                    onPressed: () => _deleteShift(shift),
                    tooltip: 'Delete Shift',
                    color: Colors.red.shade700,
                  ),
                ],
              ),
              if (shift.description != null && shift.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    shift.description!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.access_time,
                      label: 'Time',
                      value: '${shift.formattedStartTime} - ${shift.formattedEndTime}',
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.timer,
                      label: 'Duration',
                      value: '${shift.durationInHours.toStringAsFixed(1)} hours',
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildInfoItem(
                icon: Icons.calendar_today,
                label: 'Work Days',
                value: shift.formattedWorkDays,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ShiftFormDialog extends StatefulWidget {
  final String organizationId;
  final ShiftModel? shift;
  final VoidCallback onSave;
  
  const ShiftFormDialog({
    Key? key,
    required this.organizationId,
    this.shift,
    required this.onSave,
  }) : super(key: key);

  @override
  _ShiftFormDialogState createState() => _ShiftFormDialogState();
}

class _ShiftFormDialogState extends State<ShiftFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 17, minute: 0);
  List<String> _selectedDays = ['1', '2', '3', '4', '5']; // Mon-Fri
  Color _selectedColor = Colors.blue;
  
  bool _isLoading = false;
  
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
  
  final Map<String, String> _dayNames = {
    '1': 'Monday',
    '2': 'Tuesday',
    '3': 'Wednesday',
    '4': 'Thursday',
    '5': 'Friday',
    '6': 'Saturday',
    '7': 'Sunday',
  };
  
  @override
  void initState() {
    super.initState();
    
    // If editing an existing shift, populate the form
    if (widget.shift != null) {
      _nameController.text = widget.shift!.name;
      _descriptionController.text = widget.shift!.description ?? '';
      _startTime = widget.shift!.startTime;
      _endTime = widget.shift!.endTime;
      _selectedDays = widget.shift!.workDays;
      _selectedColor = widget.shift!.color;
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }
  
  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
    }
  }
  
  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }
  
  Future<void> _saveShift() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
      
      final now = DateTime.now();
      
      if (widget.shift == null) {
        // Create new shift
        final newShift = ShiftModel(
          id: '', // Will be generated by Firestore
          name: _nameController.text,
          startTime: _startTime,
          endTime: _endTime,
          workDays: _selectedDays,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          organizationId: widget.organizationId,
          createdBy: '', // Will be set by the provider
          createdAt: now,
          color: _selectedColor,
        );
        
        final success = await shiftProvider.createShift(newShift);
        
        if (success) {
          Navigator.of(context).pop();
          widget.onSave();
          ErrorUtils.showSuccessSnackBar(context, 'Shift created successfully');
        } else {
          ErrorUtils.showErrorSnackBar(context, 'Failed to create shift');
        }
      } else {
        // Update existing shift
        final updatedShift = widget.shift!.copyWith(
          name: _nameController.text,
          startTime: _startTime,
          endTime: _endTime,
          workDays: _selectedDays,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          updatedAt: now,
          color: _selectedColor,
        );
        
        final success = await shiftProvider.updateShift(updatedShift);
        
        if (success) {
          Navigator.of(context).pop();
          widget.onSave();
          ErrorUtils.showSuccessSnackBar(context, 'Shift updated successfully');
        } else {
          ErrorUtils.showErrorSnackBar(context, 'Failed to update shift');
        }
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error saving shift: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.shift == null ? 'Add Shift' : 'Edit Shift'),
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
                  labelText: 'Shift Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a shift name';
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
                'Shift Times',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectStartTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start Time',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectEndTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'End Time',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                'Work Days',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _dayNames.entries.map((entry) {
                  final day = entry.key;
                  final name = entry.value;
                  final isSelected = _selectedDays.contains(day);
                  
                  return FilterChip(
                    label: Text(name.substring(0, 3)),
                    selected: isSelected,
                    onSelected: (_) => _toggleDay(day),
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade700,
                  );
                }).toList(),
              ),
              SizedBox(height: 16),
              Text(
                'Shift Color',
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
          onPressed: _isLoading ? null : _saveShift,
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
              : Text(widget.shift == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}
