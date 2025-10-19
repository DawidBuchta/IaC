#Set-Alias -name tf -value terraform

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.49.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "102057f1-f742-4ffe-83c0-872a3b4f7578"
  tenant_id       = "50c76291-0c80-4444-a2fb-4f8ab168c311"
}


resource "azurerm_resource_group" "IaC" {

  name     = "Infrastructure_as_Code"
  location = "germanywestcentral"

}

resource "azurerm_virtual_network" "LAN" {
  name                = "IaC-network"
  location            = azurerm_resource_group.IaC.location
  resource_group_name = azurerm_resource_group.IaC.name
  address_space       = ["172.22.1.0/24"]


}

