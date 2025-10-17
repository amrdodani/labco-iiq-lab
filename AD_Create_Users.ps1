<# AD_Create_Users.ps1 #>
Set-StrictMode -Version Latest
Import-Module ActiveDirectory

$csvPath = 'C:\IIQ8.5 Lab_setup\AD_Seed_Users.csv'
$pwd     = ConvertTo-SecureString 'Lab123$' -AsPlainText -Force

# Optional: create/use a target OU
$domainDN = (Get-ADDomain).DistinguishedName
$ouName   = 'Lab Users'
$ouPath   = "OU=$ouName,$domainDN"
if (-not (Get-ADOrganizationalUnit -LDAPFilter "(ou=$ouName)" -SearchBase $domainDN -ErrorAction SilentlyContinue)) {
  New-ADOrganizationalUnit -Name $ouName -Path $domainDN -ProtectedFromAccidentalDeletion:$false | Out-Null
}

# Read CSV and sanity-check headers
$rows = Import-Csv $csvPath
$expected = 'FirstName','LastName','Username','Department','Title','Email','Manager'
$missing  = $expected | Where-Object { $_ -notin $rows[0].PsObject.Properties.Name }
if ($missing) { throw "CSV missing columns: $($missing -join ', ')" }

Write-Host "=== PASS 1: Creating users (no Manager) ==="
foreach ($r in $rows) {
  $sam = $r.Username.Trim()
  if ([string]::IsNullOrWhiteSpace($sam)) { Write-Warning "Row missing Username; skipping."; continue }

  $exists = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
  if ($exists) { Write-Host "Exists: $sam"; continue }

  $params = @{
    Name                  = "$($r.FirstName.Trim()) $($r.LastName.Trim())"
    SamAccountName        = $sam
    GivenName             = $r.FirstName.Trim()
    Surname               = $r.LastName.Trim()
    Department            = $r.Department
    Title                 = $r.Title
    EmailAddress          = $r.Email
    Path                  = $ouPath
    AccountPassword       = $pwd
    Enabled               = $true
    ChangePasswordAtLogon = $true
    ErrorAction           = 'Stop'
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

  # DN?
  if ($val -match '^(CN|OU|DC)=') {
    try { return Get-ADUser -LDAPFilter "(distinguishedName=$val)" -ErrorAction Stop } catch { return $null }
  }

  # Try SAM, UPN, or Display Name
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
