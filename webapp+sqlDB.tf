terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.60.0"
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

locals {
  resource_group_name = "TF-RG"
  location = "East US"
}

resource "azurerm_resource_group" "tf_rg" {
  name = local.resource_group_name
  location = local.location  
}

resource "azurerm_app_service_plan" "tf_asp" {
  name = "tf-asp"
  location = local.location
  resource_group_name = local.resource_group_name
  depends_on = [  
    azurerm_resource_group.tf_rg
   ]

  sku {
    tier = "Basic"
    size = "B1"
  } 
}

resource "azurerm_app_service" "tf_app" {
  name = "tf0909-webapp"
  location = local.location
  resource_group_name = local.resource_group_name
  app_service_plan_id = azurerm_app_service_plan.tf_asp.id
  site_config {
    dotnet_framework_version = "v6.0"
  } 
  source_control {
    repo_url = "https://github.com/VinayTez/ProductApp"
    branch = "master"
    manual_integration = true
    use_mercurial = false
  }
  depends_on = [  
    azurerm_resource_group.tf_rg
   ]
}

resource "azurerm_sql_server" "tf_sqlser" {
  name                         = "tf-sqlser"
  resource_group_name          = local.resource_group_name
  location                     = local.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "Azure@123"
}

resource "azurerm_sql_database" "tf_sqldb" {
  name                = "tf-sqldb"
  resource_group_name = local.resource_group_name
  location            = local.location
  server_name         = azurerm_sql_server.tf_sqlser.name
  depends_on = [  
    azurerm_sql_server.tf_sqlser
   ]
}

resource "azurerm_sql_firewall_rule" "tf_sqlfw_client" {
  name                = "tf-fwrule-client"
  resource_group_name = local.resource_group_name
  server_name         = azurerm_sql_server.tf_sqlser.name
  start_ip_address    = "111.93.10.210"
  end_ip_address      = "111.93.10.210"
  depends_on = [  
    azurerm_sql_server.tf_sqlser
   ]
}

resource "azurerm_sql_firewall_rule" "tf_sqlfw_az" {
  name                = "tf-sqlfw-az"
  resource_group_name = local.resource_group_name
  server_name         = azurerm_sql_server.tf_sqlser.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
  depends_on=[
    azurerm_sql_server.tf_sqlser
  ]
}

resource "null_resource" "tf_sql_setup" {
    provisioner "local-exec" {
      command = "sqlcmd -S tf-sqlser.database.windows.net -U sqladmin -P Azure@123 -d tf-sqldb -i init.sql"
  }
  depends_on=[
    azurerm_sql_server.tf_sqlser
  ]
}