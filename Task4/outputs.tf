output "med_vm_ip" {
  value = yandex_compute_instance.med.network_interface[0].nat_ip_address
}

output "fin_vm_ip" {
  value = yandex_compute_instance.fin.network_interface[0].nat_ip_address
}

output "ai_vm_ip" {
  value = yandex_compute_instance.ai.network_interface[0].nat_ip_address
}

output "mdm_vm_ip" {
  value = yandex_compute_instance.mdm.network_interface[0].nat_ip_address
}

output "portal_vm_ip" {
  value = yandex_compute_instance.portal.network_interface[0].nat_ip_address
}

output "airflow_vm_ip" {
  value = yandex_compute_instance.airflow.network_interface[0].nat_ip_address
}

output "med_db_host" {
  value = yandex_mdb_postgresql_cluster.med.host[0].fqdn
}

output "fin_db_host" {
  value = yandex_mdb_postgresql_cluster.fin.host[0].fqdn
}

output "mdm_db_host" {
  value = yandex_mdb_postgresql_cluster.mdm.host[0].fqdn
}

output "kafka_brokers" {
  value = tolist(yandex_mdb_kafka_cluster.kafka.host)[0].name
}

output "bucket_name" {
  value = yandex_storage_bucket.lakehouse.bucket
}