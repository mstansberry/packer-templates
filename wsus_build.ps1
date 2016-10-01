# Mount virtualbox path as f:\
#net use f: \\vboxsvr\WSUS /PERSISTENT:YES
#F:\psexec -u "nt authority\system" net use f: \\vboxsvr\WSUS /PERSISTENT:YES

# WSUS Install
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools
Invoke-BpaModel -ModelId Microsoft/Windows/UpdateServices
& "C:\Program Files\Update Services\Tools\wsusutil.exe" postinstall CONTENT_DIR=D:\WSUS\

# Disable Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

#Get WSUS Server Object
$wsus = Get-WSUSServer

#Connect to WSUS server configuration
$wsusConfig = $wsus.GetConfiguration()

#Set to download updates from Microsoft Updates
Set-WsusServerSynchronization –SyncFromMU

#Set Update Languages to English and save configuration settings
$wsusConfig.AllUpdateLanguagesEnabled = $false 
$wsusConfig.SetEnabledUpdateLanguages(“en”) 
$wsusConfig.Save()

#Get WSUS Subscription and perform initial synchronization to get latest categories
$subscription = $wsus.GetSubscription()
$subscription.StartSynchronizationForCategoryOnly()
While ($subscription.GetSynchronizationStatus() -ne ‘NotProcessing’) {
    Write-Host “.” -NoNewline
    Start-Sleep -Seconds 5
}
Write-Host “Sync is done.”

#Configure the Platforms that we want WSUS to receive updates
Get-WsusProduct | where-Object {
    $_.Product.Title -in (
    ‘Windows Server 2016’,
    ‘Windows Server 2012 R2’)
} | Set-WsusProduct -Verbose

#Configure the Classifications
Get-WsusClassification | Where-Object {
    $_.Classification.Title -in (
    ‘Update Rollups’,
    ‘Security Updates’,
    ‘Critical Updates’,
    ‘Service Packs’,
    ‘Updates’)
} | Set-WsusClassification -Verbose

#Configure Synchronizations
$subscription.SynchronizeAutomatically=$true

#Set synchronization scheduled for midnight each night
$subscription.SynchronizeAutomaticallyTimeOfDay= (New-TimeSpan -Hours 0)
$subscription.NumberOfSynchronizationsPerDay=1
$subscription.Save()

#Kick off a synchronization
$subscription.StartSynchronization()
$subscription.GetSynchronizationProgress()

# Wait for sync
while ($subscription.GetSynchronizationProgress().ProcessedItems -ne $subscription.GetSynchronizationProgress().TotalItems) {
    Write-Progress -PercentComplete (
    $subscription.GetSynchronizationProgress().ProcessedItems*100/($subscription.GetSynchronizationProgress().TotalItems)
    ) -Activity "Sync" 
}

# Make sure the default automatic approval rule is not enabled
$wsus.GetInstallApprovalRules()

# View synchronization schedule options
$wsus.GetSubscription()

# Get Configuration state
$wsus.GetConfiguration().GetUpdateServerConfigurationState()

# Get WSUS status
$wsus.GetStatus()

