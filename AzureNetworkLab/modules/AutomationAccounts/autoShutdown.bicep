param automationAccountName string = 'gml-eus-autoShutdownauto-autoAct'
param location string = resourceGroup().location
param now string = utcNow()

var startTime = dateTimeAdd(now, 'PT10M')

resource automationAccount 'Microsoft.Automation/automationAccounts@2021-06-22' = {
  name: automationAccountName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    encryption: {
      keySource: 'Microsoft.Automation'
      identity: {}
    }
  }
}
resource runbook_removeAzureBastion 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: 'Remove-AzureBastion'
  location: location
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: false
    logActivityTrace: 0
    publishContentLink: {
      version: '1.0.0'
      
    }
  }
}

resource runbook_startAzureFirewall 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: 'Start-AzureFirewall'
  location: location
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: false
    logActivityTrace: 0
  }
}

resource runbook_stopAzureFirewall 'Microsoft.Automation/automationAccounts/runbooks@2019-06-01' = {
  parent: automationAccount
  name: 'Stop-AzureFirewall'
  location: location
  properties: {
    runbookType: 'PowerShell'
    logVerbose: false
    logProgress: false
    logActivityTrace: 0
  }
}

resource schedule_nightlyShutdown 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: 'Nightly-Shutdown'
  properties: {
    description: 'Daily task to shut down specified non-VM workloads'
    // '2022-03-04T19:30:00-05:00'
    startTime: startTime
    expiryTime: '9999-12-31T18:59:00-05:00'
    interval: 1
    frequency: 'Day'
    timeZone: 'America/New_York'
  }
}

resource schedule_stopAzureFirewall 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  // create guid based on subscriptionId, resource group name and the name of the associated runbook - ensures no duplicate schedule names (schedule{name:'whatever'} is the display name)
  name: guid(subscription().subscriptionId, resourceGroup().name, automationAccountName, runbook_stopAzureFirewall.name)
  properties: {
    runbook: {
      name: runbook_stopAzureFirewall.name
    }
    schedule: {
      name: 'Nightly-Shutdown'
    }
  }
}

resource schedule_removeAzureBastion 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = {
  parent: automationAccount
  // create guid based on subscriptionId, resource group name and the name of the associated runbook - ensures no duplicate schedule names (schedule{name:'whatever'} is the display name)
  name: guid(subscription().subscriptionId, resourceGroup().name, automationAccountName, runbook_removeAzureBastion.name)
  properties: {
    runbook: {
      name: runbook_removeAzureBastion.name
    }
    schedule: {
      name: 'Nightly-Shutdown'
    }
  }
}
