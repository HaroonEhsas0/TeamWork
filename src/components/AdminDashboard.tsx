
import { useState, useEffect } from 'react';
import { User } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Building2, Users, Key, Copy, RefreshCw } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import AttendanceDashboard from "@/components/AttendanceDashboard";

interface Organization {
  id: string;
  org_name: string;
  org_code: string;
  active: boolean;
  created_at: string;
  expires_at: string;
}

interface Employee {
  id: string;
  user_id: string;
  employee_id: string;
  name: string;
  email: string;
  department: string;
  role: string;
  org_code: string;
}

interface AdminDashboardProps {
  user: User;
  employee: Employee;
}

const AdminDashboard = ({ user, employee }: AdminDashboardProps) => {
  const [organization, setOrganization] = useState<Organization | null>(null);
  const [employees, setEmployees] = useState<Employee[]>([]);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  useEffect(() => {
    fetchOrganizationData();
  }, [employee.org_code]);

  const fetchOrganizationData = async () => {
    try {
      // Fetch organization details
      const { data: orgData, error: orgError } = await (supabase as any)
        .from('organization_codes')
        .select('*')
        .eq('org_code', employee.org_code)
        .single();

      if (orgError) throw orgError;
      setOrganization(orgData);

      // Fetch all employees in the organization
      const { data: empData, error: empError } = await (supabase as any)
        .from('employees')
        .select('*')
        .eq('org_code', employee.org_code)
        .order('created_at', { ascending: false });

      if (empError) throw empError;
      setEmployees(empData || []);

    } catch (error) {
      console.error('Error fetching organization data:', error);
      toast({
        title: "Error",
        description: "Failed to load organization data",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  const copyOrgCode = async () => {
    if (organization?.org_code) {
      await navigator.clipboard.writeText(organization.org_code);
      toast({
        title: "Copied!",
        description: "Organization code copied to clipboard",
      });
    }
  };

  const regenerateCode = async () => {
    if (!organization) return;
    
    try {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      let newCode = '';
      for (let i = 0; i < 6; i++) {
        newCode += chars.charAt(Math.floor(Math.random() * chars.length));
      }

      const { error } = await (supabase as any)
        .from('organization_codes')
        .update({ 
          org_code: newCode,
          expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString()
        })
        .eq('id', organization.id);

      if (error) throw error;

      setOrganization(prev => prev ? { ...prev, org_code: newCode } : null);
      
      toast({
        title: "Code Regenerated",
        description: `New organization code: ${newCode}`,
      });
    } catch (error) {
      console.error('Error regenerating code:', error);
      toast({
        title: "Error",
        description: "Failed to regenerate code",
        variant: "destructive",
      });
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600">Loading admin dashboard...</p>
        </div>
      </div>
    );
  }

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
                <h1 className="text-xl font-bold text-gray-900">TeamWork Admin</h1>
                <p className="text-sm text-gray-500">{organization?.org_name}</p>
              </div>
            </div>
            <div className="flex items-center space-x-4">
              <Badge variant="outline" className="bg-green-50 text-green-700 border-green-200">
                Administrator
              </Badge>
              <Avatar>
                <AvatarFallback className="bg-blue-600 text-white">
                  {employee.name.split(' ').map(n => n[0]).join('')}
                </AvatarFallback>
              </Avatar>
            </div>
          </div>
        </div>
      </header>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <Tabs defaultValue="overview" className="space-y-6">
          <TabsList className="grid w-full grid-cols-3">
            <TabsTrigger value="overview">Overview</TabsTrigger>
            <TabsTrigger value="employees">Employees</TabsTrigger>
            <TabsTrigger value="reports">Reports</TabsTrigger>
          </TabsList>

          <TabsContent value="overview" className="space-y-6">
            {/* Organization Code Card */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center space-x-2">
                  <Key className="w-5 h-5" />
                  <span>Organization Code</span>
                </CardTitle>
                <CardDescription>
                  Share this code with employees to join your organization
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div className="flex items-center space-x-3">
                    <code className="text-2xl font-mono font-bold tracking-wider">
                      {organization?.org_code}
                    </code>
                    <Badge variant="outline">
                      Active until {new Date(organization?.expires_at || '').toLocaleDateString()}
                    </Badge>
                  </div>
                  <div className="flex space-x-2">
                    <Button variant="outline" size="sm" onClick={copyOrgCode}>
                      <Copy className="w-4 h-4 mr-2" />
                      Copy
                    </Button>
                    <Button variant="outline" size="sm" onClick={regenerateCode}>
                      <RefreshCw className="w-4 h-4 mr-2" />
                      Regenerate
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Quick Stats */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <Card>
                <CardContent className="p-6">
                  <div className="flex items-center space-x-2">
                    <Users className="w-8 h-8 text-blue-600" />
                    <div>
                      <p className="text-2xl font-bold">{employees.length}</p>
                      <p className="text-sm text-gray-600">Total Employees</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
              
              <Card>
                <CardContent className="p-6">
                  <div className="flex items-center space-x-2">
                    <Building2 className="w-8 h-8 text-green-600" />
                    <div>
                      <p className="text-2xl font-bold">Active</p>
                      <p className="text-sm text-gray-600">Organization Status</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
              
              <Card>
                <CardContent className="p-6">
                  <div className="flex items-center space-x-2">
                    <Key className="w-8 h-8 text-purple-600" />
                    <div>
                      <p className="text-2xl font-bold">30 Days</p>
                      <p className="text-sm text-gray-600">Code Validity</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          <TabsContent value="employees">
            <Card>
              <CardHeader>
                <CardTitle>Team Members</CardTitle>
                <CardDescription>
                  Manage your organization's employees
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  {employees.map((emp) => (
                    <div key={emp.id} className="flex items-center justify-between p-4 border rounded-lg">
                      <div className="flex items-center space-x-4">
                        <Avatar>
                          <AvatarFallback>
                            {emp.name.split(' ').map(n => n[0]).join('')}
                          </AvatarFallback>
                        </Avatar>
                        <div>
                          <p className="font-medium">{emp.name}</p>
                          <p className="text-sm text-gray-600">{emp.email}</p>
                          <p className="text-xs text-gray-500">{emp.department} • {emp.employee_id}</p>
                        </div>
                      </div>
                      <Badge variant={emp.role === 'admin' ? 'default' : 'secondary'}>
                        {emp.role}
                      </Badge>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          <TabsContent value="reports">
            <AttendanceDashboard records={[]} employees={employees} />
          </TabsContent>
        </Tabs>
      </div>
    </div>
  );
};

export default AdminDashboard;
