if((Get-ServerComponentState -Identity $env:computername -Component "OwaProxy").State -eq "Active"){
    Write-Host "==================================================================================" -ForegroundColor Green
    Write-Host " " -ForegroundColor Green
    Write-Host "Der Wartungsmodus auf dem Exchange "$env:computername" ist zur Zeit deaktiviert!" -ForegroundColor Green
    Write-Host " " -ForegroundColor Green
    Write-Host "==================================================================================" -ForegroundColor Green
    Write-Host " " -ForegroundColor Green
    Write-Host " " -ForegroundColor Green
}else{
    Write-Host "==================================================================================" -ForegroundColor Red
    Write-Host " " -ForegroundColor Red
    Write-Host "Der Wartungsmodus auf dem Exchange "$env:computername" ist zur Zeit aktiviert!" -ForegroundColor Red
    Write-Host " " -ForegroundColor Red
    Write-Host "==================================================================================" -ForegroundColor Red
    Write-Host " " -ForegroundColor Red
    Write-Host " " -ForegroundColor Red
}

$Wartung = Read-Host "Wartungsmodus AUS (0) / Wartungsmodus EIN (1) - andere Eingabe zum abbrechen: "

if(!(($Wartung -eq 1) -or ($Wartung -eq 0))){
    Write-Host "Das Skript wurde Beendet" -ForegroundColor Red
    return; # breche Skript ab bei nicht (0 oder 1)
} 

$DAGNames =(Get-DatabaseAvailabilityGroup -Identity (Get-DatabaseAvailabilityGroup).Name).Servers.Name

if($DAGNames -le 1){
    Write-Host "Der Exchange ist kein Mitglied eines DAGs" -ForegroundColor Red
    return;
}

if($DAGNames[0] -eq $env:computername){
    $DAGName = $DAGNames[1] + "." + (Get-ADDomain).DNSRoot
}else{
    $DAGName = $DAGNames[0] + "." + (Get-ADDomain).DNSRoot
}

if($Wartung -eq 1){
    #Aktivieren des Wartungsmodus
    try{
        Set-ServerComponentState $env:computername -Component HubTransport -State Draining -Requester Maintenance
        Redirect-Message -Server $env:computername -Target $DAGName
        Restart-Service MSExchangeTransport
        Suspend-ClusterNode -Name $env:computername 
        Set-MailboxServer $env:computername -DatabaseCopyActivationDisabledAndMoveNow $True
        Set-MailboxServer $env:computername -DatabaseCopyAutoActivationPolicy Blocked
        Set-ServerComponentState $env:computername -Component ServerWideOffline -State Inactive -Requester Maintenance
        Restart-Service MSExchangeTransport
        Write-Host "Wartungsmodus auf " $env:computername " aktiviert!" -ForegroundColor Green
    }catch{
        Write-Host "Wartungsmodus auf " $env:computername " wurde mit Fehlern aktiviert!" -ForegroundColor Red
    }


} elseif($Wartung -eq 0){
    #Deaktivieren des Wartungsmodus
    try{
        Set-ServerComponentState $env:computername -Component ServerWideOffline -State Active -Requester Maintenance
        Resume-ClusterNode -Name $env:computername
        Set-MailboxServer $env:computername -DatabaseCopyAutoActivationPolicy Unrestricted
        Set-MailboxServer $env:computername -DatabaseCopyActivationDisabledAndMoveNow $false
        Set-ServerComponentState $env:computername -Component HubTransport -State Active -Requester Maintenance
        Restart-Service MSExchangeTransport
        Write-Host "Wartungsmodus auf " $env:computername " deaktiviert!" -ForegroundColor Green
    }catch{
        Write-Host "Wartungsmodus auf " $env:computername " wurde mit Fehlern deaktiviert!" -ForegroundColor Red
    }
}
