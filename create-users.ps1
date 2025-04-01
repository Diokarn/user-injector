param(
    [string]$GithubRepoUrl = "https://raw.githubusercontent.com/Diokarn/user-injector/main",
    [switch]$DryRun
)

# Définition des chemins locaux des fichiers téléchargés
$csvUsersPath = "C:\Scripts\users.csv"
$csvAdminsPath = "C:\Scripts\admin.csv"

# Définition des OUs pour le domaine RAGNAR.lan
$OUClients = "OU=Client,OU=Utilisateurs,DC=RAGNAR,DC=lan"
$OUAdmins = "OU=Administrateur,OU=Utilisateurs,DC=RAGNAR,DC=lan"

# Fonction pour télécharger un fichier depuis GitHub
function Download-File {
    param(
        [string]$fileName,
        [string]$destinationPath
    )

    $fileUrl = "$GithubRepoUrl/$fileName"
    Write-Host "Téléchargement de $fileName depuis $fileUrl..."
    
    try {
        Invoke-WebRequest -Uri $fileUrl -OutFile $destinationPath -ErrorAction Stop
        Write-Host "Téléchargement réussi : $destinationPath"
    } catch {
        Write-Host "Erreur lors du téléchargement de $fileName : $_"
        exit 1
    }
}

# Fonction pour créer un utilisateur dans AD
function Create-User {
    param (
        [string]$firstName,
        [string]$lastName,
        [SecureString]$password,
        [string]$targetOU
    )

    $userName = "$firstName.$lastName"  # Format du SamAccountName

    # Vérifier si l'utilisateur existe déjà
    $existingUser = Get-ADUser -Filter {SamAccountName -eq $userName} -ErrorAction SilentlyContinue
    if ($existingUser) {
        Write-Host "L'utilisateur $userName existe déjà."
        return
    }

    # Si DryRun est activé, ne pas créer l'utilisateur mais afficher un message
    if ($DryRun) {
        Write-Host "DryRun : Création de l'utilisateur $userName avec mot de passe '$password' dans l'OU $targetOU"
    } else {
        # Création de l'utilisateur dans AD
        New-ADUser -SamAccountName $userName `
                   -UserPrincipalName "$userName@RAGNAR.lan" `
                   -GivenName $firstName `
                   -Surname $lastName `
                   -Name $userName `
                   -DisplayName "$firstName $lastName" `
                   -Path $targetOU `
                   -AccountPassword (ConvertTo-SecureString -AsPlainText $password -Force) `
                   -Enabled $true
        Write-Host "L'utilisateur $userName a été créé avec succès dans l'OU $targetOU"
    }
}

# Télécharger les fichiers depuis GitHub
Download-File -fileName "users.csv" -destinationPath $csvUsersPath
Download-File -fileName "admin.csv" -destinationPath $csvAdminsPath

# Importer et traiter les utilisateurs Clients
if (Test-Path $csvUsersPath) {
    $users = Import-Csv -Path $csvUsersPath
    Write-Host "Importation des utilisateurs Clients..."
    
    foreach ($user in $users) {
        Create-User -firstName $user.first_name -lastName $user.last_name -password $user.password -targetOU $OUClients
    }
} else {
    Write-Host "Le fichier $csvUsersPath est introuvable !"
}

# Importer et traiter les utilisateurs Administrateurs
if (Test-Path $csvAdminsPath) {
    $admins = Import-Csv -Path $csvAdminsPath
    Write-Host "Importation des Administrateurs..."
    
    foreach ($admin in $admins) {
        Create-User -firstName $admin.first_name -lastName $admin.last_name -password $admin.password -targetOU $OUAdmins
    }
} else {
    Write-Host "Le fichier $csvAdminsPath est introuvable !"
}

Write-Host "Opération terminée !"