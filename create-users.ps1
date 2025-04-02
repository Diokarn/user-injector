# Vérifier si ADDS est installé
$ADDSFeature = Get-WindowsFeature -Name AD-Domain-Services
if (-not $ADDSFeature.Installed) {
    Write-Host "Le rôle ADDS n'est pas installé. Installation en cours..." -ForegroundColor Cyan
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
} else {
    Write-Host "Le rôle ADDS est déjà installé." -ForegroundColor Green
}

# Vérifier si le serveur est déjà un contrôleur de domaine
try {
    $DomainInfo = Get-ADDomain
    Write-Host "Le serveur est déjà un contrôleur de domaine." -ForegroundColor Green
} catch {
    Write-Host "Le serveur n'est pas encore un contrôleur de domaine, promotion en cours..." -ForegroundColor Cyan
    
    # Promotion en tant que DC
    Import-Module ADDSDeployment
    Install-ADDSForest -DomainName "RAGNAR.lan" `
                       -DomainNetbiosName "RAGNAR" `
                       -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) `
                       -Force

    Write-Host "Redémarrage du serveur après la promotion..." -ForegroundColor Yellow
    Restart-Computer -Force
    exit
}

# Vérification après redémarrage
Write-Host "Vérification post-redémarrage..." -ForegroundColor Cyan

# Vérifier si le serveur est bien devenu DC après redémarrage
$retryCount = 0
$maxRetries = 15
$waitTime = 10 # Secondes entre chaque tentative

while ($true) {
    try {
        $DomainInfo = Get-ADDomain
        Write-Host "Le serveur est maintenant un contrôleur de domaine et les services AD sont opérationnels." -ForegroundColor Green
        break
    } catch {
        Write-Host "Le serveur n'est pas encore un DC. Tentative $retryCount/$maxRetries..." -ForegroundColor Yellow
        Start-Sleep -Seconds $waitTime
        $retryCount++

        if ($retryCount -eq $maxRetries) {
            Write-Host "Échec : Le serveur ne semble pas être un contrôleur de domaine après $maxRetries tentatives." -ForegroundColor Red
            exit 1
        }
    }
}

# Suite du script...
Write-Host "Configuration AD terminée, passage à l'étape suivante." -ForegroundColor Cyan
