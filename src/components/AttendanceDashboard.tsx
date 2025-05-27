
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Users, Clock, Calendar, TrendingUp } from "lucide-react";

interface Employee {
  id: string;
  name: string;
  email: string;
  department: string;
}

interface AttendanceRecord {
  id: string;
  employee_id: string;
  check_in?: string;
  check_out?: string;
  date: string;
  status: 'checked-in' | 'checked-out' | 'absent';
  fingerprint_verified: boolean;
}

interface AttendanceDashboardProps {
  records: AttendanceRecord[];
  employees: Employee[];
}

const AttendanceDashboard = ({ records, employees }: AttendanceDashboardProps) => {
  const today = new Date().toISOString().split('T')[0];
  const todayRecords = records.filter(record => record.date === today);
  
  const checkedInCount = todayRecords.filter(record => record.status === 'checked-in').length;
  const checkedOutCount = todayRecords.filter(record => record.status === 'checked-out').length;
  const absentCount = employees.length - todayRecords.length;
  const totalHoursToday = todayRecords
    .filter(record => record.check_in && record.check_out)
    .reduce((total, record) => {
      const checkIn = new Date(record.check_in!);
      const checkOut = new Date(record.check_out!);
      const hours = (checkOut.getTime() - checkIn.getTime()) / (1000 * 60 * 60);
      return total + hours;
    }, 0);

  const formatTime = (dateString: string | undefined) => {
    return dateString ? new Date(dateString).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }) : '--';
  };

  const calculateWorkHours = (checkIn: string | undefined, checkOut: string | undefined) => {
    if (!checkIn || !checkOut) return '--';
    const checkInTime = new Date(checkIn);
    const checkOutTime = new Date(checkOut);
    const hours = (checkOutTime.getTime() - checkInTime.getTime()) / (1000 * 60 * 60);
    return `${hours.toFixed(1)}h`;
  };

  return (
    <div className="space-y-6">
      {/* Statistics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Present Today</p>
                <p className="text-2xl font-bold text-green-600">{checkedInCount + checkedOutCount}</p>
              </div>
              <Users className="w-8 h-8 text-green-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Currently In</p>
                <p className="text-2xl font-bold text-blue-600">{checkedInCount}</p>
              </div>
              <Clock className="w-8 h-8 text-blue-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Absent</p>
                <p className="text-2xl font-bold text-red-600">{absentCount}</p>
              </div>
              <Calendar className="w-8 h-8 text-red-600" />
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">Total Hours</p>
                <p className="text-2xl font-bold text-purple-600">{totalHoursToday.toFixed(1)}h</p>
              </div>
              <TrendingUp className="w-8 h-8 text-purple-600" />
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Today's Attendance */}
      <Card>
        <CardHeader>
          <CardTitle>Today's Attendance</CardTitle>
          <CardDescription>
            {new Date().toLocaleDateString('en-US', { 
              weekday: 'long', 
              year: 'numeric', 
              month: 'long', 
              day: 'numeric' 
            })}
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {employees.map(employee => {
              const record = todayRecords.find(r => r.employee_id === employee.id);
              
              return (
                <div key={employee.id} className="flex items-center justify-between p-4 border rounded-lg">
                  <div className="flex items-center space-x-3">
                    <Avatar>
                      <AvatarFallback className="bg-blue-600 text-white">
                        {employee.name.split(' ').map(n => n[0]).join('')}
                      </AvatarFallback>
                    </Avatar>
                    <div>
                      <p className="font-medium text-gray-900">{employee.name}</p>
                      <p className="text-sm text-gray-500">{employee.department}</p>
                    </div>
                  </div>
                  
                  <div className="flex items-center space-x-4">
                    <div className="text-right">
                      <p className="text-sm font-medium">Check-in: {formatTime(record?.check_in)}</p>
                      <p className="text-sm font-medium">Check-out: {formatTime(record?.check_out)}</p>
                    </div>
                    
                    <div className="text-right min-w-[80px]">
                      <p className="text-sm text-gray-600 mb-1">Hours</p>
                      <p className="font-medium">{calculateWorkHours(record?.check_in, record?.check_out)}</p>
                    </div>
                    
                    <Badge 
                      variant={
                        !record ? 'destructive' : 
                        record.status === 'checked-in' ? 'default' : 
                        'secondary'
                      }
                    >
                      {!record ? 'Absent' : 
                       record.status === 'checked-in' ? 'Present' : 
                       'Completed'}
                    </Badge>
                  </div>
                </div>
              );
            })}
          </div>
        </CardContent>
      </Card>

      {/* Recent Activity */}
      <Card>
        <CardHeader>
          <CardTitle>Recent Activity</CardTitle>
          <CardDescription>Latest check-ins and check-outs</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-3">
            {records
              .sort((a, b) => {
                const aTime = a.check_out || a.check_in;
                const bTime = b.check_out || b.check_in;
                return new Date(bTime || 0).getTime() - new Date(aTime || 0).getTime();
              })
              .slice(0, 5)
              .map(record => {
                const employee = employees.find(e => e.id === record.employee_id);
                return (
                  <div key={record.id} className="flex items-center justify-between p-3 border-l-4 border-blue-500 bg-blue-50 rounded">
                    <div>
                      <p className="font-medium text-gray-900">{employee?.name || 'Unknown Employee'}</p>
                      <p className="text-sm text-gray-600">
                        {record.check_out ? 'Checked out' : 'Checked in'} at{' '}
                        {formatTime(record.check_out || record.check_in)}
                      </p>
                    </div>
                    <Badge variant="outline">
                      {new Date(record.date).toLocaleDateString()}
                    </Badge>
                  </div>
                );
              })}
          </div>
        </CardContent>
      </Card>
    </div>
  );
};

export default AttendanceDashboard;
