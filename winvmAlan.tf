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

variable "storage_account_name" {
  type = string
  description = "Please enter the Storage Account name"  
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

/*A vnet and a subnet must be already created to apply this block - This is created since subnet was written in network block
data "azurerm_subnet" "subnet1" {
  name = "subnet1"
  virtual_network_name = var.virtual_network_name
  resource_group_name = local.resource_group  
}*/

resource "azurerm_storage_account" "storage_account" {
    name = var.storage_account_name
    resource_group_name = local.resource_group
    location = local.location
    account_tier = "Standard"
    account_replication_type = "LRS"     
    # allow_blob_public_access = true
    depends_on = [  
      azurerm_resource_group.app_grp
     ]
}

resource "azurerm_storage_container" "tf_container" {
    name = "tfsample"
    storage_account_name = var.storage_account_name
    container_access_type = "blob"
    depends_on = [ 
      azurerm_storage_account.storage_account
     ]
}

resource "azurerm_storage_blob" "tf_blob" {
  name = "IIS_Config.ps1"
  storage_account_name = var.storage_account_name
  storage_container_name = "tfsample"
  type = "Block"
  source = "IIS_Config.ps1"
  depends_on = [ 
    azurerm_storage_container.tf_container 
  ]
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

resource "azurerm_network_interface" "tf_nic" {
  name = "tf-nic"
  location = local.location
  resource_group_name = local.resource_group

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.tf_subnet.id #this must be applied after vnet+subnet are created
    private_ip_address_allocation = "Dynamic" 
    public_ip_address_id = azurerm_public_ip.tf_pip.id
  } 

  depends_on = [ 
    azurerm_virtual_network.tf_vnet,
    azurerm_public_ip.tf_pip,
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
  availability_set_id = azurerm_availability_set.tf_set.id
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
    azurerm_availability_set.tf_set  
   ]
}

resource "azurerm_public_ip" "tf_pip" {
  name = "tf_pip"
  location = local.location
  resource_group_name = local.resource_group
  allocation_method = "Static"  
  depends_on = [  
    azurerm_resource_group.app_grp
   ]
}

resource "azurerm_managed_disk" "tf_md" {
  name = "tf-dd"
  location = local.location
  resource_group_name = local.resource_group
  storage_account_type = "Standard_LRS"
  create_option = "Empty"
  disk_size_gb = 16  
  depends_on = [  
    azurerm_resource_group.app_grp
   ]
}

# Attaching the created DD to the VM
resource "azurerm_virtual_machine_data_disk_attachment" "tf_attach" {
  managed_disk_id = azurerm_managed_disk.tf_md.id
  virtual_machine_id = azurerm_windows_virtual_machine.tf-vm.id
  lun = "0"
  caching = "ReadWrite"
  depends_on = [ 
    azurerm_windows_virtual_machine.tf-vm,
    azurerm_managed_disk.tf_md
   ]  
}

resource "azurerm_availability_set" "tf_set" {
  name = "tf-set"
  location = local.location
  resource_group_name = local.resource_group
  platform_fault_domain_count = 3
  platform_update_domain_count = 3
  depends_on = [  
    azurerm_resource_group.app_grp
   ]
}

resource "azurerm_virtual_machine_extension" "tf_extension" {
  name = "tf-extension"
  virtual_machine_id = azurerm_windows_virtual_machine.tf-vm.id
  publisher = "Microsoft.Compute"
  type = "CustomScriptExtension"
  type_handler_version = "1.10"
  depends_on = [  
    azurerm_storage_blob.tf_blob
   ]
   settings = <<SETTINGS
   {
    "fileUris": ["https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/tfsample/IIS_Config.ps1"],
          "commandToExecute": "powershell -ExecutionPolicy Unrestricted -file IIS_Config.ps1"  
   }
 SETTINGS 
}

resource "azurerm_network_security_group" "ts_nsg" {
  name                = "ts-nsg"
  location            = local.location
  resource_group_name = local.resource_group

# We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.tf_subnet.id
  network_security_group_id = azurerm_network_security_group.ts_nsg.id
  depends_on = [
    azurerm_network_security_group.ts_nsg
  ]
}