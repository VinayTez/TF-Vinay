terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.51.0"
    }
  }
}
provider "azurerm" {
  subscription_id = "738dfdc6-f0bd-407d-b899-c56640f7ce02"
  client_id = "a36c922f-52c3-4695-8254-1c00e2d5ec08"
  client_secret = "rtK8Q~jPAj7Sh7czpAdhe9rCIBPW-BhV62dq3cEg"
  tenant_id = "0c45565b-c823-4469-9b6b-30989afb7a2e"
  features {}
}
resource "azurerm_resource_group" "app_grp" {
    name = local.resource_group
    location = local.location
}
variable "virtual_network_name" {
  type = string
  description = "Please enter the VNET name"  
}
variable "virtual_machine_name" {
  type = string
  description = "Pls enter the name of the VM"  
}
locals {
  resource_group = "TF-RG"
  location = "EastUS"
}
resource "azurerm_virtual_network" "tf_vnet" {
  name = var.virtual_network_name
  location = local.location
  resource_group_name = local.resource_group
  address_space = ["10.0.0.0/16"]  
  depends_on = [  
    azurerm_resource_group.app_grp
   ]
}

resource "azurerm_subnet" "tf_subnet" {
    name = "subnet1"
    resource_group_name = local.resource_group
    virtual_network_name = var.virtual_network_name
    address_prefixes = ["10.0.1.0/24"]
    depends_on = [  
      azurerm_virtual_network.tf_vnet
    ]
}

// This subnet is meant for the Azure Bastion service
resource "azurerm_subnet" "tf_bastion" {
  name = "AzureBastionSubnet"
  resource_group_name = local.resource_group
  virtual_network_name = var.virtual_network_name
  address_prefixes = ["10.0.2.0/24"]
  depends_on = [  
    azurerm_virtual_network.tf_vnet
   ]  
}

resource "azurerm_network_interface" "tf_nic" {
  name = "tf-nic"
  location = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.tf_subnet.id 
    private_ip_address_allocation = "Dynamic" 
  } 

  depends_on = [ 
    azurerm_virtual_network.tf_vnet,
    azurerm_subnet.tf_subnet
   ]
}

resource "azurerm_windows_virtual_machine" "tf-vm" {
  name = var.virtual_machine_name
  location = local.location
  resource_group_name = local.resource_group
  size = "Standard_D2s_v3"
  admin_username = "demouser"
  admin_password = "Azure@123"
  network_interface_ids = [ 
    azurerm_network_interface.tf_nic.id
  ]
  
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer = "WindowsServer"
    sku = "2019-Datacenter"
    version = "latest"
  }

  depends_on = [ 
    azurerm_network_interface.tf_nic,
   ]
}
resource "azurerm_network_security_group" "ts_nsg" {
  name                = "ts-nsg"
  location            = local.location
  resource_group_name = local.resource_group

# We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_RDP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id = azurerm_subnet.tf_subnet.id
  network_security_group_id = azurerm_network_security_group.ts_nsg.id
  depends_on = [
    azurerm_network_security_group.ts_nsg
  ]
}

resource "azurerm_public_ip" "bastion_pip" {
  name = "bastion-pip"
  location = local.location
  resource_group_name = local.resource_group
  allocation_method = "Static"
  sku = "Standard"  
}

resource "azurerm_bastion_host" "tf_bastion" {
  name = "tf-bastion"
  location = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name = "configuration"
    subnet_id = azurerm_subnet.tf_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion_pip.id
  }

  depends_on = [  
    azurerm_subnet.tf_bastion,
    azurerm_public_ip.bastion_pip
   ] 
}