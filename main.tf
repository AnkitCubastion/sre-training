terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.99.0"
    }
  }
}

provider "azurerm" {
  features{}
}

resource "azurerm_resource_group" "test-rg" {
  name     = "test-rg"
  location = "West Europe"
}

resource "azurerm_virtual_network" "test-network" {
  name                = "test-network"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet1" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.test-rg.name
  virtual_network_name = azurerm_virtual_network.test-network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "test-pip" {
  name                = "test-pip"
  resource_group_name = azurerm_resource_group.test-rg.name
  location            = azurerm_resource_group.test-rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_kubernetes_cluster" "test-aks1" {
  name                = "test-aks1"
  location            = azurerm_resource_group.test-rg.location
  resource_group_name = azurerm_resource_group.test-rg.name
  dns_prefix          = "testaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

locals {
  backend_address_pool_name      = "${azurerm_virtual_network.test-network.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.test-network.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.test-network.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.test-network.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.test-network.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.test-network.name}-rqrt"
  redirect_configuration_name    = "${azurerm_virtual_network.test-network.name}-rdrcfg"
}

resource "azurerm_application_gateway" "test-appgateway" {
  name                = "test-appgateway"
  resource_group_name = azurerm_resource_group.test-rg.name
  location            = azurerm_resource_group.test-rg.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "my-gateway-ip-configuration"
    subnet_id = azurerm_subnet.subnet1.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.test-pip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/path1/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 9
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}
