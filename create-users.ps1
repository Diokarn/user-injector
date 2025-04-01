# Script PowerShell pour ajouter des utilisateurs à Active Directory
param (
    [switch]$DryRun
)

# Définition des fichiers CSV et des OUs correspondantes
$CsvFiles = @{
    "users.csv" = "OU=Client,OU=Utilisateurs,DC=RAGNAR,DC=lan"
    "admin.csv" = "OU=Administrateur,OU=Utilisateurs,DC=RAGNAR,DC=lan"
}

# Vérification de la connexion à Active Directory
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Host "Le module Active Directory n'est pas disponible. Assurez-vous que vous êtes sur un contrôleur de domaine ou que les RSAT sont installés." -ForegroundColor Red
    exit 1
}

# Parcours des fichiers CSV et traitement des utilisateurs
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
            New-ADUser -SamAccountName $username \
                       -UserPrincipalName $userPrincipalName \
                       -Name $displayName \
                       -GivenName $user.first_name \
                       -Surname $user.last_name \
                       -Path $TargetOU \
                       -AccountPassword $password \
                       -Enabled $true \
                       -PasswordNeverExpires $true \
                       -PassThru
        }
    }
}

Write-Host "Opération terminée." -ForegroundColor Green