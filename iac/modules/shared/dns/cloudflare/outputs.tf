# Outputs for Cloudflare DNS Module

output "root_record_hostname" {
  description = "Hostname do registro raiz"
  value       = try(cloudflare_record.root[0].hostname, null)
}

output "www_record_hostname" {
  description = "Hostname do registro WWW"
  value       = try(cloudflare_record.www[0].hostname, null)
}

output "api_record_hostname" {
  description = "Hostname do registro API"
  value       = try(cloudflare_record.api[0].hostname, null)
}

output "analytics_record_hostname" {
  description = "Hostname do registro Analytics"
  value       = try(cloudflare_record.analytics[0].hostname, null)
}

output "metabase_record_hostname" {
  description = "Hostname do registro Metabase"
  value       = try(cloudflare_record.metabase[0].hostname, null)
}

output "dns_records_created" {
  description = "Lista de registros DNS criados"
  value = concat(
    var.frontend_endpoint != "" ? ["${var.domain_name}", "www.${var.domain_name}"] : [],
    var.backend_ip != "" ? ["api.${var.domain_name}", "analytics.${var.domain_name}", "metabase.${var.domain_name}"] : [],
    var.backend_ip != "" && var.create_traefik_record ? ["traefik.${var.domain_name}"] : []
  )
}
