terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.58.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "102057f1-f742-4ffe-83c0-872a3b4f7578"
  tenant_id       = "50c76291-0c80-4444-a2fb-4f8ab168c311"
}

//["germanywestcentral","swedencentral","italynorth","uksouth","norwayeast"]
resource "azurerm_resource_group" "IaC" {

  name     = "Infrastructure_as_Code"
  location = "uksouth"

}

//siec główna
resource "azurerm_virtual_network" "Azure-VNet" {
  name                = "IaC-network"
  location            = azurerm_resource_group.IaC.location
  resource_group_name = azurerm_resource_group.IaC.name
  address_space       = ["172.22.0.0/16"]
  depends_on          = [azurerm_resource_group.IaC]

}

//sieć lokalna
resource "azurerm_subnet" "LAN" {

  name                 = "IaC-LAN"
  resource_group_name  = azurerm_resource_group.IaC.name
  virtual_network_name = azurerm_virtual_network.Azure-VNet.name
  address_prefixes     = ["172.22.1.0/24"]
  depends_on           = [azurerm_virtual_network.Azure-VNet, azurerm_resource_group.IaC]
}

//grupa zabezpieczen
resource "azurerm_network_security_group" "Sec-Grp" {

  name                = "IaC-SecurityGroup"
  location            = azurerm_resource_group.IaC.location
  resource_group_name = azurerm_resource_group.IaC.name
  depends_on          = [azurerm_resource_group.IaC]

  tags = {
    enviroment = "dev"
  }
}

//firewall rule
resource "azurerm_network_security_rule" "Inbound-Allow-ALL" {
  name                        = "Inbound-Allow-ALL"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.IaC.name
  network_security_group_name = azurerm_network_security_group.Sec-Grp.name
  depends_on                  = [azurerm_network_security_group.Sec-Grp, azurerm_resource_group.IaC]
}

//przypisanie podsieci do d ogrupy zabezpieczen
resource "azurerm_subnet_network_security_group_association" "SEc-Grp-Assosiation" {
  subnet_id                 = azurerm_subnet.LAN.id
  network_security_group_id = azurerm_network_security_group.Sec-Grp.id
  depends_on                = [azurerm_subnet.LAN, azurerm_resource_group.IaC, azurerm_network_security_group.Sec-Grp]
}

//ip zewnetrzne do vm main
resource "azurerm_public_ip" "wan1" {
  name                    = "wan1"
  location                = azurerm_resource_group.IaC.location
  resource_group_name     = azurerm_resource_group.IaC.name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
  depends_on              = [azurerm_resource_group.IaC]

  tags = {
    environment = "Dev"
  }
}
//ip zewnetrzne do vm linux
resource "azurerm_public_ip" "wan2" {
  name                    = "wan2"
  location                = azurerm_resource_group.IaC.location
  resource_group_name     = azurerm_resource_group.IaC.name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 30
  depends_on              = [azurerm_resource_group.IaC]

  tags = {
    environment = "Dev"
  }
}

//interfejs sieciowy podpinany do vm main
resource "azurerm_network_interface" "lancard1" {
  name                = "lancard1"
  location            = azurerm_resource_group.IaC.location
  resource_group_name = azurerm_resource_group.IaC.name
  depends_on          = [azurerm_resource_group.IaC]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.LAN.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.22.1.10"
    public_ip_address_id          = azurerm_public_ip.wan1.id
  }
  tags = {

    envoriment = "dev"
  }
}
//interfejs sieciowy podpinany do vm linux
resource "azurerm_network_interface" "lancard2" {
  name                = "lancard2"
  location            = azurerm_resource_group.IaC.location
  resource_group_name = azurerm_resource_group.IaC.name
  depends_on          = [azurerm_resource_group.IaC]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.LAN.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.22.1.11"
    public_ip_address_id          = azurerm_public_ip.wan2.id
  }
  tags = {

    envoriment = "dev"
  }
}


resource "azurerm_windows_virtual_machine" "main-server" {
  name                = "Main"
  resource_group_name = azurerm_resource_group.IaC.name
  location            = azurerm_resource_group.IaC.location
  size                = "Standard_B2as_v2" 
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  depends_on          = [azurerm_resource_group.IaC, azurerm_network_interface.lancard1]

  network_interface_ids = [
    azurerm_network_interface.lancard1.id
  ]

  //priority                  = "Spot"
  //eviction_policy           = "Deallocate"
  automatic_updates_enabled = false
  computer_name             = "Tatake"
  patch_mode                = "AutomaticByPlatform"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"

  }


  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-azure-edition-smalldisk"
    version   = "latest"
  }
}
resource "azurerm_virtual_machine_extension" "enable_winrm_main" {
  name                 = "enable-winrm"
  virtual_machine_id   = azurerm_windows_virtual_machine.main-server.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Bypass -Command \"Enable-PSRemoting -Force; winrm quickconfig -q; winrm set winrm/config/service '@{AllowUnencrypted=\\\"true\\\"}'; winrm set winrm/config/service/auth '@{Basic=\\\"true\\\"}'; New-NetFirewallRule -DisplayName 'WinRM-HTTP-5985' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5985 -Profile Any\""
  })
}

resource "azurerm_linux_virtual_machine" "linux-server" {
  name                            = "linux"
  resource_group_name             = azurerm_resource_group.IaC.name
  location                        = azurerm_resource_group.IaC.location
  size                            = "Standard_B1s"
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  depends_on                      = [azurerm_resource_group.IaC, azurerm_network_interface.lancard2]
  network_interface_ids = [
    azurerm_network_interface.lancard2.id
  ]

  //priority        = "Spot"
  //eviction_policy = "Deallocate"
  computer_name         = "Tatake"
  patch_mode            = "ImageDefault"
  patch_assessment_mode = "ImageDefault"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"

  }


  source_image_reference {
    publisher = "debian"
    offer     = "debian-13"
    sku       = "13"
    version   = "latest"
  }

  custom_data = base64encode(<<-CLOUDINIT
#cloud-config
package_update: true
packages:
  - ansible
  - python3-winrm
  - sshpass
runcmd:
  - ansible-galaxy collection install ansible.windows community.windows microsoft.ad chocolatey.chocolatey
CLOUDINIT
  )
}

