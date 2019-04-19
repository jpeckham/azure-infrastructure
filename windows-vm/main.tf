variable "prefix" {
  default = "jdp-usa"
}

variable "vm1"{
  default = "jdp-usa-win1"
}

data "azurerm_client_config" "current" {

}

output "tenant_id" {
  value = "${data.azurerm_client_config.current.tenant_id}"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location =  "Central US"
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

# windows box
resource "azurerm_public_ip" "public-ip" {  //Here defined the public IP
  name                         = "${var.prefix}-public-ip"
  location                     = "${azurerm_resource_group.main.location}"
  resource_group_name          = "${azurerm_resource_group.main.name}"
  allocation_method            = "Dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "${var.vm1}"    //Here defined the dns name

  tags {
    environment = "test"
  }
}
resource "azurerm_network_security_group" "test" {  //Here defined the network secrity group
  name                = "${var.vm1}-sg"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  security_rule {   //Here opened WinRMport
    name                       = "winrm"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {   //Here opened https port for outbound
    name                       = "winrm-out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {   //Here opened remote desktop port
    name                       = "RDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags {
    environment = "test"
  }
}

resource "azurerm_network_interface" "test" {
  name                = "${var.vm1}-nic"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.test.id}"

  ip_configuration {
    name                          = "${var.vm1}-nic-ipcfg"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.public-ip.id}"
  }

  tags = {
    environment = "staging"
  }
}

 resource "azurerm_virtual_machine" "test" {
   name                          = "${var.vm1}"
   location                      = "${azurerm_resource_group.main.location}"
   resource_group_name           = "${azurerm_resource_group.main.name}"
   network_interface_ids         = ["${azurerm_network_interface.test.id}"]
   vm_size                       = "Standard_F2" #2cpu 4gig ram
   delete_os_disk_on_termination = true

   storage_image_reference {
     publisher = "MicrosoftWindowsServer"
     offer     = "WindowsServer"
     sku       = "2016-Datacenter"
     version   = "latest"
   }

   storage_os_disk {
     name              = "${var.vm1}-osdisk"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }

   os_profile {
     computer_name  = "${var.vm1}"
     admin_username = "mradministrator"
     admin_password = "Th15IsD0g1234!"
   }

   os_profile_windows_config {
     provision_vm_agent = true
    winrm = {  //Here defined WinRM connectivity config
      protocol = "http"
    }
   }
 }
