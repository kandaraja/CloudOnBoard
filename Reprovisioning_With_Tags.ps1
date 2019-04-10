﻿$ErrorActionPreference = 'SilentlyContinue'
#Login-AzureRmAccount
net use \\10.16.99.18\Script
$csv = Import-Csv "\\10.16.99.18\Script\input001.csv"
net use * /delete /Y
Foreach ($In in $csv) {
$SubscriptionId = $In.SubscriptionID
$ResourceGroupName = $In.ResourceGroupName
$VirtualMachineSize = $In.VMSize
$VMName = $In.TargetServer
$MigrationVMname = $In.MigrationVMname
#For Tags

$GAR_ID = $In.GAR_ID
$APPLICATION = $In.application_name
$REMARK =  $in.application_remarks
$AutoShutdownSchedule= $In.AutoShutdownSchedule
$ROLE = $In.Role
$BACKUP=$In.Backup
$ITSM_NR = $In.ITSM_NR

#Reprovisioning

Select-AzureRmSubscription -SubscriptionId $SubscriptionId

$getVM = Get-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $VMName
If($getVM.Name -ne $VMName) {
$Nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name ($VMName + '-nic01')
  If($Nic.Name -eq $VMName+'-nic01') {

$ManagedDisks = Get-AzureRmDisk -ResourceGroupName $ResourceGroupName
$ManagedDisk = $ManagedDisks | where{$_.Name -like "*$MigrationVMname*"} 
$ManagedDisk.Name | sort -Unique
$VMDisk = $ManagedDisk.Name
if (!$VMDisk -ne $null) {
$Count = 0
$VMConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VirtualMachineSize
Foreach ($disk in $ManagedDisk) {
If (($disk.Name -like "*osdisk*") -or ($disk.Name -like "*DRIVE0*") ) {
$diskConfig = New-AzureRmDiskConfig -SourceResourceId $disk.Id -Location $disk.Location -CreateOption Copy
$Osdisk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $ResourceGroupName -DiskName ($VMName + '-osdisk')
$VMConfig = Set-AzureRmVMOSDisk -VM $VMConfig -ManagedDiskId $Osdisk.Id -CreateOption Attach -Windows
$diskConfig=$disk=$null }
 else {
$Count++ 
$diskConfig = New-AzureRmDiskConfig -SourceResourceId $disk.Id -Location $disk.Location -CreateOption Copy
$dataDisk = New-AzureRmDisk -Disk $diskConfig -ResourceGroupName $ResourceGroupName -DiskName ($VMName + '-datadisk' + "{0:D2}" -f ($Count))
$VMConfig = Add-AzureRmVMDataDisk -Lun ($Count - 1) -Caching ReadWrite -VM $VMConfig -ManagedDiskId $dataDisk.Id -CreateOption Attach
$diskConfig=$dataDisk=$disk=$null }
   } 
$VMConfig = Add-AzureRmVMNetworkInterface -VM $VMConfig -Id $Nic.Id
New-AzureRmVM -VM $VMConfig -ResourceGroupName $ResourceGroupName -Location $Osdisk.Location

#Tags

$resource_tags = @{GAR_ID=$GAR_ID; NAME=$resourceGroupName; APPLICATION=$APPLICATION; ITSM_NR=$ITSM_NR; REMARK=$REMARK}
Set-AzureRmResourceGroup -Tag $resource_tags -Name $resourceGroupName


$server_tags =  @{GAR_ID=$GAR_ID; NAME=$VMname; APPLICATION=$APPLICATION; ITSM_NR=$ITSM_NR; REMARK=$REMARK; AutoShutdownSchedule=$AutoShutdownSchedule; ROLE = $ROLE; BACKUP=$BACKUP}
Set-AzureRmResource -ResourceGroupName $resourceGroupName -Name $VMname -ResourceType "Microsoft.Compute/VirtualMachines" -Tag $server_tags -force


$TrDisks = Get-AzureRmDisk -ResourceGroupName $resourceGroupName
$disknames = $TrDisks | where{$_.Name -like "*$VMName*"} 
$disknames = $disknames.Name
$disknames
foreach ($diskname in $disknames)
{
$managedDisk_tags =  @{GAR_ID=$GAR_ID; NAME=$diskname; APPLICATION=$APPLICATION; ITSM_NR=$ITSM_NR}
Set-AzureRmResource -ResourceGroupName $resourceGroupName -Name $diskname -ResourceType "Microsoft.Compute/disks" -Tag $managedDisk_tags -force
}

$nw_tags =  @{GAR_ID=$GAR_ID; NAME=$Nic.Name; VMNAME=$VMname; ITSM_NR=$ITSM_NR}
Set-AzureRmResource -ResourceGroupName $resourceGroupName -Name $Nic.Name -ResourceType "Microsoft.Network/networkInterfaces" -Tag $nw_tags -force
#Tags end

$VMConfig=$SubscriptionId=$ResourceGroupName=$Osdisk=$null }

    else { Write-Host "Disk not found with name of $MigrationVMname" -ForegroundColor Yellow }

 Write-Host "Script is completed for $VMName" -ForegroundColor Yellow }

      else {Write-Host ("NIC " + "$VMName"+"-nic01 is not exist in ResourceGroup $ResourceGroupName") -ForegroundColor Yellow}
    } 

 else {Write-Host "Check the VM $VMName is already exist in ResourceGroup $ResourceGroupName " -ForegroundColor Yellow}
 }

#END

