variable "network_id" {
  description = "Network ID for Yandex Cloud"
  type        = string
}

variable "private_subnet_a_id" {
  description = "Private Subnet A ID for Yandex Cloud"
  type        = string
}

variable "private_subnet_b_id" {
  description = "Private Subnet B ID for Yandex Cloud"
  type        = string
}

variable "public_subnet_id" {
  description = "Public Subnet ID for Yandex Cloud"
  type        = string
}

variable "nat_ip_address" {
  description = "NAT IP Address"
  type        = string
}

variable "image_id" {
  description = "Image ID for Ubuntu 20.04"
  type        = string
  default     = "fd801iv1gjj2mbvjolim"
}

resource "yandex_compute_instance" "nat_instance" {
  name         = "nat-instance"
  platform_id  = "standard-v1"
  resources {
    cores  = 2
    memory = 2
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 30
    }
  }
  network_interface {
    subnet_id = var.public_subnet_id
    nat       = true
  }
  metadata = {
    user-data = <<-EOF
                #cloud-config
                runcmd:
                  - echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
                  - sysctl -p /etc/sysctl.conf
                  - iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
                EOF
  }
}

resource "yandex_vpc_route_table" "private_a_route_table" {
  network_id = var.network_id
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat_instance.network_interface.0.ip_address
  }
}

resource "yandex_vpc_route_table" "private_b_route_table" {
  network_id = var.network_id
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat_instance.network_interface.0.ip_address
  }
}

resource "yandex_vpc_subnet" "private_subnet_a_new" {
  name           = "private-subnet-a-new"
  zone           = "ru-central1-a"
  network_id     = var.network_id
  v4_cidr_blocks = ["10.0.10.0/24"]
  route_table_id = yandex_vpc_route_table.private_a_route_table.id
}

resource "yandex_vpc_subnet" "private_subnet_b_new" {
  name           = "private-subnet-b-new"
  zone           = "ru-central1-b"
  network_id     = var.network_id
  v4_cidr_blocks = ["10.0.20.0/24"]
  route_table_id = yandex_vpc_route_table.private_b_route_table.id
}

resource "yandex_compute_instance" "web_a" {
  name         = "web-server-a"
  platform_id  = "standard-v1"
  zone         = "ru-central1-a"
  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 30
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.private_subnet_a_new.id
    nat       = false
  }
  metadata = {
    ssh-keys = "admin:${file("/root/terraform/id_rsa_ansible.pub")}"
  }
  scheduling_policy {
    preemptible = true
  }
  hostname = "web-server-a.ru-central1.internal"
}

resource "yandex_compute_instance" "web_b" {
  name         = "web-server-b"
  platform_id  = "standard-v1"
  zone         = "ru-central1-b"
  resources {
    cores         = 2
    core_fraction = 20
    memory        = 2
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 30
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.private_subnet_b_new.id
    nat       = false
  }
  metadata = {
    ssh-keys = "admin:${file("/root/terraform/id_rsa_ansible.pub")}"
  }
  scheduling_policy {
    preemptible = true
  }
  hostname = "web-server-b.ru-central1.internal"
}

resource "yandex_compute_instance" "zabbix" {
  name         = "zabbix-server"
  platform_id  = "standard-v1"
  zone         = "ru-central1-a"
  resources {
    cores  = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 30
    }
  }
  network_interface {
    subnet_id = var.public_subnet_id
    nat       = true
  }
  hostname = "zabbix-server-a.ru-central1.internal"
  metadata = {
    ssh-keys = "admin:${file("/root/terraform/id_rsa_ansible.pub")}"
  }
}

resource "yandex_compute_instance" "elasticsearch" {
  name         = "elasticsearch-server"
  platform_id  = "standard-v1"
  zone         = "ru-central1-b"
  resources {
    cores  = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 30
    }
  }
  network_interface {
    subnet_id = yandex_vpc_subnet.private_subnet_b_new.id
    nat       = false
  }
  hostname = "elasticsearch-server-b.ru-central1.internal"
  metadata = {
    ssh-keys = "admin:${file("/root/terraform/id_rsa_ansible.pub")}"
  }
}

resource "yandex_compute_instance" "kibana" {
  name         = "kibana-server"
  platform_id  = "standard-v1"
  zone         = "ru-central1-a"
  resources {
    cores  = 2
    memory = 4
  }
  boot_disk {
    initialize_params {
      image_id = var.image_id
      size     = 30
    }
  }
  network_interface {
    subnet_id = var.public_subnet_id
    nat       = true
  }
  hostname = "kibana-server-a.ru-central1.internal"
  metadata = {
    ssh-keys = "admin:${file("/root/terraform/id_rsa_ansible.pub")}"
  }
}

resource "yandex_alb_target_group" "web_servers" {
  name = "web-servers-target-group"

  target {
    ip_address = yandex_compute_instance.web_a.network_interface.0.ip_address
    subnet_id  = yandex_vpc_subnet.private_subnet_a_new.id
  }

  target {
    ip_address = yandex_compute_instance.web_b.network_interface.0.ip_address
    subnet_id  = yandex_vpc_subnet.private_subnet_b_new.id
  }
}

resource "yandex_alb_backend_group" "web_backends" {
  name = "web-backend-group"

  http_backend {
    name             = "web-backend"
    port             = 80
    target_group_ids = [yandex_alb_target_group.web_servers.id]
    healthcheck {
      interval            = "2s"
      timeout             = "1s"
      unhealthy_threshold = 2
      healthy_threshold   = 2
      http_healthcheck {
        path = "/"
      }
    }
  }
}

resource "yandex_alb_http_router" "web_router" {
  name = "web-http-router"

  labels = {
    env = "prod"
  }
}

resource "yandex_alb_load_balancer" "web_lb" {
  name       = "web-load-balancer"
  network_id = var.network_id

  allocation_policy {
    location {
      zone_id   = "ru-central1-a"
      subnet_id = var.public_subnet_id
    }
  }

  listener {
    name = "http-listener"
    endpoint {
      address {
        external_ipv4_address {
        }
      }
      ports = [80]
    }
    http {
      handler {
        http_router_id = yandex_alb_http_router.web_router.id
      }
    }
  }
}

output "web_a_ip" {
  value = yandex_compute_instance.web_a.network_interface.0.ip_address
}

output "web_b_ip" {
  value = yandex_compute_instance.web_b.network_interface.0.ip_address
}

output "zabbix_ip" {
  value = yandex_compute_instance.zabbix.network_interface.0.ip_address
}

output "elasticsearch_ip" {
  value = yandex_compute_instance.elasticsearch.network_interface.0.ip_address
}

output "kibana_ip" {
  value = yandex_compute_instance.kibana.network_interface.0.ip_address
}

output "lb_public_ip" {
  value = yandex_alb_load_balancer.web_lb.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
}
