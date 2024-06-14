param vnetName string
param subnetName string
param addressPrefix string
param nsgId string
param routeTableId string = ''
param delegations array = []

resource existingVNet 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-07-01' = {
  name: subnetName
  parent: existingVNet
  properties: {
    addressPrefix: addressPrefix
    networkSecurityGroup: {
      id: nsgId
    }
    routeTable: routeTableId != '' ? {
      id: routeTableId
    } : null
    delegations: delegations
  }
}

output subnetId string = subnet.id
