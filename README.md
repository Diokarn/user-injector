# Créer un ADDS et DNS + peupler un AD avec des utilisateurs
## Je vous conseil de lire ce README 

Pour créer un ADDS DNS il faut commencer par :

Installer une version de Windows Serveur

Taper cette commande dans Powershell pour créer les dossiers et télécharger le zip automatiquement :

    $RepoUrl = "https://github.com/Diokarn/user-injector/archive/refs/heads/main.zip"
    $DestinationPath = "C:\Scripts\user-injector"
    $ZipPath = "$DestinationPath\repo.zip"
    if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
    }
    Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
    Remove-Item $ZipPath


Fixer l'adresse IP manuellement dans le fichier create-users.ps1 à la ligne 1 

    [string]$StaticIP = TONIPDUSERVEUR,

Changer le nom du serveur dans le fichier create-users.ps1 à la ligne 2 

    [string]$NewComputerName = TONNOMDUSERVEUR,

Mettre le SubnetMask dans le fichier create-users.ps1 à la ligne 3 

    [string]$SubnetMask = TONSUBNETMASK,

Indiquer la Gateway dans le fichier create-users.ps1 à la ligne 4 

    [string]$Gateway = TAGATEWAY,

Indiquer le DNS dans le fichier create-users.ps1 à la ligne 5 

    [string[]]$DNSServers = 127.0.0.1,


Il faut changer ces deux lignes en fonction du nom de domaine voulu à la ligne 45 et 46 :

    $domainName = "RAGNARDC.lan"
    $netbiosName = "RAGNARDC"

Il faut aussi changer ces trois lignes pour créer les OU souhaitées et changer au passage le nom du DC, à la ligne 100,101,102 :

    $ouList = @(
        "OU=Utilisateurs,DC=RAGNARDC,DC=lan",
        "OU=Client,OU=Utilisateurs,DC=RAGNARDC,DC=lan",
        "OU=Administrateur,OU=Utilisateurs,DC=RAGNARDC,DC=lan"
    )

Et une dernière modification en modifiant bien les OU renseigné plus haut et de changer le nom du DC à la ligne 159 et 160 :

    Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\users.csv" -ouPath "OU=Client,OU=Utilisateurs,DC=RAGNARDC,DC=lan"

    Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\admin.csv" -ouPath "OU=Administrateur,OU=Utilisateurs,DC=RAGNARDC,DC=lan"

Faites attention au nom des fichiers CSV et à leurs formats, dans ce cas précis, mon fichier csv est configurer de cette sorte : first_name,last_name,password, le code correspond à ce format et les noms des fichiers sont admin.csv et users.csv

Une fois les dossiers crées et les modifications faites dans le fichier create-users.ps1, vous pouvez lancer cette commande qui exécutera le script :

-D'abord en -DryRun (pour tester si le code s'exécute sans erreurs)

    cd C:\Scripts\user-injector\user-injector-main
    .\create-users.ps1 -DryRun

-Ensuite, en exécutant directement la commande sans -DryRun

    cd C:\Scripts\user-injector\user-injector-main
    .\create-users.ps1

Powershell va créer l'ADDS sur le serveur puis redémarrer
Une fois redémarrer, il faudra redémarrer le script une nouvelle fois avec cette commande :

    cd C:\Scripts\user-injector\user-injector-main
    .\create-users.ps1

Il va passer le serveur en contrôleur de domaine, installer le DNS et redémarrer une nouvelle fois
Après le redémarrage relancer une nouvelle fois cette commande :

    cd C:\Scripts\user-injector\user-injector-main
    .\create-users.ps1

Cette fois, il va créer les OU et les utilisateurs des fichiers CSV