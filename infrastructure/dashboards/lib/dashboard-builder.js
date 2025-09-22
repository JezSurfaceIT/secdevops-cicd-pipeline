// Dashboard Builder Library for Grafana
class DashboardBuilder {
  constructor(title, tags = []) {
    this.dashboard = {
      id: null,
      uid: null,
      title,
      tags,
      timezone: 'browser',
      panels: [],
      templating: { list: [] },
      time: { from: 'now-6h', to: 'now' },
      refresh: '1m',
      schemaVersion: 30,
      version: 0
    };
    this.nextPanelId = 1;
    this.currentY = 0;
  }
  
  setUid(uid) {
    this.dashboard.uid = uid;
    return this;
  }
  
  setTime(from, to) {
    this.dashboard.time = { from, to };
    return this;
  }
  
  setRefresh(refresh) {
    this.dashboard.refresh = refresh;
    return this;
  }
  
  addRow(title) {
    this.dashboard.panels.push({
      id: this.nextPanelId++,
      type: 'row',
      title,
      gridPos: { h: 1, w: 24, x: 0, y: this.currentY },
      collapsed: false
    });
    this.currentY += 1;
    return this;
  }
  
  addPanel(config) {
    const panel = {
      id: this.nextPanelId++,
      title: config.title,
      type: config.type || 'graph',
      datasource: config.datasource || 'Prometheus',
      targets: config.targets || [],
      gridPos: config.gridPos || { h: 8, w: 12, x: 0, y: this.currentY },
      options: config.options || {},
      fieldConfig: config.fieldConfig || {}
    };
    
    if (config.transformations) {
      panel.transformations = config.transformations;
    }
    
    this.dashboard.panels.push(panel);
    
    if (!config.gridPos) {
      this.currentY += 8;
    }
    
    return this;
  }
  
  addVariable(variable) {
    this.dashboard.templating.list.push({
      name: variable.name,
      label: variable.label || variable.name,
      type: variable.type || 'query',
      datasource: variable.datasource || 'Prometheus',
      query: variable.query,
      regex: variable.regex || '',
      multi: variable.multi || false,
      includeAll: variable.includeAll || false,
      refresh: variable.refresh || 1,
      sort: variable.sort || 1,
      current: variable.current || {},
      options: variable.options || []
    });
    return this;
  }
  
  build() {
    return this.dashboard;
  }
  
  toJSON() {
    return JSON.stringify({ dashboard: this.dashboard }, null, 2);
  }
}

module.exports = DashboardBuilder;