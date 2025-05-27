import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import '../models/team_model.dart';
import 'date_time_utils.dart';
import 'constants.dart';

class ExportUtils {
  // Generate and export attendance report as PDF
  static Future<File?> exportAttendanceReportPdf({
    required List<AttendanceModel> attendanceRecords,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    UserModel? user,
    TeamModel? team,
    Map<String, dynamic>? stats,
  }) async {
    try {
      final pdf = pw.Document();
      
      // Load font
      final font = await PdfGoogleFonts.nunitoRegular();
      final fontBold = await PdfGoogleFonts.nunitoBold();
      
      // Add page
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      AppConstants.appName,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 24,
                        color: PdfColors.blue700,
                      ),
                    ),
                    pw.Text(
                      'Generated: ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 18,
                    color: PdfColors.black,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Period: ${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
                if (user != null)
                  pw.Text(
                    'Employee: ${user.name} (${user.email})',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                if (team != null)
                  pw.Text(
                    'Team: ${team.name}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                pw.Divider(),
              ],
            );
          },
          footer: (pw.Context context) {
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  AppConstants.appDescription,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              // Statistics section
              if (stats != null)
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Summary',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 16,
                          color: PdfColors.blue700,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Present',
                            stats['present']?.toString() ?? '0',
                            PdfColors.green700,
                            font,
                            fontBold,
                          ),
                          _buildStatItem(
                            'Absent',
                            stats['absent']?.toString() ?? '0',
                            PdfColors.red700,
                            font,
                            fontBold,
                          ),
                          _buildStatItem(
                            'Late',
                            stats['late']?.toString() ?? '0',
                            PdfColors.orange700,
                            font,
                            fontBold,
                          ),
                          _buildStatItem(
                            'Early Out',
                            stats['earlyCheckout']?.toString() ?? '0',
                            PdfColors.purple700,
                            font,
                            fontBold,
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total Hours',
                            '${(stats['totalHours'] as double?)?.toStringAsFixed(1) ?? '0.0'}h',
                            PdfColors.blue700,
                            font,
                            fontBold,
                          ),
                          _buildStatItem(
                            'Avg Hours/Day',
                            '${(stats['avgHoursPerDay'] as double?)?.toStringAsFixed(1) ?? '0.0'}h',
                            PdfColors.blue700,
                            font,
                            fontBold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              
              pw.SizedBox(height: 16),
              
              // Attendance records table
              pw.Text(
                'Attendance Records',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 8),
              
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2), // Date
                  1: const pw.FlexColumnWidth(2), // Name (if team report)
                  2: const pw.FlexColumnWidth(1.5), // Check In
                  3: const pw.FlexColumnWidth(1.5), // Check Out
                  4: const pw.FlexColumnWidth(1), // Duration
                  5: const pw.FlexColumnWidth(1), // Status
                },
                children: [
                  // Table header
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue100,
                    ),
                    children: [
                      _buildTableCell('Date', font, isHeader: true),
                      if (team != null)
                        _buildTableCell('Name', font, isHeader: true)
                      else
                        _buildTableCell('Day', font, isHeader: true),
                      _buildTableCell('Check In', font, isHeader: true),
                      _buildTableCell('Check Out', font, isHeader: true),
                      _buildTableCell('Hours', font, isHeader: true),
                      _buildTableCell('Status', font, isHeader: true),
                    ],
                  ),
                  
                  // Table rows
                  ...attendanceRecords.map((record) {
                    final checkInTime = record.checkInTime;
                    final checkOutTime = record.checkOutTime;
                    final duration = record.duration;
                    
                    String status = 'Absent';
                    if (checkInTime != null) {
                      if (checkOutTime != null) {
                        status = 'Present';
                        if (record.isLate(AppConstants.workStartTime)) {
                          status = 'Late';
                        }
                        if (record.leftEarly(AppConstants.workEndTime)) {
                          status = 'Early Out';
                        }
                      } else {
                        status = 'Incomplete';
                      }
                    }
                    
                    return pw.TableRow(
                      children: [
                        _buildTableCell(
                          DateFormat('MMM d, yyyy').format(record.date),
                          font,
                        ),
                        if (team != null)
                          _buildTableCell(
                            record.userName ?? 'Unknown',
                            font,
                          )
                        else
                          _buildTableCell(
                            DateTimeUtils.getDayOfWeekName(record.date),
                            font,
                          ),
                        _buildTableCell(
                          checkInTime != null
                              ? DateFormat('h:mm a').format(checkInTime)
                              : '-',
                          font,
                        ),
                        _buildTableCell(
                          checkOutTime != null
                              ? DateFormat('h:mm a').format(checkOutTime)
                              : '-',
                          font,
                        ),
                        _buildTableCell(
                          duration != null
                              ? (duration.inMinutes / 60).toStringAsFixed(1)
                              : '-',
                          font,
                        ),
                        _buildTableCell(
                          status,
                          font,
                          textColor: _getStatusColor(status),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );
      
      // Save the PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      return file;
    } catch (e) {
      print('Error generating PDF: $e');
      return null;
    }
  }
  
  // Generate and export attendance report as CSV
  static Future<File?> exportAttendanceReportCsv({
    required List<AttendanceModel> attendanceRecords,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    UserModel? user,
    TeamModel? team,
  }) async {
    try {
      // Prepare CSV data
      final List<List<dynamic>> csvData = [];
      
      // Add header row
      final headerRow = [
        'Date',
        if (team != null) 'Name',
        'Day',
        'Check In',
        'Check Out',
        'Duration (Hours)',
        'Status',
        'Notes',
      ];
      csvData.add(headerRow);
      
      // Add data rows
      for (final record in attendanceRecords) {
        final checkInTime = record.checkInTime;
        final checkOutTime = record.checkOutTime;
        final duration = record.duration;
        
        String status = 'Absent';
        if (checkInTime != null) {
          if (checkOutTime != null) {
            status = 'Present';
            if (record.isLate(AppConstants.workStartTime)) {
              status = 'Late';
            }
            if (record.leftEarly(AppConstants.workEndTime)) {
              status = 'Early Out';
            }
          } else {
            status = 'Incomplete';
          }
        }
        
        final row = [
          DateFormat('yyyy-MM-dd').format(record.date),
          if (team != null) record.userName ?? 'Unknown',
          DateTimeUtils.getDayOfWeekName(record.date),
          checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '',
          checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '',
          duration != null ? (duration.inMinutes / 60).toStringAsFixed(1) : '',
          status,
          record.notes ?? '',
        ];
        
        csvData.add(row);
      }
      
      // Convert to CSV
      final csv = const ListToCsvConverter().convert(csvData);
      
      // Save the CSV
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      
      return file;
    } catch (e) {
      print('Error generating CSV: $e');
      return null;
    }
  }
  
  // Generate and export attendance report as Excel
  static Future<File?> exportAttendanceReportExcel({
    required List<AttendanceModel> attendanceRecords,
    required String title,
    required DateTime startDate,
    required DateTime endDate,
    UserModel? user,
    TeamModel? team,
    Map<String, dynamic>? stats,
  }) async {
    try {
      // Create a new Excel document
      final excel = Excel.createExcel();
      
      // Create a sheet for attendance data
      final Sheet attendanceSheet = excel['Attendance Records'];
      
      // Add title and date range
      final titleStyle = CellStyle(
        bold: true,
        fontSize: 14,
        fontColorHex: '#0D47A1',
      );
      
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColor: getColorFromHex('E3F2FD'),
        fontColorHex: '#1976D2',
      );
      
      // Add title row
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value = title;
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;
      
      // Add date range
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value = 
          'Period: ${DateFormat('MMM d, yyyy').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
      
      // Add user/team info if available
      int rowIndex = 2;
      if (user != null) {
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
            'Employee: ${user.name} (${user.email})';
        rowIndex++;
      }
      
      if (team != null) {
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 
            'Team: ${team.name}';
        rowIndex++;
      }
      
      rowIndex++; // Add empty row
      
      // Add statistics if available
      if (stats != null) {
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Summary';
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = titleStyle;
        rowIndex++;
        
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Present';
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = stats['present'] ?? 0;
        rowIndex++;
        
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Absent';
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = stats['absent'] ?? 0;
        rowIndex++;
        
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Late';
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = stats['late'] ?? 0;
        rowIndex++;
        
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Early Out';
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = stats['earlyCheckout'] ?? 0;
        rowIndex++;
        
        if (stats['totalHours'] != null) {
          attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Total Hours';
          attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
              '${(stats['totalHours'] as double).toStringAsFixed(1)}h';
          rowIndex++;
        }
        
        if (stats['avgHoursPerDay'] != null) {
          attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Avg Hours/Day';
          attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = 
              '${(stats['avgHoursPerDay'] as double).toStringAsFixed(1)}h';
          rowIndex++;
        }
        
        rowIndex++; // Add empty row
      }
      
      // Add header row for attendance data
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = 'Date';
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).cellStyle = headerStyle;
      
      int columnIndex = 1;
      if (team != null) {
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 'Name';
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = headerStyle;
        columnIndex++;
      }
      
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 'Day';
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = headerStyle;
      columnIndex++;
      
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 'Check In';
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = headerStyle;
      columnIndex++;
      
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 'Check Out';
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = headerStyle;
      columnIndex++;
      
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 'Hours';
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = headerStyle;
      columnIndex++;
      
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 'Status';
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = headerStyle;
      columnIndex++;
      
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 'Notes';
      attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).cellStyle = headerStyle;
      
      rowIndex++;
      
      // Add data rows
      for (final record in attendanceRecords) {
        final checkInTime = record.checkInTime;
        final checkOutTime = record.checkOutTime;
        final duration = record.duration;
        
        String status = 'Absent';
        if (checkInTime != null) {
          if (checkOutTime != null) {
            status = 'Present';
            if (record.isLate(AppConstants.workStartTime)) {
              status = 'Late';
            }
            if (record.leftEarly(AppConstants.workEndTime)) {
              status = 'Early Out';
            }
          } else {
            status = 'Incomplete';
          }
        }
        
        columnIndex = 0;
        
        // Date
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 
            DateFormat('yyyy-MM-dd').format(record.date);
        columnIndex++;
        
        // Name (if team report)
        if (team != null) {
          attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 
              record.userName ?? 'Unknown';
          columnIndex++;
        }
        
        // Day of week
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 
            DateTimeUtils.getDayOfWeekName(record.date);
        columnIndex++;
        
        // Check In
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 
            checkInTime != null ? DateFormat('HH:mm').format(checkInTime) : '-';
        columnIndex++;
        
        // Check Out
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 
            checkOutTime != null ? DateFormat('HH:mm').format(checkOutTime) : '-';
        columnIndex++;
        
        // Duration
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 
            duration != null ? (duration.inMinutes / 60).toStringAsFixed(1) : '-';
        columnIndex++;
        
        // Status
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = status;
        columnIndex++;
        
        // Notes
        attendanceSheet.cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: rowIndex)).value = 
            record.notes ?? '';
        
        rowIndex++;
      }
      
      // Auto-size columns
      for (int i = 0; i < columnIndex + 1; i++) {
        attendanceSheet.setColumnWidth(i, 15.0);
      }
      
      // Save the Excel file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/attendance_report_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      await file.writeAsBytes(excel.encode()!);
      
      return file;
    } catch (e) {
      print('Error generating Excel: $e');
      return null;
    }
  }
  
  // Share a file
  static Future<void> shareFile(File file, String subject) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject,
      );
    } catch (e) {
      print('Error sharing file: $e');
    }
  }
  
  // Print a PDF file
  static Future<void> printPdf(File file) async {
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => file.readAsBytes(),
      );
    } catch (e) {
      print('Error printing PDF: $e');
    }
  }
  
  // Helper method to build a stat item for PDF
  static pw.Widget _buildStatItem(
    String label,
    String value,
    PdfColor color,
    pw.Font font,
    pw.Font fontBold,
  ) {
    return pw.Column(
      children: [
        pw.Container(
          width: 50,
          height: 50,
          decoration: pw.BoxDecoration(
            color: color.shade(50),
            shape: pw.BoxShape.circle,
          ),
          child: pw.Center(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 16,
                color: color,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }
  
  // Helper method to build a table cell for PDF
  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: isHeader ? pw.Font.helveticaBold() : font,
          fontSize: 10,
          color: textColor ?? (isHeader ? PdfColors.blue700 : PdfColors.black),
        ),
      ),
    );
  }
  
  // Helper method to get status color for PDF
  static PdfColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return PdfColors.green700;
      case 'absent':
        return PdfColors.red700;
      case 'late':
        return PdfColors.orange700;
      case 'early out':
        return PdfColors.purple700;
      case 'incomplete':
        return PdfColors.amber700;
      default:
        return PdfColors.grey700;
    }
  }
}
