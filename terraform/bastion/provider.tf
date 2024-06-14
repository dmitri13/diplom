terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.117.0"  # Укажите последнюю стабильную версию
    }
  }
}

provider "yandex" {
  token     = var.yandex_cloud_token
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
  zone      = "ru-central1-a"
}
