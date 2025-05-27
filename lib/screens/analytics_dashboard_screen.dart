import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../database_helper.dart';
import '../providers/attendance_provider.dart';
import '../providers/team_provider.dart';
import '../utils/date_time_utils.dart';
import '../utils/error_utils.dart';
import '../widgets/connection_check_wrapper.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({Key? key}) : super(key: key);

  @override
  _AnalyticsDashboardScreenState createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late TabController _tabController;
  bool _isLoading = true;
  
  // Analytics data
  Map<String, dynamic> _attendanceStats = {};
  List<Map<String, dynamic>> _weeklyData = [];
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _teamPerformance = [];
  
  // Filter options
  String? _selectedTeamId;
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      }
      
      // Load attendance data
      await _loadAttendanceData();
      
      // Calculate weekly and monthly trends
      await _calculateTrends();
      
      // Calculate team performance
      if (_selectedTeamId != null) {
        await _calculateTeamPerformance();
      }
    } catch (e) {
      ErrorUtils.showErrorSnackBar(context, 'Error loading analytics data: ${ErrorUtils.formatErrorMessage(e)}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _loadAttendanceData() async {
    // Implementation will load attendance data from database
    // and calculate statistics
  }
  
  Future<void> _calculateTrends() async {
    // Implementation will calculate weekly and monthly trends
  }
  
  Future<void> _calculateTeamPerformance() async {
    // Implementation will calculate team performance metrics
  }
  
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      
      await _loadData();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ConnectionCheckWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: Text('Analytics Dashboard'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: _selectDateRange,
              tooltip: 'Select Date Range',
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh Data',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Trends'),
              Tab(text: 'Team Performance'),
            ],
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTrendsTab(),
                  _buildTeamPerformanceTab(),
                ],
              ),
      ),
    );
  }
  
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildSummaryCards(),
          
          SizedBox(height: 24),
          
          // Attendance distribution chart
          _buildAttendanceDistributionChart(),
          
          SizedBox(height: 24),
          
          // Working hours chart
          _buildWorkingHoursChart(),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCards() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          title: 'Attendance Rate',
          value: '${(_attendanceStats['attendanceRate'] ?? 0.0).toStringAsFixed(1)}%',
          icon: Icons.people,
          color: Colors.blue,
        ),
        _buildSummaryCard(
          title: 'Avg. Working Hours',
          value: '${(_attendanceStats['avgWorkingHours'] ?? 0.0).toStringAsFixed(1)}h',
          icon: Icons.access_time,
          color: Colors.green,
        ),
        _buildSummaryCard(
          title: 'Punctuality Rate',
          value: '${(_attendanceStats['punctualityRate'] ?? 0.0).toStringAsFixed(1)}%',
          icon: Icons.timer,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          title: 'Completion Rate',
          value: '${(_attendanceStats['completionRate'] ?? 0.0).toStringAsFixed(1)}%',
          icon: Icons.check_circle,
          color: Colors.purple,
        ),
      ],
    );
  }
  
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required MaterialColor color,
  }) {
    return Card(
      elevation: 2,
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
                Icon(
                  icon,
                  color: color.shade300,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Center(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAttendanceDistributionChart() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Distribution',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: _attendanceStats['present'] ?? 0,
                      title: 'Present',
                      color: Colors.green.shade400,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: _attendanceStats['absent'] ?? 0,
                      title: 'Absent',
                      color: Colors.red.shade400,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: _attendanceStats['late'] ?? 0,
                      title: 'Late',
                      color: Colors.orange.shade400,
                      radius: 60,
                    ),
                    PieChartSectionData(
                      value: _attendanceStats['earlyOut'] ?? 0,
                      title: 'Early Out',
                      color: Colors.purple.shade400,
                      radius: 60,
                    ),
                  ],
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWorkingHoursChart() {
    // Implementation will build a bar chart for working hours
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Working Hours by Day',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 200,
              child: Center(
                child: Text('Working hours chart will be displayed here'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTrendsTab() {
    // Implementation will build trends visualizations
    return Center(
      child: Text('Trends visualization will be displayed here'),
    );
  }
  
  Widget _buildTeamPerformanceTab() {
    // Implementation will build team performance visualizations
    return Center(
      child: Text('Team performance visualization will be displayed here'),
    );
  }
}
