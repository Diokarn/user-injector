# 🚀 Création d'un ADDS et DNS + Peuplement d'un Active Directory

Ce guide vous explique comment installer un Active Directory Domain Services (ADDS) et un serveur DNS sur Windows Server, puis y ajouter des utilisateurs en utilisant un script PowerShell.

## 📌 Prérequis
- Une installation de **Windows Server**.
- Un accès administrateur sur le serveur.
- PowerShell.
- Une connexion Internet pour télécharger les scripts.

---

## 📥 1. Téléchargement du Script

Exécutez la commande suivante dans PowerShell pour créer les dossiers nécessaires et télécharger automatiquement le script :

```powershell
$RepoUrl = "https://github.com/Diokarn/user-injector/archive/refs/heads/main.zip"
$DestinationPath = "C:\Scripts\user-injector"
$ZipPath = "$DestinationPath\repo.zip"

if (-not (Test-Path $DestinationPath)) {
    New-Item -ItemType Directory -Path $DestinationPath | Out-Null
}

Invoke-WebRequest -Uri $RepoUrl -OutFile $ZipPath
Expand-Archive -Path $ZipPath -DestinationPath $DestinationPath -Force
Remove-Item $ZipPath
```

---

## ⚙️ 2. Configuration des Paramètres du Script

Avant d'exécuter le script, modifiez les paramètres suivants dans le fichier `create-users.ps1` :

1. **Adresse IP du serveur** (ligne 1) :
   ```powershell
   [string]$StaticIP = "TONIPDUSERVEUR"
   ```
2. **Nom du serveur** (ligne 2) :
   ```powershell
   [string]$NewComputerName = "TONNOMDUSERVEUR"
   ```
3. **Subnet Mask** (ligne 3) :
   ```powershell
   [string]$SubnetMask = "TONSUBNETMASK"
   ```
4. **Gateway** (ligne 4) :
   ```powershell
   [string]$Gateway = "TAGATEWAY"
   ```
5. **DNS** (ligne 5) :
   ```powershell
   [string[]]$DNSServers = "127.0.0.1"
   ```

---

## 🌐 3. Configuration du Domaine et des OUs

1. **Nom du domaine** (ligne 45 et 46) :
   ```powershell
   $domainName = "VOTREDOMAINE.lan"
   $netbiosName = "VOTREDOMAINE"
   ```
2. **Unités Organisationnelles (OU)** (ligne 100-102) :
   ```powershell
   $ouList = @(
       "OU=Utilisateurs,DC=VOTREDOMAINE,DC=lan",
       "OU=Client,OU=Utilisateurs,DC=VOTREDOMAINE,DC=lan",
       "OU=Administrateur,OU=Utilisateurs,DC=VOTREDOMAINE,DC=lan"
   )
   ```
3. **Importation des utilisateurs CSV** (ligne 159-160) :
   ```powershell
   Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\users.csv" -ouPath "OU=Client,OU=Utilisateurs,DC=VOTREDOMAINE,DC=lan"
   Create-ADUserFromCSV -csvPath "C:\Scripts\user-injector\user-injector-main\admin.csv" -ouPath "OU=Administrateur,OU=Utilisateurs,DC=VOTREDOMAINE,DC=lan"
   ```
   **⚠️ Attention** : Les fichiers CSV doivent respecter le format suivant : `first_name,last_name,password` et être nommés `admin.csv` et `users.csv`.

---

## ▶️ 4. Exécution du Script

### 🔍 4.1 Test du script en mode `DryRun`
Avant d'exécuter les modifications, vérifiez que le script fonctionne correctement :
```powershell
cd C:\Scripts\user-injector\user-injector-main
.\create-users.ps1 -DryRun
```

### 🚀 4.2 Exécution du script
Si tout est correct, lancez l'exécution complète :
```powershell
cd C:\Scripts\user-injector\user-injector-main
.\create-users.ps1
```

Le script va :
1. Installer l'ADDS et configurer le serveur comme **contrôleur de domaine**.
2. Installer le serveur DNS.
3. Redémarrer le serveur.

Après chaque redémarrage, relancez la commande suivante jusqu'à ce que toutes les étapes soient complétées :
```powershell
cd C:\Scripts\user-injector\user-injector-main
.\create-users.ps1
```

---

## ✅ 5. Vérification
Une fois le script terminé, vérifiez que :
- ✅ Le serveur est bien **contrôleur de domaine**.
- ✅ Le serveur DNS fonctionne correctement.
- ✅ Les utilisateurs et OUs sont bien créés.

---

## 📌 6. Remarques
- ℹ️ Si vous rencontrez des erreurs, exécutez le script en mode `DryRun` pour identifier les problèmes.
- 🔍 Vérifiez que les fichiers CSV sont bien formatés.
- 🛠️ Assurez-vous que les noms de domaine et les OUs correspondent à votre configuration.

**Bonne installation ! 🚀**

