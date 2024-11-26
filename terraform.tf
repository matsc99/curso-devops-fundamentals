# Configuração Inicial e Provider
provider "azurerm" {
  features {}
}

# Definindo variáveis
variable "resource_group_name" {
  default = "rg-operacao"
}

variable "location" {
  default = "East US"
}

variable "tags" {
  default = {
    environment = "production"
    department  = "operations"
    cost_center = "12345"
  }
}

# Criando o Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

#Criando a Virtual Network e Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-operacao"
  address_space        = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-operacao"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Criando as Azure Virtual Desktops
resource "azurerm_virtual_machine" "avd" {
  count               = 50
  name                = "avd-vm-${count.index + 1}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  network_interface_ids = [
    azurerm_network_interface.nic[count.index].id
  ]
  vm_size             = "Standard_D2_v3"
  availability_set_id = azurerm_availability_set.avail_set.id
  os_profile {
    computer_name = "avd-vm-${count.index + 1}"
    admin_username = "adminuser"
    admin_password = "P@ssw0rd123"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_network_interface" "nic" {
  count               = 50
  name                = "nic-${count.index + 1}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machine Scale Sets

resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "vmss-operacao"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  upgrade_policy_mode = "Manual"
  sku {
    name     = "Standard_D2_v3"
    capacity = 3
  }
  os_profile {
    computer_name_prefix = "vmss"
    admin_username       = "adminuser"
    admin_password       = "P@ssw0rd123"
  }
  network_profile {
    name    = "network-profile"
    primary = true
    ip_configuration {
      name      = "internal"
      subnet_id = azurerm_subnet.subnet.id
    }
  }
}

# Banco de Dados SQL
resource "azurerm_sql_server" "sql_server" {
  name                         = "sqlserver-operacao"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd123"
}

resource "azurerm_sql_database" "sql_database" {
  name                = "db-operacao"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  server_name         = azurerm_sql_server.sql_server.name
  sku_name            = "S1"
}

# Azure Functions
resource "azurerm_storage_account" "storage" {
  name                     = "storageoperacao"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier              = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_function_app" "function_app" {
  name                      = "function-app-operacao"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
  app_service_plan_id       = azurerm_app_service_plan.app_service_plan.id
  storage_account_name     = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name                     = "app-service-plan-operacao"
  location                 = var.location
  resource_group_name      = azurerm_resource_group.rg.name
  kind                     = "FunctionApp"
  reserved                 = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}
