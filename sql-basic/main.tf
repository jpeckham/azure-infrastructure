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
  administrator_login_password = "myPassw0rd123" #you'll want ot get this into vault then change it!

  tags = {
    environment = "staging"
  }
}
resource "azurerm_sql_database" "test" {
  name                = "sharepoint"
  resource_group_name = "${azurerm_resource_group.test.name}"
  location            = "${azurerm_resource_group.test.location}"
  server_name         = "${azurerm_sql_server.test.name}"

  tags = {
    environment = "staging"
  }
}
resource "azurerm_sql_firewall_rule" "test" {
  name                = "test"
  resource_group_name = "${azurerm_resource_group.test.name}"
  server_name         = "${azurerm_sql_server.test.name}"
  start_ip_address    = "0.0.0.0" #open to everything NOTE BAD!!!! duh
  end_ip_address      = "255.255.255.255"
}