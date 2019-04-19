variable "prefix" {
  default = "jdp-usa"
}
data "azurerm_client_config" "current" {}

output "account_id" {
  value = "${data.azurerm_client_config.current.service_principal_application_id}"
}
output "tenant_id" {
  value = "${data.azurerm_client_config.current.tenant_id}"
}
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = "Central US"
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}-nic"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.prefix}-vm"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.main.id}"]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true


  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_windows_config {
    provision_vm_agent = true
    enable_automatic_upgrades = false
    timezone = "Central Standard Time"
  }
  tags = {
    environment = "staging"
  }
}

# windows box with win rm
resource "azurerm_key_vault" "test" {
  name                        = "${var.prefix}-test-vault"
  location                    = "${azurerm_resource_group.main.location}"
  resource_group_name         = "${azurerm_resource_group.main.name}"
  enabled_for_disk_encryption = true
  tenant_id                   = "${data.azurerm_client_config.current.tenant_id}"

  sku {
    name = "standard"
  }

  access_policy {
    tenant_id = "${data.azurerm_client_config.current.tenant_id}"
    object_id = "${data.azurerm_client_config.current.service_principal_object_id}"

    key_permissions = [
      "get",
    ]

    secret_permissions = [
      "get",
    ]

    storage_permissions = [
      "get",
    ]
  }

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "test" {
  name                = "acceptanceTestNetworkInterface1"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
  }

  tags = {
    environment = "staging"
  }
}

 resource "azurerm_key_vault_certificate" "test" {
   name      = "${var.prefix}-cert"
   # vault_uri = "${azurerm_key_vault.test.vault_uri}"
   key_vault_id = "${azurerm_key_vault.test.id}"

   certificate_policy {
     issuer_parameters {
       name = "Self"
     }

     key_properties {
       exportable = true
       key_size   = 2048
       key_type   = "RSA"
       reuse_key  = true
     }

     lifetime_action {
       action {
         action_type = "AutoRenew"
       }

       trigger {
         days_before_expiry = 30
       }
     }

     secret_properties {
       content_type = "application/x-pkcs12"
     }

     x509_certificate_properties {
       key_usage = [
         "cRLSign",
         "dataEncipherment",
         "digitalSignature",
         "keyAgreement",
         "keyCertSign",
         "keyEncipherment",
       ]

       subject            = "CN=${azurerm_network_interface.test.private_ip_address}"
       validity_in_months = 12
     }
   }
 }

 resource "azurerm_virtual_machine" "test" {
   name                          = "${var.prefix}-vm"
   location                      = "${azurerm_resource_group.main.location}"
   resource_group_name           = "${azurerm_resource_group.main.name}"
   network_interface_ids         = ["${azurerm_network_interface.test.id}"]
   vm_size                       = "Standard_F2"
   delete_os_disk_on_termination = true

   storage_image_reference {
     publisher = "MicrosoftWindowsServer"
     offer     = "WindowsServer"
     sku       = "2016-Datacenter"
     version   = "latest"
   }

   storage_os_disk {
     name              = "${var.prefix}-osdisk"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }

   os_profile {
     computer_name  = "${var.prefix}-vm"
     admin_username = "mradministrator"
     admin_password = "Th15IsD0g1234!"
   }

   os_profile_windows_config {
     provision_vm_agent = true

     winrm {
       protocol        = "https"
       certificate_url = "${azurerm_key_vault_certificate.test.secret_id}"
     }
   }

   os_profile_secrets {
     source_vault_id = "${azurerm_key_vault.test.id}"

     vault_certificates {
       certificate_url   = "${azurerm_key_vault_certificate.test.secret_id}"
       certificate_store = "My"
     }
   }
 }
