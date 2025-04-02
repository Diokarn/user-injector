param (
    [switch]$DryRun, # Permet d'exécuter le script en mode simulation sans appliquer les modifications
    [string]$NewComputerName, # Nom que la machine prendra après le renommage
    [string]$StaticIP, # Adresse IP statique à attribuer
    [string]$SubnetMask, # Masque de sous-réseau pour l'IP fixe
    [string]$Gateway, # Passerelle par défaut
    [string[]]$DNSServers # Liste des serveurs DNS à configurer
)

# Vérification et application de l'IP fixe
$networkAdapter = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue
if ($networkAdapter -and $networkAdapter.PrefixOrigin -eq 'Manual') {
    # Si l'adresse IP est déjà configurée en mode manuel (statique), afficher un message
    Write-Host "L'adresse IP est déjà statique." -ForegroundColor Green
} else {
    # Si l'adresse IP n'est pas statique, vérifier si tous les paramètres sont fournis
    if ($StaticIP -and $SubnetMask -and $Gateway -and $DNSServers) {
        # Récupérer l'adaptateur réseau actif
        $adapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
        if ($adapter) {
            # Si un adaptateur actif est trouvé, configurer l'IP fixe
            Write-Host "Configuration de l'IP fixe..." -ForegroundColor Cyan
            New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $StaticIP -PrefixLength $SubnetMask -DefaultGateway $Gateway
            # Configuration des serveurs DNS
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers
        } else {
            # Si aucun adaptateur réseau actif n'est trouvé
            Write-Host "Aucune carte réseau active trouvée." -ForegroundColor Red
        }
    } else {
        # Si les paramètres nécessaires pour l'IP statique sont incomplets
        Write-Host "Les paramètres d'IP statique sont incomplets." -ForegroundColor Red
    }
}

# Renommage de la machine si nécessaire
if ($NewComputerName) {
    # Récupérer le nom actuel de la machine
    $currentName = $env:COMPUTERNAME
    if ($currentName -ne $NewComputerName) {
        # Si le nom actuel est différent du nom souhaité, procéder au renommage
        Write-Host "Renommage de la machine de $currentName en $NewComputerName..." -ForegroundColor Cyan
        Rename-Computer -NewName $NewComputerName -Force -ErrorAction Stop
        # Un redémarrage est nécessaire après le changement de nom
        Write-Host "Redémarrage nécessaire après le changement de nom..." -ForegroundColor Yellow
        Restart-Computer -Force
        exit
    } else {
        # Si le nom est déjà correct
        Write-Host "Le nom de la machine est déjà $NewComputerName." -ForegroundColor Green
    }
}

# Définition des paramètres du domaine
$domainName = "RAGNARDC.lan" # Nom complet du domaine
$netbiosName = "RAGNARDC" # Nom NetBIOS du domaine
$adminPassword = (ConvertTo-SecureString "Admin123!" -AsPlainText -Force) # Mot de passe administrateur
$SafeModeAdminPassword = (ConvertTo-SecureString "Admin123!" -AsPlainText -Force) # Mot de passe pour le mode de restauration des services d'annuaire

# Vérification et installation du rôle AD DS
if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
    # Si le rôle AD DS n'est pas installé, procéder à l'installation
    Write-Host "Le rôle ADDS n'est pas installé. Installation en cours..."
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "Installation du rôle ADDS terminée."
    # Redémarrer l'ordinateur pour appliquer l'installation
    Restart-Computer -Force
    exit
} else {
    # Si le rôle est déjà installé, afficher un message
    Write-Host "Le rôle ADDS est déjà installé. Reprise du script après redémarrage."
}

# Fonction pour vérifier si le serveur est un contrôleur de domaine
function Check-IfDomainController {
    try {
        # Tentative de récupération des informations du domaine
        $domain = Get-ADDomain -ErrorAction Stop
        return $true # Si réussi, le serveur est un contrôleur de domaine
    } catch {
        # Si échec, le serveur n'est pas un contrôleur de domaine
        return $false
    }
}

# Promotion du serveur en contrôleur de domaine si nécessaire
if (-not (Check-IfDomainController)) {
    # Si le serveur n'est pas encore un contrôleur de domaine, procéder à la promotion
    Write-Host "Promotion du serveur en tant que contrôleur de domaine..."
    Install-ADDSForest `
        -DomainName $domainName ` # Spécifier le nom complet du domaine
        -DomainNetbiosName $netbiosName ` # Spécifier le nom NetBIOS du domaine
        -SafeModeAdministratorPassword $SafeModeAdminPassword ` # Spécifier le mot de passe de l'administrateur pour le mode restauration
        -CreateDnsDelegation:$false ` # Ne pas créer de délégation DNS
        -DatabasePath "C:\Windows\NTDS" ` # Emplacement de la base de données NTDS
        -LogPath "C:\Windows\NTDS" ` # Emplacement des journaux de la base de données NTDS
        -SysvolPath "C:\Windows\SYSVOL" ` # Emplacement du dossier SYSVOL
        -Force ` # Exécution forcée sans confirmation
        -NoRebootOnCompletion:$false # Redémarrer l'ordinateur après la promotion
    Write-Host "Promotion terminée, redémarrage en cours..."
    Restart-Computer -Force
    exit
} else {
    # Si le serveur est déjà un contrôleur de domaine
    Write-Host "Le serveur est déjà un contrôleur de domaine."
}

# Attente que les services AD soient opérationnels après redémarrage
Write-Host "Vérification de la disponibilité des services AD..."
try {
    # Vérification si le serveur est bien un contrôleur de domaine
    $domain = Get-ADDomain -ErrorAction Stop
    Write-Host "Le serveur est maintenant un contrôleur de domaine et les services AD sont opérationnels."
} catch {
    # Si la connexion au domaine échoue, afficher un message mais poursuivre le script
    Write-Host "Attention : Impossible de confirmer la connexion au domaine, mais le script continue."
}

# Création des unités d'organisation
$ouList = @(
    "OU=Utilisateurs,DC=RAGNARDC,DC=lan", # Unité d'organisation pour les utilisateurs
    "OU=Client,OU=Utilisateurs,DC=RAGNARDC,DC=lan", # Unité d'organisation pour les clients
    "OU=Administrateur,OU=Utilisateurs,DC=RAGNARDC,DC=lan" # Unité d'organisation pour les administrateurs
)

# Création de chaque unité d'organisation si elle n'existe pas déjà
foreach ($ou in $ouList) {
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ou'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name ($ou -split ",")[0].Substring(3) -Path ($ou -replace "^OU=[^,]+,", "") -ProtectedFromAccidentalDeletion $false
        Write-Host "Unité d'organisation créée : $ou"
    } else {
        Write-Host "L'unité d'organisation existe déjà : $ou"
    }
}

# Lecture et création des utilisateurs à partir des fichiers CSV
function Create-ADUserFromCSV {
    param (
        [string]$csvPath, # Chemin du fichier CSV contenant les informations des utilisateurs
        [string]$ouPath # Chemin de l'unité d'organisation où les utilisateurs doivent être créés
    )
    # Importation des utilisateurs depuis le fichier CSV
    $users = Import-Csv -Path $csvPath
    foreach ($user in $users) {
        # Vérification que les champs first_name et last_name ne sont pas vides
        if (![string]::IsNullOrWhiteSpace($user.first_name) -and ![string]::IsNullOrWhiteSpace($user.last_name)) {
            # Construction du SamAccountName avec le prénom et le nom
            $SamAccountName = "$($user.first_name.Trim()).$($user.last_name.Trim())"  # Retirer les espaces superflus

            # Validation du format du SamAccountName (caractères autorisés uniquement)
            if ($SamAccountName -match "^[a-zA-Z0-9._-]+$") {
                # Vérification si l'utilisateur existe déjà dans AD
                if (-not (Get-ADUser -Filter {SamAccountName -eq $SamAccountName} -ErrorAction SilentlyContinue)) {
                    # Création du mot de passe sécurisé pour l'utilisateur
                    $Password = ConvertTo-SecureString $user.password -AsPlainText -Force

                    # Création de l'utilisateur dans Active Directory
                      New-ADUser `
                        -GivenName $user.first_name ` # Prénom de l'utilisateur, récupéré à partir du CSV
                        -Surname $user.last_name ` # Nom de famille de l'utilisateur, récupéré à partir du CSV
                        -Name "$($user.first_name) $($user.last_name)" ` # Nom complet de l'utilisateur, composé du prénom et du nom
                        -SamAccountName $SamAccountName ` # Nom d'utilisateur (SamAccountName) généré à partir du prénom et nom
                        -UserPrincipalName "$SamAccountName@$domainName" ` # UPN (User Principal Name) formaté en adresse e-mail (ex: utilisateur@domaine.com)
                        -Path $ouPath ` # Chemin dans l'Active Directory où l'utilisateur sera créé (unité d'organisation spécifiée)
                        -AccountPassword $Password ` # Mot de passe de l'utilisateur, converti en format sécurisé
                        -Enabled $true ` # Activation du compte de l'utilisateur
                        -ChangePasswordAtLogon $false # L'utilisateur ne sera pas obligé de changer son mot de passe lors de la première connexion

                    Write-Host "Utilisateur créé : $SamAccountName" # Affichage du message confirmant la création de l'utilisateur
                } else {
                    Write-Host "L'utilisateur existe déjà : $SamAccountName" # Si l'utilisateur existe déjà, un message d'avertissement est affiché
                }
            } else {
                Write-Host "Le nom de compte pour $($user.first_name) $($user.last_name) est invalide (caractères non autorisés)." -ForegroundColor Red # Si le SamAccountName contient des caractères invalides, un message d'erreur est affiché
            }
        } else {
            Write-Host "Le prénom ou le nom est manquant pour un utilisateur dans le fichier CSV." -ForegroundColor Red # Si le prénom ou le nom est manquant, un message d'erreur est affiché
        }
    }
}


# Appel de la fonction pour créer des utilisateurs depuis les fichiers CSV
Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\users.csv" -ouPath "OU=Client,OU=Utilisateurs,DC=RAGNARDC,DC=lan"
Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\admin.csv" -ouPath "OU=Administrateur,OU=Utilisateurs,DC=RAGNARDC,DC=lan"

# Message de fin
Write-Host "Opération terminée."