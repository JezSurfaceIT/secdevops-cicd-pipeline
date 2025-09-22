# Grafana Dashboard Infrastructure
# Following IaC-first approach with e2e-* naming convention

# Grafana namespace already created in prometheus.tf
# Using the same monitoring namespace = "monitoring"

# Grafana ConfigMap for grafana.ini
resource "kubernetes_config_map" "grafana_config" {
  metadata {
    name      = "grafana-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "grafana.ini" = templatefile("${path.module}/configs/grafana.ini", {
      domain              = var.grafana_domain
      environment         = var.environment
      azure_tenant_id     = var.azure_tenant_id
      azure_client_id     = var.oauth_client_id
      azure_client_secret = var.oauth_client_secret
      db_host            = var.grafana_db_host
      db_password        = var.grafana_db_password
    })
  }
}

# Grafana Data Sources ConfigMap
resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_datasource = "1"
    }
  }
  
  data = {
    "datasources.yaml" = templatefile("${path.module}/configs/datasources.yaml", {
      prometheus_url     = "http://prometheus:9090"
      thanos_url        = "http://thanos-query:9090"
      loki_url          = "http://loki-gateway:3100"
      azure_client_id   = var.azure_client_id
      azure_tenant_id   = var.azure_tenant_id
      azure_subscription_id = var.azure_subscription_id
      azure_client_secret = var.azure_client_secret
      db_host           = var.grafana_db_host
      db_reader_password = var.grafana_db_reader_password
    })
  }
}

# Dashboard Provider ConfigMap
resource "kubernetes_config_map" "grafana_dashboard_provider" {
  metadata {
    name      = "grafana-dashboard-provider"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "provider.yaml" = file("${path.module}/configs/dashboard-provider.yaml")
  }
}

# Grafana Service Account
resource "kubernetes_service_account" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# Grafana Role
resource "kubernetes_role" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "watch", "list"]
  }
}

# Grafana RoleBinding
resource "kubernetes_role_binding" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.grafana.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.grafana.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# Grafana StatefulSet for HA
resource "kubernetes_stateful_set" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    
    annotations = {
      "azure-resource-group" = "e2e-${var.environment}-${var.region}-secops-monitoring-001"
    }
  }
  
  spec {
    replicas = var.grafana_replicas
    
    service_name = "grafana-headless"
    
    selector {
      match_labels = {
        app = "grafana"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "grafana"
        }
        
        annotations = {
          checksum_config = sha256(kubernetes_config_map.grafana_config.data["grafana.ini"])
          checksum_datasources = sha256(kubernetes_config_map.grafana_datasources.data["datasources.yaml"])
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.grafana.metadata[0].name
        
        security_context {
          fs_group = 472
          run_as_user = 472
          run_as_non_root = true
        }
        
        init_container {
          name  = "init-chown-data"
          image = "busybox:1.35"
          
          command = ["chown", "-R", "472:472", "/var/lib/grafana"]
          
          volume_mount {
            name       = "storage"
            mount_path = "/var/lib/grafana"
          }
          
          security_context {
            run_as_user = 0
          }
        }
        
        container {
          name  = "grafana"
          image = "grafana/grafana:${var.grafana_version}"
          
          port {
            container_port = 3000
            name          = "http"
            protocol      = "TCP"
          }
          
          port {
            container_port = 9094
            name          = "gossip"
            protocol      = "TCP"
          }
          
          env {
            name  = "GF_PATHS_DATA"
            value = "/var/lib/grafana"
          }
          
          env {
            name  = "GF_PATHS_LOGS"
            value = "/var/log/grafana"
          }
          
          env {
            name  = "GF_PATHS_PLUGINS"
            value = "/var/lib/grafana/plugins"
          }
          
          env {
            name  = "GF_PATHS_PROVISIONING"
            value = "/etc/grafana/provisioning"
          }
          
          env {
            name = "GF_SECURITY_ADMIN_USER"
            value = var.grafana_admin_user
          }
          
          env {
            name = "GF_SECURITY_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.grafana_admin.metadata[0].name
                key  = "admin-password"
              }
            }
          }
          
          env {
            name  = "GF_INSTALL_PLUGINS"
            value = var.grafana_plugins
          }
          
          volume_mount {
            name       = "config"
            mount_path = "/etc/grafana/grafana.ini"
            sub_path   = "grafana.ini"
          }
          
          volume_mount {
            name       = "storage"
            mount_path = "/var/lib/grafana"
          }
          
          volume_mount {
            name       = "datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }
          
          volume_mount {
            name       = "dashboard-provider"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }
          
          volume_mount {
            name       = "dashboards"
            mount_path = "/var/lib/grafana/dashboards"
          }
          
          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            
            limits = {
              cpu    = "1000m"
              memory = "1024Mi"
            }
          }
          
          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            
            initial_delay_seconds = 60
            timeout_seconds       = 30
            failure_threshold     = 10
          }
          
          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
          }
        }
        
        volume {
          name = "config"
          
          config_map {
            name = kubernetes_config_map.grafana_config.metadata[0].name
          }
        }
        
        volume {
          name = "datasources"
          
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }
        
        volume {
          name = "dashboard-provider"
          
          config_map {
            name = kubernetes_config_map.grafana_dashboard_provider.metadata[0].name
          }
        }
        
        volume {
          name = "dashboards"
          
          config_map {
            name = kubernetes_config_map.grafana_dashboards.metadata[0].name
          }
        }
        
        affinity {
          pod_anti_affinity {
            required_during_scheduling_ignored_during_execution {
              label_selector {
                match_expressions {
                  key      = "app"
                  operator = "In"
                  values   = ["grafana"]
                }
              }
              topology_key = "kubernetes.io/hostname"
            }
          }
        }
      }
    }
    
    volume_claim_template {
      metadata {
        name = "storage"
      }
      
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "managed-premium"
        
        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }
}

# Grafana Service
resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    selector = {
      app = "grafana"
    }
    
    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }
    
    type = "ClusterIP"
    
    session_affinity = "ClientIP"
    
    session_affinity_config {
      client_ip {
        timeout_seconds = 10800
      }
    }
  }
}

# Headless Service for StatefulSet
resource "kubernetes_service" "grafana_headless" {
  metadata {
    name      = "grafana-headless"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    cluster_ip = "None"
    
    selector = {
      app = "grafana"
    }
    
    port {
      name        = "http"
      port        = 3000
      target_port = 3000
    }
  }
}

# Grafana Ingress
resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    
    annotations = {
      "cert-manager.io/cluster-issuer"           = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/affinity"     = "cookie"
      "nginx.ingress.kubernetes.io/affinity-mode" = "persistent"
    }
  }
  
  spec {
    ingress_class_name = "nginx"
    
    tls {
      hosts       = [var.grafana_domain]
      secret_name = "grafana-tls"
    }
    
    rule {
      host = var.grafana_domain
      
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          
          backend {
            service {
              name = kubernetes_service.grafana.metadata[0].name
              
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}

# Grafana Admin Secret
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    admin-user     = base64encode(var.grafana_admin_user)
    admin-password = base64encode(var.grafana_admin_password)
  }
}

# Dashboard ConfigMap (will hold all dashboards)
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }
  
  data = {
    for file in fileset("${path.module}/dashboards", "**/*.json") :
    replace(file, "/", "-") => file("${path.module}/dashboards/${file}")
  }
}

# PostgreSQL Database for Grafana (using Azure Database for PostgreSQL)
resource "azurerm_postgresql_server" "grafana" {
  name                = "e2e-${var.environment}-${var.region}-grafana-psql"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  
  sku_name = "GP_Gen5_2"
  
  storage_mb                   = 51200
  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled           = true
  
  administrator_login          = "grafanaadmin"
  administrator_login_password = var.grafana_db_password
  version                     = "11"
  ssl_enforcement_enabled     = true
  
  tags = {
    environment = var.environment
    component   = "monitoring"
    managed_by  = "terraform"
  }
}

# Grafana Database
resource "azurerm_postgresql_database" "grafana" {
  name                = "grafana"
  resource_group_name = data.azurerm_resource_group.main.name
  server_name         = azurerm_postgresql_server.grafana.name
  charset            = "UTF8"
  collation          = "English_United States.1252"
}