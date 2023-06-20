Terraform
All terraform templates

Terraform consists of 3 imporrtant file

*.tf file: which has all your terraform code and where you declare all the information
*.tfstatefile: which has the state information of your resources in cloud and if the state file is deleted then you need to manually import all the resources for making any changes Command: terraform import "/subscriptions/738dfdc6-f0bd-407d-b899-c56640f7ce02/resourceGroups/my-resource-group/providers/Microsoft.Compute/virtualMachines/vm1"
*.tflock.hcl: Terraform lock.hcl it locks the provider version with hashing algorithms. Contains provider related version using hashes. Hashing is the procedure of translating a given key into a code.
Commands
terraform init: to initialize terarform on to the folder terraform plan: which save the plan of the configuration terraform destroy : to destroy the existing resources and it takes input from the state file terraform apply: which will apply the configuration terraform init --upgrade: This can be used when you update the hashicorp version and also to clear initilization cache. teerraform show: used to show the current configuratin from state file.

Few important blocks
Backend:
Its always import to presere terraform state file where if the file is deleted in local the terraform can pull it from the storage account this can be achieved by using backedn block as below.

terraform { backend "azurerm" {

resource_group_name= "NetworkWatcherRG" storage_account_name= "kstg123" container_name = "rahul" key= "terraform.tfstate" } }

Provider
The provider block provide the neccsary information about the sub,tenant,client,secret ids of the account and its not good practise to share the info in the terraform files to avoid that we can use azure cli and ignore that info as below.

Before using cli
provider "azurerm" { client_id = "" tenant_id = "" subscription_id = "" client_secret = "" features {} }

After using the cli
provider "azurerm" { tenant_id = "0c45565b-c823-4469-9b6b-30989afb7a2e" features { resource_group { prevent_deletion_if_contains_resources = false # If you want to delete some unused resources then you can use this flag in features block. } }

Data block
The data block is used to get the data like current configuration or subcription level information like below.

data "azurerm_client_config" "current" { }

usage
access_policy { tenant_id = data.azurerm_client_config.current.tenant_id object_id = data.azurerm_client_config.current.object_id }
