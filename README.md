# user-injector
Pour peupler l'AD de façon automatisé avec des fichiers csv:
Télécharger le zip sur https://github.com/Diokarn/user-injector/archive/refs/heads/main.zip
Créer à la racine de C:\ un dossier Scripts, dans Script un dossier user-injector dans lequel vous viendrais extraire le dossier user-injector-main (C:\Scripts\user-injector\user-injector-main)
Ou taper cette commande dans Powershell pour créer les dossiers et télécharger le zip automatiquement.


$RepoUrl = "https://github.com/Diokarn/user-injector/archive/refs/heads/main.zip"
$DestinationPath = "C:\Scripts\user-injector"
$ZipPath = "$DestinationPath\repo.zip"

if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
}

Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath

Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force

Remove-Item $ZipPath

Pour ce tp j'ai utilisé un générateur de fichier csv avec des noms aléatoire, vous pouvez modifier les fichiers csv à condition de soit les renommés admin.csv et users.csv ou sois de changer le nom de ses fichiers à condition de bien le modifier dans le fichier create-users.ps1 à ces lignes :

$CsvFiles = @{
    "C:\Scripts\user-injector\user-injector-main\users.csv" = "OU=Client,OU=Utilisateurs,DC=RAGNAR,DC=lan"
    "C:\Scripts\user-injector\user-injector-main\admin.csv" = "OU=Administrateur,OU=Utilisateurs,DC=RAGNAR,DC=lan"
}

Vous devez aussi changer les informations en fonction de votre Active Directory dans ces mêmes lignes.

$CsvFiles = @{
    "C:\Scripts\user-injector\user-injector-main\users.csv" = "OU=Client,OU=Utilisateurs,DC=RAGNAR,DC=lan"
    "C:\Scripts\user-injector\user-injector-main\admin.csv" = "OU=Administrateur,OU=Utilisateurs,DC=RAGNAR,DC=lan"
}

Une fois les modifications faites, vous pouvez lancer cette commande qui exécutera le script :

-D'abord en -DryRun (pour tester si le code s'exécute sans erreurs)

cd C:\Scripts\user-injector\user-injector-main
.\create-users.ps1 -DryRun

-Ensuite en exécutant directement la commande sur -DryRun

cd C:\Scripts\user-injector\user-injector-main
.\create-users.ps1