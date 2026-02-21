terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.120"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

# ----- Сеть -----
resource "yandex_vpc_network" "network" {
  name = "future2-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "future2-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = [var.subnet_cidr]
}

# ----- Сервисный аккаунт для Object Storage (Lakehouse) -----
resource "yandex_iam_service_account" "storage_sa" {
  name = "storage-sa"
}

# Назначаем роль storage.admin на папку
resource "yandex_resourcemanager_folder_iam_member" "storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.storage_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "storage_key" {
  service_account_id = yandex_iam_service_account.storage_sa.id
}

# ----- Object Storage (Lakehouse) -----
resource "yandex_storage_bucket" "lakehouse" {
  bucket     = "future2-lakehouse-${var.folder_id}"
  access_key = yandex_iam_service_account_static_access_key.storage_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage_key.secret_key
  force_destroy = true  # разрешает удаление непустого бакета
}

# ----- Managed PostgreSQL для Медицины -----
resource "yandex_mdb_postgresql_cluster" "med" {
  name        = "med-postgres"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.network.id

  config {
    version = 15
    resources {
      resource_preset_id = "b2.medium"
      disk_size          = 10
      disk_type_id       = "network-hdd"
    }
  }

  host {
    zone             = var.zone
    subnet_id        = yandex_vpc_subnet.subnet.id
    assign_public_ip = false
  }
}

resource "yandex_mdb_postgresql_user" "med" {
  cluster_id = yandex_mdb_postgresql_cluster.med.id
  name       = "meduser"
  password   = var.med_db_password
}

resource "yandex_mdb_postgresql_database" "med" {
  cluster_id = yandex_mdb_postgresql_cluster.med.id
  name       = "meddb"
  owner      = yandex_mdb_postgresql_user.med.name
  depends_on = [yandex_mdb_postgresql_user.med]
}

# ----- Managed PostgreSQL для Финтеха -----
resource "yandex_mdb_postgresql_cluster" "fin" {
  name        = "fin-postgres"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.network.id

  config {
    version = 15
    resources {
      resource_preset_id = "b2.medium"
      disk_size          = 10
      disk_type_id       = "network-hdd"
    }
  }

  host {
    zone             = var.zone
    subnet_id        = yandex_vpc_subnet.subnet.id
    assign_public_ip = false
  }
}

resource "yandex_mdb_postgresql_user" "fin" {
  cluster_id = yandex_mdb_postgresql_cluster.fin.id
  name       = "finuser"
  password   = var.fin_db_password
}

resource "yandex_mdb_postgresql_database" "fin" {
  cluster_id = yandex_mdb_postgresql_cluster.fin.id
  name       = "findb"
  owner      = yandex_mdb_postgresql_user.fin.name
  depends_on = [yandex_mdb_postgresql_user.fin]
}

# ----- Managed PostgreSQL для MDM -----
resource "yandex_mdb_postgresql_cluster" "mdm" {
  name        = "mdm-postgres"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.network.id

  config {
    version = 15
    resources {
      resource_preset_id = "b2.medium"
      disk_size          = 10
      disk_type_id       = "network-hdd"
    }
  }

  host {
    zone             = var.zone
    subnet_id        = yandex_vpc_subnet.subnet.id
    assign_public_ip = false
  }
}

resource "yandex_mdb_postgresql_user" "mdm" {
  cluster_id = yandex_mdb_postgresql_cluster.mdm.id
  name       = "mdmuser"
  password   = var.mdm_db_password
}

resource "yandex_mdb_postgresql_database" "mdm" {
  cluster_id = yandex_mdb_postgresql_cluster.mdm.id
  name       = "mdmdb"
  owner      = yandex_mdb_postgresql_user.mdm.name
  depends_on = [yandex_mdb_postgresql_user.mdm]
}

# ----- Managed Kafka (Event Bus) -----
resource "yandex_mdb_kafka_cluster" "kafka" {
  name        = "future2-kafka"
  environment = "PRODUCTION"
  network_id  = yandex_vpc_network.network.id

  config {
    version          = "3.6"
    brokers_count    = 1
    zones            = [var.zone]
    assign_public_ip = false
    kafka {
      resources {
        resource_preset_id = "b2.medium"
        disk_size          = 10
        disk_type_id       = "network-hdd"
      }
    }
  }

  subnet_ids = [yandex_vpc_subnet.subnet.id]
}

# ----- Образ для ВМ -----
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# ----- ВМ для сервисов Медицины -----
resource "yandex_compute_instance" "med" {
  name        = "med-services"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    ssh-authorized-keys:\n      - ${var.ssh_public_key}\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    shell: /bin/bash"
  }
}

# ----- ВМ для сервисов Финтеха -----
resource "yandex_compute_instance" "fin" {
  name        = "fin-services"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    ssh-authorized-keys:\n      - ${var.ssh_public_key}\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    shell: /bin/bash"
  }
}

# ----- ВМ для ИИ-сервисов -----
resource "yandex_compute_instance" "ai" {
  name        = "ai-services"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    ssh-authorized-keys:\n      - ${var.ssh_public_key}\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    shell: /bin/bash"
  }
}

# ----- ВМ для MDM -----
resource "yandex_compute_instance" "mdm" {
  name        = "mdm-services"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    ssh-authorized-keys:\n      - ${var.ssh_public_key}\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    shell: /bin/bash"
  }
}

# ----- ВМ для Портала самообслуживания (Web, Dremio, DataHub) -----
resource "yandex_compute_instance" "portal" {
  name        = "portal-services"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 4    # Dremio требует больше RAM
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 30
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    ssh-authorized-keys:\n      - ${var.ssh_public_key}\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    shell: /bin/bash"
  }
}

# ----- ВМ для Airflow (вместо managed-кластера) -----
resource "yandex_compute_instance" "airflow" {
  name        = "airflow-vm"
  platform_id = "standard-v2"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true
  }

  metadata = {
    user-data = "#cloud-config\nusers:\n  - name: ubuntu\n    ssh-authorized-keys:\n      - ${var.ssh_public_key}\n    sudo: ['ALL=(ALL) NOPASSWD:ALL']\n    shell: /bin/bash"
  }
}