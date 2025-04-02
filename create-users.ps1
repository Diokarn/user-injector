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

# Définition des paramètres du domaine
$domainName = "RAGNARDC.lan"
$netbiosName = "RAGNARDC"
$adminPassword = (ConvertTo-SecureString "Admin123!" -AsPlainText -Force)
$SafeModeAdminPassword = (ConvertTo-SecureString "Admin123!" -AsPlainText -Force)

# Vérification et installation du rôle AD DS
if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
    Write-Host "Le rôle ADDS n'est pas installé. Installation en cours..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "Installation du rôle ADDS terminée."
    Restart-Computer -Force
    exit
} else {
    Write-Host "Le rôle ADDS est déjà installé. Reprise du script après redémarrage."
}

# Fonction pour vérifier si le serveur est un contrôleur de domaine
function Check-IfDomainController {
    try {
        $domain = Get-ADDomain -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Promotion du serveur en contrôleur de domaine si nécessaire
if (-not (Check-IfDomainController)) {
    Write-Host "Promotion du serveur en tant que contrôleur de domaine..."
    Install-ADDSForest `
        -DomainName $domainName `
        -DomainNetbiosName $netbiosName `
        -SafeModeAdministratorPassword $SafeModeAdminPassword `
        -CreateDnsDelegation:$false `
        -DatabasePath "C:\Windows\NTDS" `
        -LogPath "C:\Windows\NTDS" `
        -SysvolPath "C:\Windows\SYSVOL" `
        -Force `
        -NoRebootOnCompletion:$false
    Write-Host "Promotion terminée, redémarrage en cours..."
    Restart-Computer -Force
    exit
} else {
    Write-Host "Le serveur est déjà un contrôleur de domaine."
}

# Attente que les services AD soient opérationnels après redémarrage
Write-Host "Vérification de la disponibilité des services AD..."
Start-Sleep -Seconds 10
while (-not (Test-ComputerSecureChannel -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 5
}
Write-Host "Le serveur est maintenant un contrôleur de domaine et les services AD sont opérationnels."

# Création des unités d'organisation
$ouList = @(
    "OU=Utilisateurs,DC=RAGNARDC=lan",
    "OU=Client,OU=Utilisateurs,DC=RAGNARDC,DC=lan",
    "OU=Administrateur,OU=Utilisateurs,DC=RAGNARDC,DC=lan"
)

foreach ($ou in $ouList) {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name ($ou -split ",")[0].Substring(3) -Path ($ou -replace "^OU=[^,]+,", "") -ProtectedFromAccidentalDeletion $false
        Write-Host "Unité d'organisation créée : $ou"
    } else {
        Write-Host "L'unité d'organisation existe déjà : $ou"
    }
}

# Lecture et création des utilisateurs
function Create-ADUserFromCSV {
    param (
        [string]$csvPath,
        [string]$ouPath
    )
    $users = Import-Csv -Path $csvPath
    foreach ($user in $users) {
        # Vérification si les valeurs first_name et last_name ne sont pas vides
        if (![string]::IsNullOrWhiteSpace($user.first_name) -and ![string]::IsNullOrWhiteSpace($user.last_name)) {
            # Construction du SamAccountName en utilisant first_name et last_name
            $SamAccountName = "$($user.first_name.Trim()).$($user.last_name.Trim())"  # On enlève les espaces superflus

            # Validation du format du SamAccountName
            if ($SamAccountName -match "^[a-zA-Z0-9._-]+$") {
                if (-not (Get-ADUser -Filter {SamAccountName -eq $SamAccountName} -ErrorAction SilentlyContinue)) {
                    # Création du mot de passe sécurisé
                    $Password = ConvertTo-SecureString $user.password -AsPlainText -Force

                    # Création de l'utilisateur AD
                    New-ADUser `
                        -GivenName $user.first_name `
                        -Surname $user.last_name `
                        -Name "$($user.first_name) $($user.last_name)" `
                        -SamAccountName $SamAccountName `
                        -UserPrincipalName "$SamAccountName@$domainName" `
                        -Path $ouPath `
                        -AccountPassword $Password `
                        -Enabled $true `
                        -ChangePasswordAtLogon $false

                    Write-Host "Utilisateur créé : $SamAccountName"
                } else {
                    Write-Host "L'utilisateur existe déjà : $SamAccountName"
                }
            } else {
                Write-Host "Le nom de compte pour $($user.first_name) $($user.last_name) est invalide (caractères non autorisés)." -ForegroundColor Red
            }
        } else {
            Write-Host "Le prénom ou le nom est manquant pour un utilisateur dans le fichier CSV." -ForegroundColor Red
        }
    }
}


Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\users.csv" -ouPath "OU=Client,OU=Utilisateurs,DC=RAGNARDC,DC=lan"
Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\admin.csv" -ouPath "OU=Administrateur,OU=Utilisateurs,DC=RAGNARDC,DC=lan"

Write-Host "Opération terminée."
