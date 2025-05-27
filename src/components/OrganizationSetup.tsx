
import { useState } from 'react';
import { User } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Building2, Users, Key } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

interface OrganizationSetupProps {
  user: User;
  onSetupComplete: () => void;
}

const OrganizationSetup = ({ user, onSetupComplete }: OrganizationSetupProps) => {
  const [isLoading, setIsLoading] = useState(false);
  const [formData, setFormData] = useState({
    orgName: '',
    joinCode: ''
  });
  const { toast } = useToast();

  const generateOrgCode = () => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  };

  const createOrganization = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.orgName.trim()) return;
    
    setIsLoading(true);
    try {
      const orgCode = generateOrgCode();
      
      // Create organization
      const { data: newOrgData, error: orgError } = await (supabase as any)
        .from('organization_codes')
        .insert({
          admin_id: user.id,
          org_name: formData.orgName.trim(),
          org_code: orgCode,
          active: true
        })
        .select()
        .single();

      if (orgError) throw orgError;

      // Create admin role
      const { error: roleError } = await (supabase as any)
        .from('user_roles')
        .insert({
          user_id: user.id,
          role: 'admin',
          org_code: orgCode,
          permissions: { manage_employees: true, view_reports: true }
        });

      if (roleError) throw roleError;

      // Update or create employee record
      const { error: empError } = await (supabase as any)
        .from('employees')
        .upsert({
          user_id: user.id,
          employee_id: 'ADMIN_' + user.id.slice(0, 8),
          name: user.user_metadata?.name || user.email?.split('@')[0] || 'Admin',
          email: user.email || '',
          department: 'Administration',
          role: 'admin',
          org_code: orgCode
        });

      if (empError) throw empError;

      toast({
        title: "Organization Created!",
        description: `Your organization code is: ${orgCode}. Share this with your team members.`,
      });

      onSetupComplete();
    } catch (error: any) {
      console.error('Error creating organization:', error);
      toast({
        title: "Error",
        description: error.message || "Failed to create organization",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const joinOrganization = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.joinCode.trim()) return;
    
    setIsLoading(true);
    try {
      // Check if organization code exists and is active
      const { data: org, error: orgError } = await (supabase as any)
        .from('organization_codes')
        .select('*')
        .eq('org_code', formData.joinCode.toUpperCase())
        .eq('active', true)
        .single();

      if (orgError || !org) {
        throw new Error('Invalid or expired organization code');
      }

      // Check if code is expired
      if (new Date(org.expires_at) < new Date()) {
        throw new Error('Organization code has expired');
      }

      // Create employee role
      const { error: roleError } = await (supabase as any)
        .from('user_roles')
        .insert({
          user_id: user.id,
          role: 'employee',
          org_code: formData.joinCode.toUpperCase(),
          permissions: { view_attendance: true }
        });

      if (roleError) throw roleError;

      // Create employee record
      const { error: empError } = await (supabase as any)
        .from('employees')
        .insert({
          user_id: user.id,
          employee_id: 'EMP_' + user.id.slice(0, 8),
          name: user.user_metadata?.name || user.email?.split('@')[0] || 'Employee',
          email: user.email || '',
          department: 'General',
          role: 'employee',
          org_code: formData.joinCode.toUpperCase()
        });

      if (empError) throw empError;

      toast({
        title: "Successfully Joined!",
        description: `Welcome to ${org.org_name}!`,
      });

      onSetupComplete();
    } catch (error: any) {
      console.error('Error joining organization:', error);
      toast({
        title: "Error",
        description: error.message || "Failed to join organization",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <div className="mx-auto mb-4 w-16 h-16 bg-blue-600 rounded-full flex items-center justify-center">
            <Building2 className="w-8 h-8 text-white" />
          </div>
          <CardTitle className="text-2xl font-bold text-gray-900">Welcome to TeamWork</CardTitle>
          <CardDescription>Join your organization or create a new one</CardDescription>
        </CardHeader>
        <CardContent>
          <Tabs defaultValue="join" className="space-y-4">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="join" className="flex items-center gap-2">
                <Users className="w-4 h-4" />
                Join Team
              </TabsTrigger>
              <TabsTrigger value="create" className="flex items-center gap-2">
                <Key className="w-4 h-4" />
                Create Org
              </TabsTrigger>
            </TabsList>

            <TabsContent value="join">
              <form onSubmit={joinOrganization} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="join-code">Organization Code</Label>
                  <Input
                    id="join-code"
                    type="text"
                    placeholder="Enter 6-character code"
                    value={formData.joinCode}
                    onChange={(e) => setFormData(prev => ({ ...prev, joinCode: e.target.value }))}
                    maxLength={6}
                    required
                    className="uppercase"
                  />
                  <p className="text-xs text-gray-500">
                    Get this code from your organization administrator
                  </p>
                </div>
                <Button type="submit" className="w-full" disabled={isLoading}>
                  {isLoading ? "Joining..." : "Join Organization"}
                </Button>
              </form>
            </TabsContent>

            <TabsContent value="create">
              <form onSubmit={createOrganization} className="space-y-4">
                <div className="space-y-2">
                  <Label htmlFor="org-name">Organization Name</Label>
                  <Input
                    id="org-name"
                    type="text"
                    placeholder="Enter your company name"
                    value={formData.orgName}
                    onChange={(e) => setFormData(prev => ({ ...prev, orgName: e.target.value }))}
                    required
                  />
                </div>
                <Button type="submit" className="w-full" disabled={isLoading}>
                  {isLoading ? "Creating..." : "Create Organization"}
                </Button>
                <p className="text-xs text-gray-500 text-center">
                  You'll become the administrator and get a shareable code
                </p>
              </form>
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  );
};

export default OrganizationSetup;
