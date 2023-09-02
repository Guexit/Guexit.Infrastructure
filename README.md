# Guexit.Infrastructure
Guexit's infrastructure configuration

## Setup

* Steps to configure Terraform in Azure in [here](https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-cloud-shell-bash?tabs=bash). **TODO: I haven't configured a Service Principal yet, but it's something that must be done [here]**(https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-cloud-shell-bash?tabs=bash#create-a-service-principal)

* Crete a key vault in Azure. **TODO: Create a private connection to the key vault**

* Populate `.tf` files with a similar configuration to [this tutorial](https://learn.microsoft.com/en-us/azure/developer/terraform/deploy-postgresql-flexible-server-database?tabs=azure-cli)

* Install terraform from [here](https://developer.hashicorp.com/terraform/downloads)

* I had to pin azurerm to a version for it to work with database `collation = "en_US.UTF8"`.

* Install Azure Command-Line Interface (CLI) following [these instructions](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)

* Log in to Azure using `az login`

* `terraform init --upgrade` & `terraform validate`

* `terraform plan`

* `terraform apply -var="env_name=develop"`. It can also be set as an env variable: `export TF_VAR_env_name=develop`. This variable is not mandatory, the default is `develop` but could be set to `staging` or `production`.

* To destroy the resources, run `terraform destroy -var="env_name=develop"`
