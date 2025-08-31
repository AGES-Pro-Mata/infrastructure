resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = "promata.com.br"
  value   = azurerm_public_ip.main.ip_address
  type    = "A"
  ttl     = 300
}

resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id  
  name    = "api"
  value   = azurerm_public_ip.main.ip_address
  type    = "A"
  ttl     = 300
}