# Freeze current IPv4 settings (IP/Prefix/GW/DNS) to STATIC on every UP adapter with a non-APIPA IPv4.
# Windows PowerShell 5.1 compatible.

$targets = @()

foreach ($cfg in Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
    if (-not $cfg.IPv4Address) { continue }

    # First non-APIPA IPv4 on this adapter
    $addrObj = $cfg.IPv4Address |
        Where-Object { $_.IPAddress -match '^\d{1,3}(\.\d{1,3}){3}$' -and $_.IPAddress -notmatch '^169\.254\.' } |
        Select-Object -First 1
    if (-not $addrObj) { continue }

    # Adapter must be Up
    $na = Get-NetAdapter -InterfaceIndex $cfg.InterfaceIndex -ErrorAction SilentlyContinue
    if ($na -and $na.Status -ne 'Up') { continue }

    # Gateway (from config or route table)
    $gw = $null
    if ($cfg.IPv4DefaultGateway) { $gw = $cfg.IPv4DefaultGateway.NextHop }
    if (-not $gw) {
        $route = Get-NetRoute -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                 Sort-Object RouteMetric | Select-Object -First 1
        if ($route) { $gw = $route.NextHop }
    }

    # DNS servers
    $dns = (Get-DnsClientServerAddress -InterfaceIndex $cfg.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses

    $targets += [pscustomobject]@{
        InterfaceIndex = $cfg.InterfaceIndex
        InterfaceAlias = $cfg.InterfaceAlias
        IPAddress      = $addrObj.IPAddress
        PrefixLength   = $addrObj.PrefixLength
        Gateway        = $gw
        DnsServers     = $dns
    }
}

if (-not $targets -or $targets.Count -eq 0) {
    Write-Warning "No UP adapters with a non-APIPA IPv4 were found. Nothing to change."
    return
}

foreach ($t in $targets) {
    $gwStr  = if ($t.Gateway) { $t.Gateway } else { '(none)' }
    Write-Host ("Converting '{0}' -> {1}/{2} (GW: {3})" -f $t.InterfaceAlias, $t.IPAddress, $t.PrefixLength, $gwStr) -ForegroundColor Cyan

    try {
        # Disable DHCP (safe even if already static)
        Set-NetIPInterface -InterfaceIndex $t.InterfaceIndex -Dhcp Disabled -ErrorAction SilentlyContinue

        # Try in-place set
        $setParams = @{
            InterfaceIndex = $t.InterfaceIndex
            IPAddress      = $t.IPAddress
            PrefixLength   = $t.PrefixLength
            ErrorAction    = 'Stop'
        }
        if ($t.Gateway) { $setParams['DefaultGateway'] = $t.Gateway }

        $didSet = $true
        try { Set-NetIPAddress @setParams | Out-Null } catch { $didSet = $false }

        if (-not $didSet) {
            # Remove existing IPv4s, then add fresh
            Get-NetIPAddress -InterfaceIndex $t.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

            $newParams = @{
                InterfaceIndex = $t.InterfaceIndex
                IPAddress      = $t.IPAddress
                PrefixLength   = $t.PrefixLength
                ErrorAction    = 'Stop'
            }
            if ($t.Gateway) { $newParams['DefaultGateway'] = $t.Gateway }
            New-NetIPAddress @newParams | Out-Null
        }

        # DNS (apply if present, else clear)
        if ($t.DnsServers -and $t.DnsServers.Count) {
            Set-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -ServerAddresses $t.DnsServers -ErrorAction SilentlyContinue
        } else {
            Set-DnsClientServerAddress -InterfaceIndex $t.InterfaceIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        }

        Write-Host ("  Success: '{0}' is now STATIC." -f $t.InterfaceAlias) -ForegroundColor Green
    }
    catch {
        Write-Host ("  FAILED on '{0}': {1}" -f $t.InterfaceAlias, $_.Exception.Message) -ForegroundColor Red
    }
}
