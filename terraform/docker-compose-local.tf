# Local Docker Infrastructure (Jenkins, Monitoring, SonarQube)

resource "docker_network" "monitoring" {
  name = "monitoring-network"
}

resource "docker_network" "jenkins" {
  name = "jenkins-network"
}

# Prometheus Container
resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = "prom/prometheus:latest"
  
  ports {
    internal = 9090
    external = 9091
  }
  
  volumes {
    host_path      = "/tmp/monitoring/prometheus"
    container_path = "/etc/prometheus"
  }
  
  volumes {
    host_path      = "/tmp/prometheus-data"
    container_path = "/prometheus"
  }
  
  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--web.console.libraries=/etc/prometheus/console_libraries",
    "--web.console.templates=/etc/prometheus/consoles",
    "--web.enable-lifecycle"
  ]
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  restart = "unless-stopped"
}

# Grafana Container
resource "docker_container" "grafana" {
  name  = "grafana"
  image = "grafana/grafana:latest"
  
  ports {
    internal = 3000
    external = 3000
  }
  
  volumes {
    host_path      = "/tmp/grafana-data"
    container_path = "/var/lib/grafana"
  }
  
  env = [
    "GF_SECURITY_ADMIN_PASSWORD=${var.grafana_admin_password}",
    "GF_INSTALL_PLUGINS=redis-datasource,cloudwatch,azure-monitor"
  ]
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  restart = "unless-stopped"
}

# Alertmanager Container
resource "docker_container" "alertmanager" {
  name  = "alertmanager"
  image = "prom/alertmanager:latest"
  
  ports {
    internal = 9093
    external = 9093
  }
  
  volumes {
    host_path      = "/tmp/monitoring/alertmanager"
    container_path = "/etc/alertmanager"
  }
  
  volumes {
    host_path      = "/tmp/alertmanager-data"
    container_path = "/alertmanager"
  }
  
  command = [
    "--config.file=/etc/alertmanager/config.yml",
    "--storage.path=/alertmanager"
  ]
  
  networks_advanced {
    name = docker_network.monitoring.name
  }
  
  restart = "unless-stopped"
}

# Jenkins Container
resource "docker_container" "jenkins" {
  name  = "jenkins"
  image = "jenkins/jenkins:lts"
  
  ports {
    internal = 8080
    external = 8080
  }
  
  ports {
    internal = 50000
    external = 50000
  }
  
  volumes {
    host_path      = "/tmp/jenkins_home"
    container_path = "/var/jenkins_home"
  }
  
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  
  env = [
    "JENKINS_OPTS=--prefix=/jenkins",
    "JAVA_OPTS=-Djenkins.install.runSetupWizard=false"
  ]
  
  networks_advanced {
    name = docker_network.jenkins.name
  }
  
  restart = "unless-stopped"
}