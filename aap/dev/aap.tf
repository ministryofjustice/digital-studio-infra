terraform {
    required_version = ">= 0.9.2"
    backend "azure" {
        resource_group_name = "webops"
        storage_account_name = "nomsstudiowebops"
        container_name = "terraform"
        key = "aap-dev.terraform.tfstate"
        arm_subscription_id = "c27cfedb-f5e9-45e6-9642-0fad1a5c94e7"
        arm_tenant_id = "747381f4-e81f-4a43-bf68-ced6a1e14edf"
    }
}

variable "env-name" {
    type = "string"
    default = "aap-dev"
}
variable "tags" {
    type = "map"
    default {
        Service = "AAP"
        Environment = "Dev"
    }
}

resource "random_id" "sql-app-password" {
    byte_length = 32
}

resource "azurerm_resource_group" "group" {
    name = "${var.env-name}"
    location = "ukwest"
    tags = "${var.tags}"
}

resource "azurerm_storage_account" "storage" {
    name = "${replace(var.env-name, "-", "")}storage"
    resource_group_name = "${azurerm_resource_group.group.name}"
    location = "${azurerm_resource_group.group.location}"
    account_type = "Standard_RAGRS"
    enable_blob_encryption = true

    tags = "${var.tags}"
}

module "sql" {
    source = "../../shared/modules/azure-sql"
    name = "${var.env-name}"
    resource_group = "${azurerm_resource_group.group.name}"
    location = "${azurerm_resource_group.group.location}"
    administrator_login = "aap"
    firewall_rules = [
        {
            label = "Allow azure access"
            start = "0.0.0.0"
            end = "0.0.0.0"
        },
        {
            label = "Open to the world"
            start = "0.0.0.0"
            end = "255.255.255.255"
        },
    ]
    audit_storage_account = "${azurerm_storage_account.storage.name}"
    edition = "Basic"
    collation = "SQL_Latin1_General_CP1_CI_AS"
    tags = "${var.tags}"

    db_users {
        app = "${random_id.sql-app-password.b64}"
    }

    setup_queries = [
        "GRANT SELECT TO app"
    ]
}

resource "azurerm_template_deployment" "api" {
    name = "api"
    resource_group_name = "${azurerm_resource_group.group.name}"
    deployment_mode = "Incremental"
    template_body = "${file("../../shared/api-management.template.json")}"

    parameters {
        name = "${var.env-name}"
        publisherEmail = "noms-studio-webops@digital.justice.gov.uk"
        publisherName = "HMPPS"
        sku = "Developer"
    }
}

resource "null_resource" "api-sync" {
    depends_on = ["azurerm_template_deployment.api"]

    triggers {
        swagger = "https://${azurerm_template_deployment.viper.parameters.name}.azurewebsites.net/api-docs"
    }

    provisioner "local-exec" {
        command = <<CMD
node ${path.module}/../tools/sync-api.js \
    --tenantId '${var.azure_tenant_id}' \
    --subscriptionId '${var.azure_subscription_id}' \
    --resourceGroupName '${azurerm_resource_group.group.name}' \
    --serviceName '${azurerm_template_deployment.api.parameters.name}' \
    --swaggerDefinition 'https://${azurerm_template_deployment.viper.parameters.name}.azurewebsites.net/api-docs' \
    --path 'analytics' \
    --apiId 'analytics' \
    --username 'viper' \
    --password '${random_id.app-basic-password.b64}'
CMD
    }
}
