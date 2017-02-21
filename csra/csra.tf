variable "crsa_poc_admin_password" {
  type = "string"
}

resource "azurerm_resource_group" "csra-poc" {
    name = "csra-poc"
    location = "ukwest"
    tags {
      Service = "CSRA"
      Environment = "PoC"
    }
}

resource "azurerm_sql_server" "csra-poc" {
    name = "csra-poc"
    resource_group_name = "${azurerm_resource_group.csra-poc.name}"
    location = "ukwest"
    version = "12.0"
    administrator_login = "csra"
    administrator_login_password = "${var.crsa_poc_admin_password}"
    tags {
        Service = "CSRA"
        Environment = "PoC"
    }
}

resource "azurerm_sql_firewall_rule" "csra-poc-open" {
    name = "Open to the world"
    resource_group_name = "${azurerm_resource_group.csra-poc.name}"
    server_name = "${azurerm_sql_server.csra-poc.name}"
    start_ip_address = "0.0.0.0"
    end_ip_address = "255.255.255.255"
}

resource "azurerm_sql_database" "csra-poc" {
    name = "csra-poc"
    resource_group_name = "${azurerm_resource_group.csra-poc.name}"
    location = "ukwest"
    server_name = "${azurerm_sql_server.csra-poc.name}"
    edition = "Basic"
    tags {
        Service = "CSRA"
        Environment = "PoC"
    }
}

resource "azurerm_template_deployment" "csra-poc-webapp" {
  name = "csra-poc-webapp"
  resource_group_name = "${azurerm_resource_group.csra-poc.name}"
  deployment_mode = "Incremental"
  template_body = "${file("./webapp.template.json")}"
  parameters {
    environment = "PoC"
  }
}
