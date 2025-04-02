param (
    [switch]$DryRun, # Permet d'exécuter le script en mode simulation sans appliquer les modifications
    [string]$NewComputerName, # Nom que la machine prendra après le renommage
    [string]$StaticIP, # Adresse IP statique à attribuer
    [string]$SubnetMask, # Masque de sous-réseau pour l'IP fixe
    [string]$Gateway, # Passerelle par défaut
    [string[]]$DNSServers # Serveurs DNS à configurer
)

# Vérification et application de l'IP fixe
$networkAdapter = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($networkAdapter -and $networkAdapter.PrefixOrigin -eq 'Manual') {
    Write-Host "L'adresse IP est déjà statique." -ForegroundColor Green
} else {
    if ($StaticIP -and $SubnetMask -and $Gateway -and $DNSServers) {
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        if ($adapter) {
            Write-Host "Configuration de l'IP fixe..." -ForegroundColor Cyan
            New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $StaticIP -PrefixLength $SubnetMask -DefaultGateway $Gateway
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers
        } else {
            Write-Host "Aucune carte réseau active trouvée." -ForegroundColor Red
        }
    } else {
        Write-Host "Les paramètres d'IP statique sont incomplets." -ForegroundColor Red
    }
}

# Renommage de la machine si nécessaire
if ($NewComputerName) {
    $currentName = $env:COMPUTERNAME
    if ($currentName -ne $NewComputerName) {
        Write-Host "Renommage de la machine de $currentName en $NewComputerName..." -ForegroundColor Cyan
        Rename-Computer -NewName $NewComputerName -Force -ErrorAction Stop
        Write-Host "Redémarrage nécessaire après le changement de nom..." -ForegroundColor Yellow
        Restart-Computer -Force
        exit
    } else {
        Write-Host "Le nom de la machine est déjà $NewComputerName." -ForegroundColor Green
    }
}

# Vérification du module Active Directory
$ADModule = Get-Module -ListAvailable -Name ActiveDirectory
if (-not $ADModule) {
    Write-Host "Le module Active Directory n'est pas installé. Installation en cours..." -ForegroundColor Cyan
    # Installation du module RSAT (si nécessaire)
    if (-not (Get-WindowsFeature RSAT-AD-PowerShell).Installed) {
        Install-WindowsFeature RSAT-AD-PowerShell
    }
}

# Après l'installation, importation du module Active Directory
Import-Module ActiveDirectory

# Vérifier si le rôle ADDS est déjà installé
$ADDSFeature = Get-WindowsFeature -Name AD-Domain-Services
if ($ADDSFeature.Installed) {
    Write-Host "Le rôle ADDS est déjà installé." -ForegroundColor Green
} else {
    Write-Host "Le rôle ADDS n'est pas installé. Installation en cours..." -ForegroundColor Cyan
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
}

# Vérification du serveur contrôleur de domaine
if (-not (Test-ComputerSecureChannel -ErrorAction SilentlyContinue)) {
    Write-Host "Le serveur n'est pas encore un contrôleur de domaine, promotion en cours..." -ForegroundColor Cyan
    Import-Module ADDSDeployment
    Install-ADDSForest -DomainName "RAGNAR.lan" `
                       -DomainNetbiosName "RAGNAR" `
                       -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force) `
                       -Force

    Write-Host "Redémarrage du serveur pour finaliser la promotion..." -ForegroundColor Yellow
    Restart-Computer -Force
    exit
} else {
    Write-Host "Le serveur est déjà un contrôleur de domaine." -ForegroundColor Green
}

# Une fois le redémarrage effectué, on laisse un peu de temps avant de continuer
Start-Sleep -Seconds 60  # Pause pour que les services AD se stabilisent

# Vérification de la disponibilité des services AD
Write-Host "Vérification de la disponibilité des services AD..." -ForegroundColor Cyan
$retryCount = 0
$maxRetries = 10
$waitTime = 10  # Temps d'attente entre chaque tentative en secondes

while (-not (Test-ComputerSecureChannel -ErrorAction SilentlyContinue) -and $retryCount -lt $maxRetries) {
    Write-Host "Les services AD ne sont pas encore disponibles. Tentative $retryCount/$maxRetries..." -ForegroundColor Yellow
    Start-Sleep -Seconds $waitTime
    $retryCount++
}

if ($retryCount -eq $maxRetries) {
    Write-Host "Échec : Les services AD ne sont toujours pas disponibles après $maxRetries tentatives." -ForegroundColor Red
    exit 1
}

Write-Host "Le serveur est maintenant un contrôleur de domaine et les services AD sont opérationnels." -ForegroundColor Green

# Création des unités d'organisation (OU) après la promotion
Write-Host "Création des unités d'organisation..." -ForegroundColor Cyan
$OUs = @("OU=Client,OU=Utilisateurs,DC=RAGNAR,DC=lan", "OU=Administrateur,OU=Utilisateurs,DC=RAGNAR,DC=lan")
foreach ($OU in $OUs) {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$OU'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name ($OU -split ",")[0].Replace("OU=", "") -Path ($OU -replace "^[^,]+,", "") -ProtectedFromAccidentalDeletion $false
    }
}

# Définition des fichiers CSV contenant les informations des utilisateurs
$CsvFiles = @{
    "C:\Scripts\user-injector\user-injector-main\users.csv" = "OU=Client,OU=Utilisateurs,DC=RAGNAR,DC=lan"
    "C:\Scripts\user-injector\user-injector-main\admin.csv" = "OU=Administrateur,OU=Utilisateurs,DC=RAGNAR,DC=lan"
}

# Vérification de la connexion à Active Directory
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Host "Le module Active Directory n'est pas disponible. Assurez-vous que vous êtes sur un contrôleur de domaine ou que les RSAT sont installés." -ForegroundColor Red
    exit 1
}

# Lecture des fichiers CSV et création des utilisateurs
foreach ($CsvPath in $CsvFiles.Keys) {
    $TargetOU = $CsvFiles[$CsvPath]
    
    if (-not (Test-Path $CsvPath)) {
        Write-Host "Le fichier CSV spécifié n'existe pas : $CsvPath" -ForegroundColor Red
        continue
    }

    Write-Host "Traitement du fichier $CsvPath pour l'OU $TargetOU" -ForegroundColor Cyan
    
    $users = Import-Csv -Path $CsvPath

    foreach ($user in $users) {
        $username = "$($user.first_name).$($user.last_name)".ToLower()
        $password = ConvertTo-SecureString $user.password -AsPlainText -Force
        $displayName = "$($user.first_name) $($user.last_name)"
        $userPrincipalName = "$username@RAGNAR.lan"
        
        Write-Host "Création de l'utilisateur : $displayName ($username)" -ForegroundColor Cyan
        
        if ($DryRun) {
            Write-Host "[Dry Run] Ajout de l'utilisateur $username à $TargetOU" -ForegroundColor Yellow
        } else {
            New-ADUser -SamAccountName $username `
            -UserPrincipalName $userPrincipalName `
            -Name $displayName `
            -GivenName $user.first_name `
            -Surname $user.last_name `
            -Path $TargetOU `
            -AccountPassword $password `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -PassThru
        }
    }
}

Write-Host "Opération terminée." -ForegroundColor Green
