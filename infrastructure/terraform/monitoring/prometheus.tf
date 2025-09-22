# Prometheus Infrastructure Deployment
# Following IaC-first approach with e2e-* naming convention

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "e2e-dev-eus-secops-terraform-001"
    storage_account_name = "e2edevtfstate"
    container_name      = "tfstate"
    key                = "monitoring/prometheus.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
  client_key            = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key            = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  }
}

# Data sources
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    
    labels = {
      environment = var.environment
      managed_by  = "terraform"
      component   = "monitoring"
    }
  }
}

# Prometheus ConfigMap
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "prometheus.yml" = templatefile("${path.module}/configs/prometheus.yml", {
      azure_subscription_id = var.azure_subscription_id
      azure_tenant_id      = var.azure_tenant_id
      azure_client_id      = var.azure_client_id
      azure_client_secret  = var.azure_client_secret
      environment          = var.environment
      region              = var.region
    })
  }
}

# Prometheus Rules ConfigMap
resource "kubernetes_config_map" "prometheus_rules" {
  metadata {
    name      = "prometheus-rules"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "recording-rules.yml" = file("${path.module}/configs/recording-rules.yml")
    "alerting-rules.yml"  = file("${path.module}/configs/alerting-rules.yml")
  }
}

# Prometheus Auth ConfigMap
resource "kubernetes_config_map" "prometheus_auth" {
  metadata {
    name      = "prometheus-auth"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "web-config.yml" = file("${path.module}/configs/web-config.yml")
  }
}

# Service Account for Prometheus
resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# ClusterRole for Prometheus
resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }
  
  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/metrics", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get"]
  }
  
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }
  
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for Prometheus
resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }
  
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }
  
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
}

# TLS Certificate Secret
resource "kubernetes_secret" "prometheus_tls" {
  metadata {
    name      = "prometheus-tls"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  type = "kubernetes.io/tls"
  
  data = {
    "tls.crt" = var.prometheus_tls_cert
    "tls.key" = var.prometheus_tls_key
  }
}

# Thanos Object Storage Secret
resource "kubernetes_secret" "thanos_objstore_config" {
  metadata {
    name      = "thanos-objstore-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  data = {
    "objstore.yml" = templatefile("${path.module}/configs/thanos-objstore.yml", {
      azure_storage_account = var.azure_storage_account
      azure_storage_key    = var.azure_storage_key
    })
  }
}

# Prometheus StatefulSet
resource "kubernetes_stateful_set" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    
    annotations = {
      "azure-resource-group" = "e2e-${var.environment}-${var.region}-secops-monitoring-001"
    }
  }
  
  spec {
    replicas = var.prometheus_replicas
    
    service_name = "prometheus-headless"
    
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
        
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "9090"
        }
      }
      
      spec {
        service_account_name = kubernetes_service_account.prometheus.metadata[0].name
        
        container {
          name  = "prometheus"
          image = "prom/prometheus:${var.prometheus_version}"
          
          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=15d",
            "--storage.tsdb.retention.size=50GB",
            "--web.enable-lifecycle",
            "--web.enable-admin-api",
            "--web.config.file=/etc/prometheus/web-config.yml"
          ]
          
          port {
            container_port = 9090
            name          = "web"
          }
          
          resources {
            requests = {
              memory = "2Gi"
              cpu    = "1"
            }
            
            limits = {
              memory = "4Gi"
              cpu    = "2"
            }
          }
          
          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
            read_only  = true
          }
          
          volume_mount {
            name       = "storage"
            mount_path = "/prometheus"
          }
          
          volume_mount {
            name       = "rules"
            mount_path = "/etc/prometheus/rules"
            read_only  = true
          }
          
          volume_mount {
            name       = "auth"
            mount_path = "/etc/prometheus/web-config.yml"
            sub_path   = "web-config.yml"
            read_only  = true
          }
          
          volume_mount {
            name       = "tls"
            mount_path = "/etc/prometheus/certs"
            read_only  = true
          }
          
          liveness_probe {
            http_get {
              path   = "/-/healthy"
              port   = 9090
              scheme = "HTTPS"
            }
            
            initial_delay_seconds = 30
            period_seconds       = 10
          }
          
          readiness_probe {
            http_get {
              path   = "/-/ready"
              port   = 9090
              scheme = "HTTPS"
            }
            
            initial_delay_seconds = 30
            period_seconds       = 10
          }
        }
        
        volume {
          name = "config"
          
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }
        
        volume {
          name = "rules"
          
          config_map {
            name = kubernetes_config_map.prometheus_rules.metadata[0].name
          }
        }
        
        volume {
          name = "auth"
          
          config_map {
            name = kubernetes_config_map.prometheus_auth.metadata[0].name
          }
        }
        
        volume {
          name = "tls"
          
          secret {
            secret_name = kubernetes_secret.prometheus_tls.metadata[0].name
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
            storage = "100Gi"
          }
        }
      }
    }
  }
}

# Prometheus Service
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    selector = {
      app = "prometheus"
    }
    
    port {
      name        = "web"
      port        = 9090
      target_port = 9090
    }
    
    type = "ClusterIP"
  }
}

# Headless service for StatefulSet
resource "kubernetes_service" "prometheus_headless" {
  metadata {
    name      = "prometheus-headless"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    cluster_ip = "None"
    
    selector = {
      app = "prometheus"
    }
    
    port {
      name        = "web"
      port        = 9090
      target_port = 9090
    }
  }
}

# Thanos Receiver StatefulSet
resource "kubernetes_stateful_set" "thanos_receiver" {
  metadata {
    name      = "thanos-receiver"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    replicas = 3
    
    service_name = "thanos-receiver-headless"
    
    selector {
      match_labels = {
        app = "thanos-receiver"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "thanos-receiver"
        }
      }
      
      spec {
        container {
          name  = "thanos-receiver"
          image = "quay.io/thanos/thanos:${var.thanos_version}"
          
          args = [
            "receive",
            "--grpc-address=0.0.0.0:10901",
            "--http-address=0.0.0.0:10902",
            "--remote-write.address=0.0.0.0:19291",
            "--objstore.config-file=/etc/thanos/objstore.yml",
            "--tsdb.path=/var/thanos/receive",
            "--tsdb.retention=7d",
            "--label=receive_replica=\"$(POD_NAME)\"",
            "--label=receive=\"true\""
          ]
          
          env {
            name = "POD_NAME"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          
          port {
            container_port = 10901
            name          = "grpc"
          }
          
          port {
            container_port = 10902
            name          = "http"
          }
          
          port {
            container_port = 19291
            name          = "remote-write"
          }
          
          volume_mount {
            name       = "objstore-config"
            mount_path = "/etc/thanos"
          }
          
          volume_mount {
            name       = "data"
            mount_path = "/var/thanos/receive"
          }
          
          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            
            limits = {
              memory = "2Gi"
              cpu    = "1"
            }
          }
        }
        
        volume {
          name = "objstore-config"
          
          secret {
            secret_name = kubernetes_secret.thanos_objstore_config.metadata[0].name
          }
        }
      }
    }
    
    volume_claim_template {
      metadata {
        name = "data"
      }
      
      spec {
        access_modes = ["ReadWriteOnce"]
        
        resources {
          requests = {
            storage = "100Gi"
          }
        }
      }
    }
  }
}

# OAuth2 Proxy Deployment
resource "kubernetes_deployment" "oauth2_proxy" {
  metadata {
    name      = "oauth2-proxy"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    replicas = 2
    
    selector {
      match_labels = {
        app = "oauth2-proxy"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "oauth2-proxy"
        }
      }
      
      spec {
        container {
          name  = "oauth2-proxy"
          image = "quay.io/oauth2-proxy/oauth2-proxy:${var.oauth2_proxy_version}"
          
          args = [
            "--provider=azure",
            "--azure-tenant=${var.azure_tenant_id}",
            "--client-id=${var.oauth_client_id}",
            "--client-secret=${var.oauth_client_secret}",
            "--upstream=http://prometheus:9090",
            "--http-address=0.0.0.0:4180",
            "--cookie-secure=true",
            "--cookie-secret=${var.cookie_secret}",
            "--email-domain=${var.email_domain}"
          ]
          
          port {
            container_port = 4180
            name          = "http"
          }
          
          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }
        }
      }
    }
  }
}

# Network Policy for Prometheus
resource "kubernetes_network_policy" "prometheus_netpol" {
  metadata {
    name      = "prometheus-netpol"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  
  spec {
    pod_selector {
      match_labels = {
        app = "prometheus"
      }
    }
    
    policy_types = ["Ingress", "Egress"]
    
    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "grafana"
          }
        }
      }
      
      from {
        pod_selector {
          match_labels = {
            app = "oauth2-proxy"
          }
        }
      }
      
      ports {
        port     = "9090"
        protocol = "TCP"
      }
    }
    
    egress {
      to {
        pod_selector {}
      }
      
      to {
        namespace_selector {}
      }
      
      ports {
        port     = "443"
        protocol = "TCP"
      }
      
      ports {
        port     = "9090"
        protocol = "TCP"
      }
      
      ports {
        port     = "19291"
        protocol = "TCP"
      }
    }
  }
}

# Azure Storage Account for Thanos
resource "azurerm_storage_account" "thanos" {
  name                     = "e2e${var.environment}thanos"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                = data.azurerm_resource_group.main.location
  account_tier            = "Standard"
  account_replication_type = "GRS"
  
  tags = {
    environment = var.environment
    component   = "monitoring"
    managed_by  = "terraform"
  }
}

# Storage Container for Thanos metrics
resource "azurerm_storage_container" "thanos_metrics" {
  name                  = "thanos-metrics"
  storage_account_name  = azurerm_storage_account.thanos.name
  container_access_type = "private"
}