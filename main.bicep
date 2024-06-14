param location string = resourceGroup().location
param tags object = {}

var existingVnetName = 'external-vnet'
var existingVnetRg = 'externalvnet-rg'

param apimSubnetName string = 'snet-apim'
param apimNsgName string = 'nsg-apim'
param apimRouteTableName string = 'rt-apim'
param apimSubnetAddressPrefix string = '10.170.0.0/26'

param privateEndpointSubnetName string = 'snet-private-endpoint'
param privateEndpointNsgName string = 'nsg-pe'
param privateEndpointSubnetAddressPrefix string = '10.170.0.64/26'

param functionAppSubnetName string = 'snet-functionapp'
param functionAppNsgName string = 'nsg-functionapp'
param functionAppSubnetAddressPrefix string = '10.170.0.128/26'

param privateDnsZoneNames array = []

resource apimNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: apimNsgName
  location: location
  tags: union(tags, { 'azd-service-name': apimNsgName })
  properties: {
    securityRules: [
      {
        name: 'AllowPublicAccess'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 3000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMManagement'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3443'
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 3010
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAPIMLoadBalancer'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '6390'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 3020
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureTrafficManager'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'AzureTrafficManager'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 3030
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource apimRouteTable 'Microsoft.Network/routeTables@2020-06-01' = {
  name: apimRouteTableName
  location: location
  tags: union(tags, { 'azd-service-name': apimRouteTableName })
  properties: {
    routes: [
      {
        name: 'apim-management'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'Internet'
        }
      }
    ]
  }
}

resource privateEndpointNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: privateEndpointNsgName
  location: location
  tags: union(tags, { 'azd-service-name': privateEndpointNsgName })
  properties: {
    securityRules: []
  }
}

resource functionAppNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: functionAppNsgName
  location: location
  tags: union(tags, { 'azd-service-name': functionAppNsgName })
  properties: {
    securityRules: []
  }
}

resource existingVNet 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  scope: resourceGroup(existingVnetRg)
  name: existingVnetName
}

module apimSubnetModule './subnet.bicep' = {
  name: 'apimSubnetModule'
  scope: resourceGroup(existingVnetRg)
  params: {
    vnetName: existingVnetName
    subnetName: apimSubnetName
    addressPrefix: apimSubnetAddressPrefix
    nsgId: apimNsg.id
    routeTableId: apimRouteTable.id
  }
}

module privateEndpointSubnetModule './subnet.bicep' = {
  name: 'privateEndpointSubnetModule'
  scope: resourceGroup(existingVnetRg)
  params: {
    vnetName: existingVnetName
    subnetName: privateEndpointSubnetName
    addressPrefix: privateEndpointSubnetAddressPrefix
    nsgId: privateEndpointNsg.id
    routeTableId: ''
  }
}

module functionAppSubnetModule './subnet.bicep' = {
  name: 'functionAppSubnetModule'
  scope: resourceGroup(existingVnetRg)
  params: {
    vnetName: existingVnetName
    subnetName: functionAppSubnetName
    addressPrefix: functionAppSubnetAddressPrefix
    nsgId: functionAppNsg.id
    routeTableId: ''
    delegations: [
      {
        name: 'Microsoft.Web/serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: '${privateDnsZoneName}/privateDnsZoneLink'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: existingVNet.id
    }
    registrationEnabled: false
  }
}]

output apimSubnetId string = apimSubnetModule.outputs.subnetId
output privateEndpointSubnetId string = privateEndpointSubnetModule.outputs.subnetId
output functionAppSubnetId string = functionAppSubnetModule.outputs.subnetId
output location string = location
output vnetRG string = existingVnetRg
