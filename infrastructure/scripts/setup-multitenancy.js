// Grafana Multi-tenancy Setup Script
const axios = require('axios');

class GrafanaMultitenancy {
  constructor(apiUrl, apiKey) {
    this.client = axios.create({
      baseURL: apiUrl,
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json'
      }
    });
  }
  
  async createOrganization(name, admins = []) {
    try {
      const org = await this.client.post('/api/orgs', { name });
      
      for (const admin of admins) {
        await this.client.post(`/api/orgs/${org.data.orgId}/users`, {
          loginOrEmail: admin,
          role: 'Admin'
        });
      }
      
      console.log(`Created organization: ${name} (ID: ${org.data.orgId})`);
      return org.data;
    } catch (error) {
      console.error(`Failed to create organization ${name}:`, error.message);
      throw error;
    }
  }
  
  async createTeamFolders(orgId, teams) {
    try {
      // Switch to organization context
      await this.client.post(`/api/user/using/${orgId}`);
      
      for (const team of teams) {
        const folder = await this.client.post('/api/folders', {
          title: team.name,
          uid: team.uid
        });
        
        await this.client.post(`/api/folders/${folder.data.uid}/permissions`, {
          items: [
            {
              teamId: team.id,
              permission: 4  // Edit permission
            }
          ]
        });
        
        console.log(`Created folder for team: ${team.name}`);
      }
    } catch (error) {
      console.error(`Failed to create team folders:`, error.message);
      throw error;
    }
  }
  
  async setupDatasourcePermissions(orgId, datasources) {
    try {
      for (const ds of datasources) {
        await this.client.post(`/api/datasources/${ds.id}/permissions`, {
          enabled: true,
          permissions: ds.permissions
        });
        
        console.log(`Configured permissions for datasource: ${ds.name}`);
      }
    } catch (error) {
      console.error(`Failed to setup datasource permissions:`, error.message);
      throw error;
    }
  }
  
  async setupDefaultDashboards(orgId) {
    try {
      await this.client.post(`/api/user/using/${orgId}`);
      
      // Import default dashboards for the organization
      const dashboards = [
        'infrastructure/kubernetes-overview.json',
        'application/performance.json',
        'business/kpi.json'
      ];
      
      for (const dashboardPath of dashboards) {
        const dashboardData = require(`../dashboards/${dashboardPath}`);
        await this.client.post('/api/dashboards/db', dashboardData);
        console.log(`Imported dashboard: ${dashboardPath}`);
      }
    } catch (error) {
      console.error(`Failed to setup default dashboards:`, error.message);
      throw error;
    }
  }
}

// Main setup function
async function setupMultitenancy(config) {
  const grafana = new GrafanaMultitenancy(config.apiUrl, config.apiKey);
  
  // Create organizations
  for (const org of config.organizations) {
    const orgData = await grafana.createOrganization(org.name, org.admins);
    
    if (org.teams) {
      await grafana.createTeamFolders(orgData.orgId, org.teams);
    }
    
    if (org.datasources) {
      await grafana.setupDatasourcePermissions(orgData.orgId, org.datasources);
    }
    
    if (org.setupDefaultDashboards) {
      await grafana.setupDefaultDashboards(orgData.orgId);
    }
  }
  
  console.log('Multi-tenancy setup completed successfully');
}

// Export for use as module
module.exports = {
  GrafanaMultitenancy,
  setupMultitenancy
};

// Run if called directly
if (require.main === module) {
  const config = {
    apiUrl: process.env.GRAFANA_URL || 'http://localhost:3000',
    apiKey: process.env.GRAFANA_API_KEY || 'your-api-key',
    organizations: [
      {
        name: 'Development Team',
        admins: ['dev-admin@oversight.com'],
        teams: [
          { id: 1, name: 'Frontend', uid: 'frontend' },
          { id: 2, name: 'Backend', uid: 'backend' }
        ],
        setupDefaultDashboards: true
      },
      {
        name: 'Operations Team',
        admins: ['ops-admin@oversight.com'],
        teams: [
          { id: 3, name: 'SRE', uid: 'sre' },
          { id: 4, name: 'DevOps', uid: 'devops' }
        ],
        setupDefaultDashboards: true
      }
    ]
  };
  
  setupMultitenancy(config).catch(console.error);
}