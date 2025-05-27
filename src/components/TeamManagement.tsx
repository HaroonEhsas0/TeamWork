import { useState, useEffect } from 'react';
import { User } from '@supabase/supabase-js';
import { supabase } from '@/integrations/supabase/client';
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Users, UserPlus, Trash2, RefreshCcw } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

interface TeamManagementProps {
  user: User;
  isAdmin: boolean;
  orgCode: string;
}

interface Team {
  id: string;
  name: string;
  created_at: string;
  org_code: string;
}

interface TeamMember {
  id: string;
  employee_id: string;
  name: string;
  email: string;
  role: string;
}

const TeamManagement = ({ user, isAdmin, orgCode }: TeamManagementProps) => {
  const [teams, setTeams] = useState<Team[]>([]);
  const [teamMembers, setTeamMembers] = useState<Record<string, TeamMember[]>>({});
  const [newTeamName, setNewTeamName] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [selectedTeam, setSelectedTeam] = useState<string | null>(null);
  const { toast } = useToast();

  // Load teams on component mount
  useEffect(() => {
    loadTeams();
  }, [orgCode]);

  // Load team members when a team is selected
  useEffect(() => {
    if (selectedTeam) {
      loadTeamMembers(selectedTeam);
    }
  }, [selectedTeam]);

  const loadTeams = async () => {
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('teams')
        .select('*')
        .eq('org_code', orgCode);

      if (error) throw error;
      
      setTeams(data || []);
      if (data && data.length > 0 && !selectedTeam) {
        setSelectedTeam(data[0].id);
      }
    } catch (error) {
      console.error('Error loading teams:', error);
      toast({
        title: "Error",
        description: "Failed to load teams. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const loadTeamMembers = async (teamId: string) => {
    try {
      const { data, error } = await supabase
        .from('team_members')
        .select(`
          id,
          employees (
            id,
            name,
            email,
            role
          )
        `)
        .eq('team_id', teamId);

      if (error) throw error;
      
      // Transform the data to match our interface
      const members = data?.map(item => ({
        id: item.id,
        employee_id: item.employees.id,
        name: item.employees.name,
        email: item.employees.email,
        role: item.employees.role
      })) || [];
      
      setTeamMembers(prev => ({
        ...prev,
        [teamId]: members
      }));
    } catch (error) {
      console.error('Error loading team members:', error);
      toast({
        title: "Error",
        description: "Failed to load team members. Please try again.",
        variant: "destructive",
      });
    }
  };

  const createTeam = async () => {
    if (!newTeamName.trim()) return;
    
    setIsLoading(true);
    try {
      const { data, error } = await supabase
        .from('teams')
        .insert({
          name: newTeamName.trim(),
          org_code: orgCode,
          created_at: new Date().toISOString()
        })
        .select();

      if (error) throw error;
      
      toast({
        title: "Success",
        description: "Team created successfully",
      });
      
      setNewTeamName('');
      loadTeams();
    } catch (error) {
      console.error('Error creating team:', error);
      toast({
        title: "Error",
        description: "Failed to create team. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const deleteTeam = async (teamId: string) => {
    if (!confirm('Are you sure you want to delete this team?')) return;
    
    setIsLoading(true);
    try {
      // First delete all team members
      const { error: memberError } = await supabase
        .from('team_members')
        .delete()
        .eq('team_id', teamId);

      if (memberError) throw memberError;
      
      // Then delete the team
      const { error } = await supabase
        .from('teams')
        .delete()
        .eq('id', teamId);

      if (error) throw error;
      
      toast({
        title: "Success",
        description: "Team deleted successfully",
      });
      
      loadTeams();
      if (selectedTeam === teamId) {
        setSelectedTeam(null);
      }
    } catch (error) {
      console.error('Error deleting team:', error);
      toast({
        title: "Error",
        description: "Failed to delete team. Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  const assignUserToTeam = async () => {
    if (!selectedTeam) return;
    
    // This would typically open a modal with a list of employees to select from
    toast({
      title: "Feature Coming Soon",
      description: "User assignment will be available in the next update.",
    });
  };

  return (
    <Card className="w-full">
      <CardHeader>
        <CardTitle className="flex items-center">
          <Users className="mr-2" />
          {isAdmin ? 'Team Management' : 'My Teams'}
        </CardTitle>
        <CardDescription>
          {isAdmin 
            ? 'Create and manage teams in your organization' 
            : 'View your team assignments and members'}
        </CardDescription>
      </CardHeader>
      <CardContent>
        {isAdmin && (
          <div className="space-y-4 mb-6">
            <div className="flex items-end gap-2">
              <div className="flex-1">
                <Label htmlFor="teamName">Team Name</Label>
                <Input 
                  id="teamName" 
                  placeholder="Enter team name" 
                  value={newTeamName}
                  onChange={(e) => setNewTeamName(e.target.value)}
                />
              </div>
              <Button 
                onClick={createTeam} 
                disabled={isLoading || !newTeamName.trim()}
              >
                Add Team
              </Button>
            </div>
          </div>
        )}
        
        {teams.length === 0 ? (
          <div className="text-center py-8 text-muted-foreground">
            {isAdmin 
              ? 'No teams created yet. Create your first team above.' 
              : 'You are not assigned to any teams.'}
          </div>
        ) : (
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-medium">Teams</h3>
              <Button 
                variant="outline" 
                size="sm" 
                onClick={loadTeams}
                disabled={isLoading}
              >
                <RefreshCcw className="h-4 w-4 mr-1" />
                Refresh
              </Button>
            </div>
            
            <Tabs 
              value={selectedTeam || undefined} 
              onValueChange={setSelectedTeam as any}
              className="w-full"
            >
              <TabsList className="w-full justify-start overflow-auto">
                {teams.map(team => (
                  <TabsTrigger key={team.id} value={team.id} className="flex-shrink-0">
                    {team.name}
                  </TabsTrigger>
                ))}
              </TabsList>
              
              {teams.map(team => (
                <TabsContent key={team.id} value={team.id} className="space-y-4">
                  <div className="flex justify-between items-center">
                    <h3 className="text-xl font-semibold">{team.name}</h3>
                    <div className="flex gap-2">
                      {isAdmin && (
                        <>
                          <Button 
                            variant="outline" 
                            size="sm"
                            onClick={assignUserToTeam}
                          >
                            <UserPlus className="h-4 w-4 mr-1" />
                            Assign User
                          </Button>
                          <Button 
                            variant="destructive" 
                            size="sm"
                            onClick={() => deleteTeam(team.id)}
                          >
                            <Trash2 className="h-4 w-4 mr-1" />
                            Delete Team
                          </Button>
                        </>
                      )}
                    </div>
                  </div>
                  
                  <div className="border rounded-lg p-4">
                    <h4 className="font-medium mb-3">Team Members</h4>
                    {!teamMembers[team.id] ? (
                      <div className="text-center py-4 text-muted-foreground">
                        Loading team members...
                      </div>
                    ) : teamMembers[team.id].length === 0 ? (
                      <div className="text-center py-4 text-muted-foreground">
                        No members in this team yet.
                      </div>
                    ) : (
                      <div className="space-y-2">
                        {teamMembers[team.id].map(member => (
                          <div key={member.id} className="flex items-center justify-between p-2 bg-muted/50 rounded-md">
                            <div className="flex items-center gap-3">
                              <Avatar>
                                <AvatarFallback>
                                  {member.name.substring(0, 2).toUpperCase()}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <div className="font-medium">{member.name}</div>
                                <div className="text-sm text-muted-foreground">{member.email}</div>
                              </div>
                            </div>
                            <Badge variant={member.role === 'admin' ? "destructive" : "secondary"}>
                              {member.role}
                            </Badge>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </TabsContent>
              ))}
            </Tabs>
          </div>
        )}
      </CardContent>
    </Card>
  );
};

export default TeamManagement;
