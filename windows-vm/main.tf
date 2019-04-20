#Example of 2 windows machines in an availability set
#TODO: load balancer, http/https, iis
variable "prefix" {
  default = "jdp-usa"
}

variable "vm1" {
  default = "jdp-usa-win1"
}
variable "vm2" {
  default = "jdp-usa-win2"
}

data "azurerm_client_config" "current" {}

output "tenant_id" {
  value = "${data.azurerm_client_config.current.tenant_id}"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = "Central US"
}

resource "azurerm_availability_set" "test" {
  name                = "${var.vm1}-avail-set"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  managed             = true
  tags = {
    environment = "staging"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
}

resource "azurerm_subnet" "internal" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  address_prefix       = "10.0.2.0/24"
}

resource "azurerm_network_security_group" "test" {
  name                = "${var.vm1}-net-sec-grp"                  //Here defined the network secrity group
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  security_rule {
    name                       = "winrm"   //WinRM
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "winrm-out" //WinRM
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"     //RDP
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
# windows box 1
resource "azurerm_public_ip" "public-ip1" {
  name                    = "${var.vm1}-public-ip"                 //Here defined the public IP
  location                = "${azurerm_resource_group.main.location}"
  resource_group_name     = "${azurerm_resource_group.main.name}"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  domain_name_label       = "${var.vm1}"                              //Here defined the dns name

  tags {
    environment = "test"
  }
}


resource "azurerm_network_interface" "test1" {
  name                      = "${var.vm1}-nic"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.test.id}"

  ip_configuration {
    name                          = "${var.vm1}-nic-ipcfg"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.public-ip1.id}"
  }

  tags = {
    environment = "staging"
  }
}

resource "azurerm_virtual_machine" "test" {
  name                          = "${var.vm1}"
  location                      = "${azurerm_resource_group.main.location}"
  resource_group_name           = "${azurerm_resource_group.main.name}"
  network_interface_ids         = ["${azurerm_network_interface.test1.id}"]
  vm_size                       = "Standard_B1ms"                           #2cpu 4gig ram
  delete_os_disk_on_termination = true
  availability_set_id           = "${azurerm_availability_set.test.id}"

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

    winrm = {
      protocol = "http" //WinRM http. not secure.
    }
  }
}
# windows box 2
resource "azurerm_public_ip" "public-ip2" {
  name                    = "${var.vm2}-public-ip"                 //Here defined the public IP
  location                = "${azurerm_resource_group.main.location}"
  resource_group_name     = "${azurerm_resource_group.main.name}"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
  domain_name_label       = "${var.vm2}"                              //Here defined the dns name

  tags {
    environment = "test"
  }
}


resource "azurerm_network_interface" "test2" {
  name                      = "${var.vm2}-nic"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.test.id}"

  ip_configuration {
    name                          = "${var.vm1}-nic-ipcfg"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.public-ip2.id}"
  }

  tags = {
    environment = "staging"
  }
}

resource "azurerm_virtual_machine" "test2" {
  name                          = "${var.vm2}"
  location                      = "${azurerm_resource_group.main.location}"
  resource_group_name           = "${azurerm_resource_group.main.name}"
  network_interface_ids         = ["${azurerm_network_interface.test2.id}"]
  vm_size                       = "Standard_B1ms"                           #2cpu 4gig ram
  delete_os_disk_on_termination = true
  availability_set_id           = "${azurerm_availability_set.test.id}"

  storage_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.vm2}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${var.vm2}"
    admin_username = "mradministrator"
    admin_password = "Th15IsD0g1234!"
  }

  os_profile_windows_config {
    provision_vm_agent = true

    winrm = {
      protocol = "http" //WinRM http. not secure.
    }
  }
}
