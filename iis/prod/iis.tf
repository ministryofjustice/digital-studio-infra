terraform {
    required_version = ">= 0.9.0"
    backend "azure" {
        resource_group_name = "webops-prod"
        storage_account_name = "nomsstudiowebopsprod"
        container_name = "terraform"
        key = "iis-prod.terraform.tfstate"
        arm_subscription_id = "a5ddf257-3b21-4ba9-a28c-ab30f751b383"
        arm_tenant_id = "747381f4-e81f-4a43-bf68-ced6a1e14edf"
    }
}

resource "azurerm_resource_group" "iis-prod" {
    name = "iis-prod"
    location = "ukwest"
    tags {
      Service = "IIS"
      Environment = "Prod"
    }
}

resource "random_id" "iis-prod-sql-admin-password" {
    byte_length = 16
}
resource "random_id" "iis-prod-sql-user-password" {
    byte_length = 16
}

resource "azurerm_sql_server" "iis-prod" {
    name = "iis-prod"
    resource_group_name = "${azurerm_resource_group.iis-prod.name}"
    location = "${azurerm_resource_group.iis-prod.location}"
    version = "12.0"
    administrator_login = "iis"
    administrator_login_password = "${random_id.iis-prod-sql-admin-password.b64}"
    tags {
        Service = "IIS"
        Environment = "Prod"
    }
}

resource "azurerm_sql_firewall_rule" "iis-prod-office-access" {
    name = "NOMS Studio office"
    resource_group_name = "${azurerm_resource_group.iis-prod.name}"
    server_name = "${azurerm_sql_server.iis-prod.name}"
    start_ip_address = "${var.ips["office"]}"
    end_ip_address = "${var.ips["office"]}"
}

resource "azurerm_sql_database" "iis-prod" {
    name = "iis-prod"
    resource_group_name = "${azurerm_resource_group.iis-prod.name}"
    location = "${azurerm_resource_group.iis-prod.location}"
    server_name = "${azurerm_sql_server.iis-prod.name}"
    edition = "Standard"
    requested_service_objective_name = "S3"
    tags {
        Service = "IIS"
        Environment = "Prod"
    }
}

resource "azurerm_template_deployment" "sql-tde" {
    name = "sql-tde"
    resource_group_name = "${azurerm_resource_group.iis-prod.name}"
    deployment_mode = "Incremental"
    template_body = "${file("../../shared/azure-sql-tde.template.json")}"
    parameters {
        serverName = "${azurerm_sql_server.iis-prod.name}"
        databaseName = "${azurerm_sql_database.iis-prod.name}"
        service = "IIS"
        environment = "Prod"
    }
}

resource "azurerm_template_deployment" "iis-prod-webapp" {
    name = "iis-prod"
    resource_group_name = "${azurerm_resource_group.iis-prod.name}"
    deployment_mode = "Incremental"
    template_body = "${file("../webapp.template.json")}"
    parameters {
        name = "iis-prod"
        hostname = "hpa.service.hmpps.dsd.io"
        service = "IIS"
        environment = "Prod"
        DB_USER = "iis-user"
        DB_PASS = "${random_id.iis-prod-sql-user-password.b64}"
        DB_SERVER = "${azurerm_sql_server.iis-prod.fully_qualified_domain_name}"
        DB_NAME = "${azurerm_sql_database.iis-prod.name}"
    }
}

output "advice" {
    value = "Don't forget to set up the SQL instance user/schemas manually."
}
