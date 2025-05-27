import { useState, useEffect } from 'react';
import { User } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import FingerprintScanner from "@/components/FingerprintScanner";
import AttendanceDashboard from "@/components/AttendanceDashboard";
import OrganizationSetup from "@/components/OrganizationSetup";
import AdminDashboard from "@/components/AdminDashboard";
import { Fingerprint, Clock, Calendar, Building2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from '@/hooks/useAuth';

interface Employee {
  id: string;
  user_id: string;
  employee_id: string;
  name: string;
  email: string;
  department: string;
  role: string;
  org_code: string; // Made required to match AttendanceDashboard
  fingerprint_hash?: string;
}

interface UserRole {
  id: string;
  user_id: string;
  role: string;
  permissions: any;
  org_code: string;
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

interface AttendanceAppProps {
  user: User;
}

const AttendanceApp = ({ user }: AttendanceAppProps) => {
  const [employee, setEmployee] = useState<Employee | null>(null);
  const [userRole, setUserRole] = useState<UserRole | null>(null);
  const [todayRecord, setTodayRecord] = useState<AttendanceRecord | null>(null);
  const [attendanceRecords, setAttendanceRecords] = useState<AttendanceRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [needsSetup, setNeedsSetup] = useState(false);
  const { toast } = useToast();
  const { signOut } = useAuth();

  useEffect(() => {
    fetchEmployeeData();
  }, [user]);

  const fetchEmployeeData = async () => {
    try {
      console.log('Fetching employee data for user:', user.id);
      
      // First check if user has any roles
      const { data: roleData, error: roleError } = await (supabase as any)
        .from('user_roles')
        .select('*')
        .eq('user_id', user.id)
        .maybeSingle();

      console.log('Role data:', roleData, 'Error:', roleError);

      if (roleError && roleError.code !== 'PGRST116') {
        throw roleError;
      }

      if (!roleData) {
        console.log('No role found, user needs setup');
        setNeedsSetup(true);
        setLoading(false);
        return;
      }

      setUserRole(roleData);

      // Fetch employee record
      const { data: employeeData, error: employeeError } = await (supabase as any)
        .from('employees')
        .select('*')
        .eq('user_id', user.id)
        .eq('org_code', roleData.org_code)
        .maybeSingle();

      console.log('Employee data:', employeeData, 'Error:', employeeError);

      if (employeeError) {
        console.error('Employee fetch error:', employeeError);
        throw employeeError;
      }

      if (!employeeData || !employeeData.org_code) {
        setNeedsSetup(true);
        setLoading(false);
        return;
      }

      setEmployee(employeeData);

      // If user is admin, don't fetch attendance records - they'll use admin dashboard
      if (roleData.role === 'admin') {
        setLoading(false);
        return;
      }

      // Fetch today's attendance record for employees
      const today = new Date().toISOString().split('T')[0];
      const { data: attendanceData, error: attendanceError } = await (supabase as any)
        .from('attendance_records')
        .select('*')
        .eq('employee_id', (employeeData as any).id)
        .eq('date', today)
        .maybeSingle();

      console.log('Today\'s attendance:', attendanceData, 'Error:', attendanceError);

      if (attendanceError && attendanceError.code !== 'PGRST116') {
        console.error('Attendance fetch error:', attendanceError);
      } else {
        setTodayRecord(attendanceData);
      }

      // Fetch all attendance records
      const { data: allRecords, error: allRecordsError } = await (supabase as any)
        .from('attendance_records')
        .select('*')
        .eq('employee_id', (employeeData as any).id)
        .order('date', { ascending: false });

      console.log('All records:', allRecords, 'Error:', allRecordsError);

      if (allRecordsError) {
        console.error('All records fetch error:', allRecordsError);
      } else {
        setAttendanceRecords(allRecords || []);
      }

    } catch (error) {
      console.error('Error fetching employee data:', error);
      toast({
        title: "Error",
        description: "Failed to load employee data",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const handleFingerprintAuth = async (action: 'check-in' | 'check-out') => {
    if (!employee) return;

    try {
      console.log('Processing fingerprint auth:', action, 'for employee:', employee.id);
      const today = new Date().toISOString().split('T')[0];
      const now = new Date().toISOString();

      if (action === 'check-in') {
        const { data, error } = await (supabase as any)
          .from('attendance_records')
          .insert({
            employee_id: employee.id,
            check_in: now,
            date: today,
            status: 'checked-in',
            fingerprint_verified: true,
          })
          .select()
          .single();

        console.log('Check-in result:', data, 'Error:', error);

        if (error) throw error;

        if (data) {
          setTodayRecord(data);
          setAttendanceRecords(prev => [data, ...prev]);
          
          toast({
            title: "Check-in Successful",
            description: `Welcome to work, ${employee.name}!`,
          });
        }
      } else {
        if (!todayRecord) return;

        const { data, error } = await (supabase as any)
          .from('attendance_records')
          .update({
            check_out: now,
            status: 'checked-out',
          })
          .eq('id', todayRecord.id)
          .select()
          .single();

        console.log('Check-out result:', data, 'Error:', error);

        if (error) throw error;

        if (data) {
          setTodayRecord(data);
          setAttendanceRecords(prev => 
            prev.map(record => record.id === (data as any).id ? data : record)
          );
          
          toast({
            title: "Check-out Successful",
            description: `Have a great day, ${employee.name}!`,
          });
        }
      }
    } catch (error) {
      console.error('Error with fingerprint auth:', error);
      toast({
        title: "Error",
        description: "Failed to process attendance",
        variant: "destructive",
      });
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading your profile...</p>
        </div>
      </div>
    );
  }

  if (needsSetup) {
    return <OrganizationSetup user={user} onSetupComplete={fetchEmployeeData} />;
  }

  if (!employee || !userRole) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
        <Card className="w-full max-w-md">
          <CardHeader className="text-center">
            <CardTitle>Profile Setup Required</CardTitle>
            <CardDescription>Setting up your employee profile...</CardDescription>
          </CardHeader>
        </Card>
      </div>
    );
  }

  // Show admin dashboard for admin users
  if (userRole.role === 'admin') {
    return <AdminDashboard user={user} employee={employee} />;
  }

  // Show employee attendance app
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      {/* Header */}
      <header className="bg-white border-b border-gray-200 shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-3">
              <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center">
                <Building2 className="w-5 h-5 text-white" />
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">TeamWork</h1>
                <p className="text-sm text-gray-500">Smart Attendance</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <div className="flex items-center space-x-3">
                <Avatar>
                  <AvatarFallback className="bg-blue-600 text-white">
                    {employee.name.split(' ').map(n => n[0]).join('')}
                  </AvatarFallback>
                </Avatar>
                <div className="hidden sm:block">
                  <p className="text-sm font-medium text-gray-900">{employee.name}</p>
                  <p className="text-xs text-gray-500">{employee.department}</p>
                </div>
              </div>
              <Button variant="outline" onClick={signOut}>
                Logout
              </Button>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Tabs defaultValue="attendance" className="space-y-6">
          <TabsList className="grid w-full grid-cols-2">
            <TabsTrigger value="attendance">Attendance</TabsTrigger>
            <TabsTrigger value="dashboard">Dashboard</TabsTrigger>
          </TabsList>

          <TabsContent value="attendance" className="space-y-6">
            {/* Today's Status */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <Calendar className="w-5 h-5" />
                  <span>Today's Status</span>
                </CardTitle>
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
                <div className="flex items-center justify-between">
                  <div className="space-y-2">
                    {todayRecord ? (
                      <>
                        <div className="flex items-center space-x-2">
                          <Badge variant={todayRecord.status === 'checked-in' ? 'default' : 'secondary'}>
                            {todayRecord.status === 'checked-in' ? 'Checked In' : 'Checked Out'}
                          </Badge>
                          {todayRecord.fingerprint_verified && (
                            <Badge variant="outline" className="text-green-600 border-green-600">
                              Verified
                            </Badge>
                          )}
                        </div>
                        {todayRecord.check_in && (
                          <p className="text-sm text-gray-600">
                            Check-in: {new Date(todayRecord.check_in).toLocaleTimeString()}
                          </p>
                        )}
                        {todayRecord.check_out && (
                          <p className="text-sm text-gray-600">
                            Check-out: {new Date(todayRecord.check_out).toLocaleTimeString()}
                          </p>
                        )}
                      </>
                    ) : (
                      <Badge variant="outline">Not Checked In</Badge>
                    )}
                  </div>
                  <Clock className="w-8 h-8 text-gray-400" />
                </div>
              </CardContent>
            </Card>

            {/* Fingerprint Scanner */}
            <Card>
              <CardHeader>
                <CardTitle>Fingerprint Authentication</CardTitle>
                <CardDescription>
                  Secure check-in/out with fingerprint verification for {employee.name}
                </CardDescription>
              </CardHeader>
              <CardContent>
                <FingerprintScanner 
                  onAuthenticated={() => handleFingerprintAuth(
                    !todayRecord ? 'check-in' : todayRecord.status === 'checked-in' ? 'check-out' : 'check-in'
                  )}
                  isDisabled={todayRecord?.status === 'checked-out'}
                />
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="dashboard">
            <AttendanceDashboard records={attendanceRecords} employees={[employee]} />
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
};

export default AttendanceApp;
