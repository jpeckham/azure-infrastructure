resource "azurerm_resource_group" "test" {
  name     = "jdp-sql-rg"
  location = "Central US"
}

output "sql_domain_name" {
    value = "${azurerm_sql_server.test.fully_qualified_domain_name}"
}

resource "azurerm_sql_server" "test" {
  name                         = "jdp-sql-server"
  resource_group_name          = "${azurerm_resource_group.test.name}"
  location                     = "${azurerm_resource_group.test.location}"
  version                      = "12.0"
  administrator_login          = "jdpeckham"
  administrator_login_password = "myPassw0rd123"

  tags = {
    environment = "staging"
  }
}

resource "azurerm_sql_firewall_rule" "test" {
  name                = "office"
  resource_group_name = "${azurerm_resource_group.test.name}"
  server_name         = "${azurerm_sql_server.test.name}"
  start_ip_address    = "192.168.1.100" #replace with your external IP
  end_ip_address      = "192.168.1.100"
}