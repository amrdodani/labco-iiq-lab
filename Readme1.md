# SailPoint IdentityIQ v8.5 Lab Setup Guide

This README will help you set up a realistic company environment to master SailPoint IdentityIQ v8.5, Active Directory, MySQL, and GitHub integration. Each section explains:
- **Purpose:** Why this step is important for learning or lab automation.
- **How-To:** Concrete commands and file usage.
- **File Description:** What each script or file is for and when to use it.


## **1. Seed Data Preparation**

### 1.1. Create Active Directory Users CSV

**Purpose:**  
- Simulates real company user data for automated AD creation.
- Ensures repeatable and consistent setups.

**File:**  
`AD_Seed_Users.csv`
FirstName,LastName,Username,Department,Title,Email,Manager
Alice,Smith,asmith,Engineering,DevOps Engineer,alice.smith@labco.com,Robert
Bob,Jones,bjones,Sales,Sales Manager,bob.jones@labco.com,Alice
Carol,Tan,ctan,Finance,Accountant,carol.tan@labco.com,Bob


*Expand with as many rows as you like to simulate a full org.*

### 1.2. Automated AD User Creation Script

**Purpose:**  
- Imports the above CSV and creates users in AD under a dedicated OU.
- Sets up manager–employee relationships per your org chart.

**File:**  
`AD_Create_Users.ps1`  
*Save script below as `AD_Create_Users.ps1` in your lab setup folder (e.g., `C:\IIQ8.5 Lab_setup`).*

Set-StrictMode -Version Latest
Import-Module ActiveDirectory

$csvPath = 'C:\IIQ8.5 Lab_setup\AD_Seed_Users.csv'
$pwd = ConvertTo-SecureString 'Lab123$' -AsPlainText -Force

Optional: create/use a target OU
$domainDN = (Get-ADDomain).DistinguishedName
$ouName = 'Lab Users'
$ouPath = "OU=$ouName,$domainDN"
if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$ouName)" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
New-ADOrganizationalUnit -Name $ouName -Path $domainDN -ProtectedFromAccidentalDeletion:$false | Out-Null
}

Read CSV and sanity-check headers
$rows = Import-Csv $csvPath
$expected = 'FirstName','LastName','Username','Department','Title','Email','Manager'
$missing = $expected | Where-Object { $_ -notin $rows.PsObject.Properties.Name }
if ($missing) { throw "CSV missing columns: $($missing -join ', ')" }

Write-Host "=== PASS 1: Creating users (no Manager) ==="
foreach ($r in $rows) {
$sam = $r.Username.Trim()
if ([string]::IsNullOrWhiteSpace($sam)) { Write-Warning "Row missing Username; skipping."; continue }

$exists = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
if ($exists) { Write-Host "Exists: $sam"; continue }

$params = @{
Name = "$($r.FirstName.Trim()) $($r.LastName.Trim())"
SamAccountName = $sam
GivenName = $r.FirstName.Trim()
Surname = $r.LastName.Trim()
Department = $r.Department
Title = $r.Title
EmailAddress = $r.Email
Path = $ouPath
AccountPassword = $pwd
Enabled = $true
ChangePasswordAtLogon = $true
ErrorAction = 'Stop'
}

try {
New-ADUser @params
Write-Host "Created: $sam"
} catch {
Write-Warning "Failed ${sam}: $($_.Exception.Message)"
}
}

function Resolve-ManagerUser($value) {
if ([string]::IsNullOrWhiteSpace($value)) { return $null }
$val = $value.Trim()

DN?
if ($val -match '^(CN|OU|DC)=') {
try { return Get-ADUser -LDAPFilter "(distinguishedName=$val)" -ErrorAction Stop } catch { return $null }
}

Try SAM, UPN, or Display Name
try {
return Get-ADUser -Filter "SamAccountName -eq '$val' -or UserPrincipalName -eq '$val' -or Name -eq '$val'" -ErrorAction Stop
} catch { return $null }
}

Write-Host "=== PASS 2: Setting Manager where resolvable ==="
foreach ($r in $rows) {
$sam = $r.Username.Trim()
$user = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
if (-not $user) { Write-Warning "User not found for manager step: $sam"; continue }

$mgr = Resolve-ManagerUser $r.Manager
if ($mgr) {
Set-ADUser -Identity $user -Manager $mgr.DistinguishedName
Write-Host "Manager set: $sam -> $($mgr.SamAccountName)"
} else {
Write-Host "Manager unresolved for ${sam}: '$($r.Manager)'"
}
}

Write-Host "All done."


**How to run:**
Open PowerShell as Administrator
cd 'C:\IIQ8.5 Lab_setup'
.\AD_Create_Users.ps1



### 1.3. MySQL Seed Data

**Purpose:**  
- Simulates an HR/business application for SailPoint to read identities from.
- Enables you to test aggregation/provisioning.

**File:**  
`sql_seed_employees.sql`
CREATE DATABASE lab_hr;
USE lab_hr;

CREATE TABLE employees (
id INT AUTO_INCREMENT PRIMARY KEY,
first_name VARCHAR(30),
last_name VARCHAR(30),
username VARCHAR(30),
department VARCHAR(30),
title VARCHAR(50),
email VARCHAR(100)
);

INSERT INTO employees (first_name, last_name, username, department, title, email)
VALUES ('Alice', 'Smith', 'asmith', 'Engineering', 'DevOps Engineer', 'alice.smith@labco.com'),
('Bob', 'Jones', 'bjones', 'Sales', 'Sales Manager', 'bob.jones@labco.com'),
('Carol', 'Tan', 'ctan', 'Finance', 'Accountant', 'carol.tan@labco.com');



**How to load:**
-- Log in to MySQL Workbench or CLI:
-- (replace db credentials as needed)
source C:\IIQ8.5 Lab_setup\sql_seed_employees.sql;




## **2. Version Control with GitHub**

**Purpose:**  
- Keeps all scripts, seed files, and changes tracked for easy rollback or collaboration.
- Lets you share or repeat your lab easily.

**How to use:**

1. **Navigate to your setup folder:**
    
    cd "C:\IIQ8.5 Lab_setup"
 
2. **Initialize Git:**
   
    git init
 
3. **Add files:**
  
    git add AD_Seed_Users.csv AD_Create_Users.ps1 sql_seed_employees.sql
 
4. **Commit changes:**
   
    git commit -m "Initial seed and automation scripts"
   
5. **Create a new repo on GitHub website** (name: `labco-iiq-lab`)
6. **Add the remote:**
  
    git remote add origin https://github.com/[yourusername]/labco-iiq-lab.git
 
7. **Push files:**
   
    git branch -M main
    git push -u origin main
    

## **File Summary Table**

| File Name                | Purpose                                                  | How/Where Used                          |
|--------------------------|----------------------------------------------------------|-----------------------------------------|
| AD_Seed_Users.csv        | User, dept, manager seed info for AD and SailPoint       | Powershell, IIQ Demo, Audit             |
| AD_Create_Users.ps1      | Bulk creates AD users and reporting lines                | Run with PowerShell                     |
| sql_seed_employees.sql   | Sample HR database for identity aggregation              | MySQL Workbench/CLI                     |
| README.md                | Setup and documentation reference                        | GitHub repo, update as lab grows        |

---

## **Next Steps**

Now that your environment is seeded and scripts are tracked in GitHub:
- **Proceed to configuring SailPoint IIQ’s AD and JDBC connectors** (next lesson).
- Update this README after each future lesson to document your learning and setup.



**Tip:**  
Whenever you change a file, save, then run:
git add .
git commit -m "Describe what you changed"
git push

text
This keeps your repository up-to-date and your lab documentation perfect.