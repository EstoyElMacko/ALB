@description('Name of the automation account')
param automationAccountName string = 'gml-eus-autoShutdownauto-autoAct'


@description('Determines if schedule will be deployed. Note: You cannot redeploy a schedule if any part of it already exists in the automation account. if the schedule already exists, it must be deleted before redeploying or it will cause the template to fail.')
param deployScheduleJob bool = false

@description('Time zone to use for automation shutdown schedule')
param timeZone string = 'America/New_York'

@description('UTC formatted time string when template was executed. Do not pass value.')
param templateRunTime string = utcNow()

@description('Azure region where the automation account will be deployed. Defaults to the region where the resource group is located')
param location string = resourceGroup().location

param invokationTimeUTC string = utcNow()


//var originalStartTime = '2022-03-04T19:30:00-05:00'
//var startDate = dateTimeAdd(invokationTimeUTC, 'P1D', 'yyyy-MM-dd')
//var startTimeString = '${padLeft(gmtStartHour24, 2, '0')}:${padLeft(startMinute, 2, '0')}:00'
//var startTime = '${startDate}T${startTimeString}'
var timeString = '19:30:00-05:00'
var scheduleDate = dateTimeAdd(templateRunTime, 'P1D')
var startTime = '${split(scheduleDate,'T')[0]}T${timeString}'
output templatRunTime string = templateRunTime
output timeString string = timeString
output startTime string = startTime

//var startTime = dateTimeAdd(invokationTimeUTC, 'PT10M')

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
      uri: 'https://raw.githubusercontent.com/EstoyElMacko/ALB/EstoyElMack_12-5-2021/runbooks/Remove-AzureBastion.ps1'
    }
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
    publishContentLink: {
      version: '1.0.0'
      uri: 'https://raw.githubusercontent.com/EstoyElMacko/ALB/EstoyElMack_12-5-2021/runbooks/Stop-AzureFirewall.ps1'
    }

  }
}

resource schedule_nightlyShutdown 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: automationAccount
  name: 'Nightly-Shutdown'
  properties: {
    description: 'Daily task to shut down specified non-VM workloads'
    startTime: startTime
    expiryTime: '9999-12-31T18:59:00-05:00'
    interval: 1
    frequency: 'Day'
    timeZone: timeZone
  }
}

resource scheduleJob_stopAzureFirewall 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = if(deployScheduleJob){
  parent: automationAccount
  // create a new guid each time the template is run, using a combination of the runbook name associated and the timestamp when this template was called
  name: guid(runbook_stopAzureFirewall.name, invokationTimeUTC)
  properties: {
    runbook: {
      name: runbook_stopAzureFirewall.name
    }
    schedule: {
      name: 'Nightly-Shutdown'
    }
  }
}

resource scheduleJob_removeAzureBastion 'Microsoft.Automation/automationAccounts/jobSchedules@2020-01-13-preview' = if(deployScheduleJob){
  parent: automationAccount
  // create guid based on subscriptionId, resource group name and the name of the associated runbook - ensures no duplicate schedule names (schedule{name:'whatever'} is the display name)
  name: guid(runbook_removeAzureBastion.name, invokationTimeUTC)
  properties: {
    runbook: {
      name: runbook_removeAzureBastion.name
    }
    schedule: {
      name: 'Nightly-Shutdown'
    }
  }
}
