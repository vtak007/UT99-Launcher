# ============================================
# Intel I226-V NIC Profile Tuner - Rev 4
# Profiles: Gaming, Balanced, Everyday
# Fixed adapter name: "Ethernet"
# ============================================

# ---------- Adapter Name ----------
# This must be the *Name* from Get-NetAdapter, not the InterfaceDescription.
# On your system it is: "Ethernet"
$AdapterName = "Ethernet"

# ---------- Jumbo Packet Configuration ----------
# Open Device Manager -> Your NIC -> Advanced -> Jumbo Packet.
# Find the SMALLEST numeric value (normal MTU) and put its text here.
# Examples: "1514 Bytes", "1500 Bytes", "1514".



# ---------- Helper: Set Advanced Properties ----------
function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($currentIdentity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedScript {
    param([string]$ScriptPath)

    $hostExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    $argumentList = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $ScriptPath)
    )

    Start-Process -FilePath $hostExe -ArgumentList $argumentList -Verb RunAs | Out-Null
}

function Set-NicAdvancedProfile {
    param(
        [string]$AdapterName,
        [hashtable]$ProfileTable
    )

    Write-Host "`nApplying advanced properties to '$AdapterName'..." -ForegroundColor Green

    foreach ($key in $ProfileTable.Keys) {
        $value = $ProfileTable[$key]

        Write-Host ("  -> {0} = {1}" -f $key, $value) -ForegroundColor Yellow

        try {
            Set-NetAdapterAdvancedProperty `
                -Name $AdapterName `
                -DisplayName $key `
                -DisplayValue $value `
                -NoRestart `
                -ErrorAction Stop
        }
        catch {
            Write-Warning "    Failed to set '$key' to '$value'. $($_.Exception.Message)"
        }
    }
}

# ---------- Helper: Power Management Profiles ----------
function Set-NicPowerProfileGaming {
    param([string]$AdapterName)

    Write-Host "Adjusting power management for GAMING (disable offloads/sleep/WoL)..." -ForegroundColor Green

    try {
        Disable-NetAdapterPowerManagement -Name $AdapterName -ArpOffload -NsOffload -SelectiveSuspend -WakeOnMagicPacket -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to adjust power management settings for gaming."
    }
}

function Set-NicPowerProfileBalanced {
    param([string]$AdapterName)

    Write-Host "Adjusting power management for BALANCED (reduced power features, WoL off)..." -ForegroundColor Green

    try {
        # Balanced: allow ARP/NS offload, but keep Selective Suspend/WoL off for latency
        Enable-NetAdapterPowerManagement  -Name $AdapterName -ArpOffload -NsOffload -ErrorAction SilentlyContinue
        Disable-NetAdapterPowerManagement -Name $AdapterName -SelectiveSuspend -WakeOnMagicPacket -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to adjust power management settings for balanced profile."
    }
}

function Set-NicPowerProfileEveryday {
    param([string]$AdapterName)

    Write-Host "Adjusting power management for EVERYDAY (power saving + WoL)..." -ForegroundColor Green

    try {
        Enable-NetAdapterPowerManagement -Name $AdapterName -ArpOffload -NsOffload -SelectiveSuspend -WakeOnMagicPacket -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to adjust power management settings for everyday use."
    }
}


# ---------- Helper: Network Offload Profiles ----------
function Set-NetworkProfileGaming {
    param([string]$AdapterName)

    Write-Host "Applying GAMING network offload profile (LSO disabled, RSC disabled, RSS enabled)..." -ForegroundColor Green

    try {
        Disable-NetAdapterLso -Name $AdapterName -IPv4 -IPv6 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to disable LSO for gaming profile."
    }

    try {
        Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Disabled -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to disable RSC for gaming profile."
    }

    try {
        Enable-NetAdapterRss -Name $AdapterName -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to ensure RSS is enabled for gaming profile."
    }
}

function Set-NetworkProfileBalanced {
    param([string]$AdapterName)

    Write-Host "Applying BALANCED network offload profile (LSO disabled, RSC enabled, RSS enabled)..." -ForegroundColor Green

    try {
        Disable-NetAdapterLso -Name $AdapterName -IPv4 -IPv6 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to disable LSO for balanced profile."
    }

    try {
        Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Enabled -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to enable RSC for balanced profile."
    }

    try {
        Enable-NetAdapterRss -Name $AdapterName -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to ensure RSS is enabled for balanced profile."
    }
}

function Set-NetworkProfileEveryday {
    param([string]$AdapterName)

    Write-Host "Restoring EVERYDAY network offload profile (LSO enabled, RSC enabled, RSS enabled)..." -ForegroundColor Green

    try {
        Enable-NetAdapterLso -Name $AdapterName -IPv4 -IPv6 -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to enable LSO for everyday profile."
    }

    try {
        Set-NetOffloadGlobalSetting -ReceiveSegmentCoalescing Enabled -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to enable RSC for everyday profile."
    }

    try {
        Enable-NetAdapterRss -Name $AdapterName -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "  Failed to ensure RSS is enabled for everyday profile."
    }
}

function Get-NicProfileMatchScore {
    param(
        [hashtable]$CurrentProperties,
        [hashtable]$ProfileTable
    )

    $matchedSettings = 0
    $comparedSettings = 0

    foreach ($key in $ProfileTable.Keys) {
        if (-not $CurrentProperties.ContainsKey($key)) {
            continue
        }

        $comparedSettings++

        if ($CurrentProperties[$key] -eq $ProfileTable[$key]) {
            $matchedSettings++
        }
    }

    return [pscustomobject]@{
        MatchedSettings  = $matchedSettings
        ComparedSettings = $comparedSettings
    }
}

function Get-ActiveNicProfileStatus {
    param([string]$AdapterName)

    $currentProperties = @{}

    try {
        $advancedProperties = Get-NetAdapterAdvancedProperty -Name $AdapterName -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{
            Name    = "Unknown"
            Message = "Unknown (could not read current adapter advanced properties)"
        }
    }

    foreach ($property in $advancedProperties) {
        if (-not [string]::IsNullOrWhiteSpace($property.DisplayName)) {
            $currentProperties[$property.DisplayName] = $property.DisplayValue
        }
    }

    $profiles = @(
        @{ Name = "Gaming";   Table = Get-GamingProfile   -AdapterName $AdapterName },
        @{ Name = "Balanced"; Table = Get-BalancedProfile -AdapterName $AdapterName },
        @{ Name = "Everyday"; Table = Get-EverydayProfile -AdapterName $AdapterName }
    )

    $bestProfile = $null
    $bestScore = $null

    foreach ($profile in $profiles) {
        $score = Get-NicProfileMatchScore -CurrentProperties $currentProperties -ProfileTable $profile.Table

        if (
            ($null -eq $bestScore) -or
            ($score.MatchedSettings -gt $bestScore.MatchedSettings) -or
            (
                ($score.MatchedSettings -eq $bestScore.MatchedSettings) -and
                ($score.ComparedSettings -gt $bestScore.ComparedSettings)
            )
        ) {
            $bestProfile = $profile
            $bestScore = $score
        }
    }

    if (($null -eq $bestProfile) -or ($bestScore.ComparedSettings -eq 0)) {
        return [pscustomobject]@{
            Name    = "Unknown"
            Message = "Unknown (no comparable adapter settings were found)"
        }
    }

    return [pscustomobject]@{
        Name    = $bestProfile.Name
        Message = $bestProfile.Name
    }
}

function Write-ActiveNicProfileStatus {
    param([string]$AdapterName)

    $profileStatus = Get-ActiveNicProfileStatus -AdapterName $AdapterName
    Write-Host "Active profile: $($profileStatus.Message)" -ForegroundColor Yellow

    return $profileStatus
}

function Write-ProfileMenu {
    param([string]$ActiveProfileName)

    Write-Host "`nChoose a profile:"
    Write-Host ("{0} [1] Gaming   - Lowest latency, more CPU, less power saving" -f $(if ($ActiveProfileName -eq "Gaming") { "*" } else { " " }))
    Write-Host ("{0} [2] Balanced - Hybrid profile (recommended everyday gaming + desktop)" -f $(if ($ActiveProfileName -eq "Balanced") { "*" } else { " " }))
    Write-Host ("{0} [3] Everyday - Power efficient, best for general use & downloads" -f $(if ($ActiveProfileName -eq "Everyday") { "*" } else { " " }))
    Write-Host "  [Q] Quit"
}

# ---------- Profile Definitions ----------
# NOTE: DisplayName/DisplayValue strings MUST match Device Manager exactly.

function Get-GamingProfile {
    param([string]$AdapterName)

    return @{
        "ARP Offload"                       = "Disabled"
        "DMA Coalescing"                    = "Disabled"
        "Enable PME"                        = "Enabled"
        "Energy Efficient Ethernet"         = "Off"
        "Flow Control"                      = "Disabled"
        "Interrupt Moderation"              = "Disabled"
        "Interrupt Moderation Rate"         = "Off"
        "IPv4 Checksum Offload"             = "Rx & Tx Enabled"        
        "Jumbo Packet"                      = "1514"
        "Large Send Offload V2 (IPv4)"      = "Disabled"
        "Large Send Offload V2 (IPv6)"      = "Disabled"
        "Log Link State Event"              = "Enabled"
        "NS Offload"                        = "Disabled"
        "Packet Priority & VLAN"            = "Packet Priority & VLAN Disabled"
        "Receive Buffers"                   = "1024"        
        "Selective Suspend"                 = "Disabled"
        "Selective Suspend Idle Timeout"    = "1"
        "Speed & Duplex"                    = "Auto Negotiation"
        "TCP Checksum Offload (IPv4)"       = "Rx & Tx Enabled"
        "TCP Checksum Offload (IPv6)"       = "Rx & Tx Enabled"
		"Transmit Buffers"                  = "1024"
		"UDP Checksum Offload (IPv4)"       = "Rx & Tx Enabled"
        "UDP Checksum Offload (IPv6)"       = "Rx & Tx Enabled"
        "Wait for Link"                     = "Off"
        "Wake from S0ix on Magic Packet"    = "Disabled"
        "Wake on Link Settings"             = "Disabled"
        "Wake on Magic Packet"              = "Disabled"
        "Wake on Pattern Match"             = "Disabled"
    }
}

function Get-BalancedProfile {
    param([string]$AdapterName)

    return @{
        "ARP Offload"                       = "Disabled"
        "DMA Coalescing"                    = "Disabled"
        "Enable PME"                        = "Enabled"
        "Energy Efficient Ethernet"         = "Off"
        "Flow Control"                      = "Rx & Tx Enabled"
        "Interrupt Moderation"              = "Enabled"
        "Interrupt Moderation Rate"         = "Low"
        "IPv4 Checksum Offload"             = "Rx & Tx Enabled"        
        "Jumbo Packet"                      = "1514"
        "Large Send Offload V2 (IPv4)"      = "Disabled"
        "Large Send Offload V2 (IPv6)"      = "Disabled"
        "Log Link State Event"              = "Enabled"
        "NS Offload"                        = "Disabled"
        "Packet Priority & VLAN"            = "Packet Priority & VLAN Disabled"
        "Receive Buffers"                   = "1024"        
        "Selective Suspend"                 = "Disabled"
        "Selective Suspend Idle Timeout"    = "1"
        "Speed & Duplex"                    = "Auto Negotiation"   
        "TCP Checksum Offload (IPv4)"       = "Rx & Tx Enabled"
        "TCP Checksum Offload (IPv6)"       = "Rx & Tx Enabled"
		"Transmit Buffers"                  = "1024"
        "UDP Checksum Offload (IPv4)"       = "Rx & Tx Enabled"
        "UDP Checksum Offload (IPv6)"       = "Rx & Tx Enabled"		
        "Wait for Link"                     = "Off"
        "Wake from S0ix on Magic Packet"    = "Disabled"
        "Wake on Link Settings"             = "Disabled"
        "Wake on Magic Packet"              = "Disabled"
        "Wake on Pattern Match"             = "Disabled"
    }
}

function Get-EverydayProfile {
    param([string]$AdapterName)

    return @{
        "ARP Offload"                       = "Enabled"
        "DMA Coalescing"                    = "Disabled"
        "Enable PME"                        = "Enabled"
        "Energy Efficient Ethernet"         = "Off"
        "Flow Control"                      = "Rx & Tx Enabled"
        "Interrupt Moderation"              = "Enabled"
        "Interrupt Moderation Rate"         = "Medium"
        "IPv4 Checksum Offload"             = "Rx & Tx Enabled"        
        "Jumbo Packet"                      = "1514"
        "Large Send Offload V2 (IPv4)"      = "Enabled"
        "Large Send Offload V2 (IPv6)"      = "Enabled"
        "Log Link State Event"              = "Enabled"
        "NS Offload"                        = "Enabled"
        "Packet Priority & VLAN"            = "Packet Priority & VLAN Enabled"
        "Receive Buffers"                   = "2048"        
        "Selective Suspend"                 = "Enabled"
        "Selective Suspend Idle Timeout"    = "1"
        "Speed & Duplex"                    = "Auto Negotiation"
        "TCP Checksum Offload (IPv4)"       = "Rx & Tx Enabled"
        "TCP Checksum Offload (IPv6)"       = "Rx & Tx Enabled"
		"Transmit Buffers"                  = "2048"
		"UDP Checksum Offload (IPv4)"       = "Rx & Tx Enabled"
        "UDP Checksum Offload (IPv6)"       = "Rx & Tx Enabled"
        "Wait for Link"                     = "Auto Detect"
        "Wake from S0ix on Magic Packet"    = "Disabled"
        "Wake on Link Settings"             = "Forced"
        "Wake on Magic Packet"              = "Enabled"
        "Wake on Pattern Match"             = "Enabled"
    }
}

# ---------- Main ----------

if (-not (Test-IsAdministrator)) {
    Write-Warning 'This script must be run as Administrator.'

    if ($PSCommandPath) {
        try {
            Write-Host 'Attempting to relaunch with elevation...' -ForegroundColor Yellow
            Start-ElevatedScript -ScriptPath $PSCommandPath
        }
        catch {
            Write-Warning "Unable to relaunch elevated automatically. $($_.Exception.Message)"
            Write-Host "Please re-run 'Set-I226VProfile.ps1' from an elevated PowerShell session." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host 'Please re-run this script from an elevated PowerShell session.' -ForegroundColor Yellow
    }

    Read-Host "`nPress ENTER to exit..."
    return
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Intel I226-V NIC Profile Tuner - Rev 4" -ForegroundColor Cyan
Write-Host " Profiles: Gaming / Balanced / Everyday" -ForegroundColor Cyan
Write-Host " Fixed adapter name: '$AdapterName'" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

$adapter = Get-NetAdapter -Name $AdapterName -ErrorAction SilentlyContinue
if (-not $adapter) {
    Write-Error "Adapter '$AdapterName' not found. Run 'Get-NetAdapter' to confirm the correct Name."
    Read-Host "`nPress ENTER to exit..."
    return
}

Write-Host "Selected adapter: $($adapter.Name)  (Desc: $($adapter.InterfaceDescription))" -ForegroundColor Cyan
$activeProfileStatus = Write-ActiveNicProfileStatus -AdapterName $AdapterName

Write-ProfileMenu -ActiveProfileName $activeProfileStatus.Name

$choice = Read-Host "`nEnter your choice"

switch ($choice.ToUpper()) {
    "1" {
        $profileTable = Get-GamingProfile -AdapterName $AdapterName
        Set-NicAdvancedProfile -AdapterName $AdapterName -ProfileTable $profileTable
        Set-NicPowerProfileGaming -AdapterName $AdapterName
        Set-NetworkProfileGaming -AdapterName $AdapterName
    }
    "2" {
        $profileTable = Get-BalancedProfile -AdapterName $AdapterName
        Set-NicAdvancedProfile -AdapterName $AdapterName -ProfileTable $profileTable
        Set-NicPowerProfileBalanced -AdapterName $AdapterName
        Set-NetworkProfileBalanced -AdapterName $AdapterName
    }
    "3" {
        $profileTable = Get-EverydayProfile -AdapterName $AdapterName
        Set-NicAdvancedProfile -AdapterName $AdapterName -ProfileTable $profileTable
        Set-NicPowerProfileEveryday -AdapterName $AdapterName
        Set-NetworkProfileEveryday -AdapterName $AdapterName
    }
    "Q" {
        Write-Host "Aborted by user." -ForegroundColor Yellow
        Read-Host "`nPress ENTER to exit..."
        return
    }
    Default {
        Write-Error "Invalid choice. Exiting."
        Read-Host "`nPress ENTER to exit..."
        return
    }
}

Write-Host "`nRestarting adapter '$AdapterName' to apply changes..." -ForegroundColor Cyan
Disable-NetAdapter -Name $AdapterName -Confirm:$false
Start-Sleep -Seconds 3
Enable-NetAdapter -Name $AdapterName -Confirm:$false
$activeProfileStatus = Write-ActiveNicProfileStatus -AdapterName $AdapterName

Write-Host "Done. Active profile: $($activeProfileStatus.Message)." -ForegroundColor Green

# Keep console open so you can read messages
Read-Host "`nPress ENTER to exit..."
