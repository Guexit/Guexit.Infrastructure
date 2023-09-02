# Guexit.Infrastructure

## Overview

This repository contains the Terraform configurations for managing the infrastructure of Guexit's services in Azure. It sets up resources such as Azure PostgreSQL Flexible Server, Virtual Network, Subnets, and DNS zones among others.

## Prerequisites

1. **Azure Subscription**: You need an active Azure subscription to deploy these resources.

2. **Terraform**: Install Terraform from [here](https://developer.hashicorp.com/terraform/downloads).

3. **Azure CLI**: Install Azure Command-Line Interface (CLI) following [these instructions](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli).

## Initial Setup

1. **Configure Terraform in Azure**: Follow the steps mentioned [here](https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-cloud-shell-bash?tabs=bash)
    * **Service Principal**: (TODO: Create a service principal as described [here](https://learn.microsoft.com/en-us/azure/developer/terraform/get-started-cloud-shell-bash?tabs=bash#create-a-service-principal))

2. **Create Azure Key Vault**: (TODO: Create a key vault in Azure and set up a private connection to it)

3. **Clone this Repository**:

    ```shell
    git clone https://github.com/your-repo/Guexit.Infrastructure.git
    cd Guexit.Infrastructure
    ```

4. **Login to Azure**:

    ```shell
    az login
    ```

## Terraform Commands

1. **Initialise Terraform**:

    ```shell
    terraform init --upgrade
    ```

2. **Validate the Configuration**:

    ```shell
    terraform validate
    ```

3. **Generate and Review Execution Plan**:

    ```shell
    terraform plan --var="env_name=develop"
    ```

4. **Apply the Changes**:

    ```shell
    terraform apply -var="env_name=develop"
    ```

    * Alternatively, you can set `env_name` as an env variable: `export TF_VAR_env_name=develop`

5. **Destroy the Resources**:

    ```shell
    terraform destroy -var="env_name=develop"
    ```

## Configuration Parameters

* `env_name`: Environment name (default is "develop"). It can also be "staging" or "production".

* Additional variables can be set in `variables.tf``.

## Notes

* This configuration pins `azurerm` to a specific version for compatibility with the database `collation = "en_US.UTF8"`.
