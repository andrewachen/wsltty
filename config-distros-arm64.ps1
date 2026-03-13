# ABOUTME: Configure WSL shortcuts for wsltty ARM64 installation.
# ABOUTME: PowerShell replacement for config-distros.sh; no Cygwin tools required.

param(
    [string]$InstallDir  = "$env:LOCALAPPDATA\wsltty",
    [string]$ConfigDir   = "$env:APPDATA\wsltty",
    [switch]$Remove,
    [switch]$ContextMenu,
    [switch]$DefaultOnly
)

$target      = "$InstallDir\bin\mintty.exe"
$defaultIcon = "$InstallDir\wsl.ico"
$lxss        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
$smfolder    = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\WSLtty"
$windowsApps = "$env:LOCALAPPDATA\Microsoft\WindowsApps"

if (!(Test-Path $smfolder)) { New-Item -ItemType Directory -Path $smfolder | Out-Null }

$wsh = New-Object -ComObject WScript.Shell

function Make-Shortcut($path, $tgt, $args, $icon) {
    $lnk = $wsh.CreateShortcut($path)
    $lnk.TargetPath       = $tgt
    $lnk.Arguments        = $args
    $lnk.IconLocation     = $icon
    $lnk.WorkingDirectory = '%USERPROFILE%'
    $lnk.Save()
    Write-Host "Created $([System.IO.Path]::GetFileName($path))"
}

function Make-Launcher($batPath, $distro, $home) {
    # Use env var references so the .bat works from any install location
    $cdir    = if ($home) { ' -~' } else { '' }
    $distArg = if ($distro) { $distro } else { '' }
    $content = @"
@echo off
chcp 65001 > nul:
if "%1" == "" goto login
:cmd
"%LOCALAPPDATA%\wsltty\bin\mintty.exe" -i "%LOCALAPPDATA%\wsltty\wsl.ico" --WSL="$distArg" --configdir="%APPDATA%\wsltty"$cdir %*
goto end
:login
"%LOCALAPPDATA%\wsltty\bin\mintty.exe" -i "%LOCALAPPDATA%\wsltty\wsl.ico" --WSL="$distArg" --configdir="%APPDATA%\wsltty"$cdir -
:end
"@
    [System.IO.File]::WriteAllText($batPath, $content, [System.Text.Encoding]::ASCII)
    Write-Host "Created $([System.IO.Path]::GetFileName($batPath))"
}

function Find-DistroIcon($guid) {
    try {
        $props = Get-ItemProperty "$lxss\$guid" -ErrorAction Stop
        if ($props.PackageFamilyName) {
            $dir = "$env:ProgramW6432\WindowsApps"
            $match = Get-ChildItem $dir -Filter "$($props.PackageFamilyName)*" -Directory -ErrorAction SilentlyContinue |
                     Select-Object -First 1
            if ($match) {
                # Prefer distro .exe, fall back to images/icon.ico
                $exe = Get-ChildItem $match.FullName -Filter "*.exe" -ErrorAction SilentlyContinue |
                       Where-Object { $_.Name -notmatch 'wsl' } | Select-Object -First 1
                if ($exe)  { return $exe.FullName }
                $ico = Join-Path $match.FullName "images\icon.ico"
                if (Test-Path $ico) { return $ico }
            }
        }
    } catch {}
    return $defaultIcon
}

# Build distro list: [{Name, Distro, Icon}]
$distros = @()

if (!$DefaultOnly -and (Test-Path $lxss)) {
    foreach ($key in Get-ChildItem $lxss -ErrorAction SilentlyContinue) {
        $props = $key | Get-ItemProperty -ErrorAction SilentlyContinue
        $dname = $props.DistributionName
        if (!$dname -or $dname -eq 'Legacy')  { continue }
        if ($dname -match '^docker')           { continue }
        $distros += @{ Name = $dname; Distro = $dname; Icon = (Find-DistroIcon $key.PSChildName) }
    }
}

# Always include a default-distro entry ("WSL" shortcut, empty --WSL=)
$distros += @{ Name = 'WSL'; Distro = ''; Icon = $defaultIcon }

foreach ($d in $distros) {
    $name   = $d.Name
    $distro = $d.Distro
    $icon   = $d.Icon
    $args0  = "--WSL=`"$distro`" --configdir=`"%APPDATA%\wsltty`""

    if ($ContextMenu) {
        $base    = 'HKCU:\Software\Classes\Directory'
        $keyName = "${name}_Terminal"
        $cmdStr  = "`"$target`" -i `"$icon`" --dir `"%1`" $args0 -"

        if ($Remove) {
            Remove-Item "$base\shell\$keyName"            -Recurse -ErrorAction SilentlyContinue
            Remove-Item "$base\Background\shell\$keyName" -Recurse -ErrorAction SilentlyContinue
        } else {
            foreach ($sub in @("$base\shell", "$base\Background\shell")) {
                $kPath = "$sub\$keyName"
                New-Item "$kPath\command" -Force | Out-Null
                Set-ItemProperty $kPath         -Name '(default)' -Value "$name Terminal"
                Set-ItemProperty $kPath         -Name 'Icon'      -Value $icon
                Set-ItemProperty "$kPath\command" -Name '(default)' -Value $cmdStr
            }
            Write-Host "Registered context menu: $name Terminal"
        }
        continue
    }

    Write-Host "Configuring distro '$name'"

    if ($Remove) {
        Remove-Item "$smfolder\$name Terminal %.lnk"                                           -ErrorAction SilentlyContinue
        Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$name Terminal.lnk"   -ErrorAction SilentlyContinue
        Remove-Item "$windowsApps\$name.bat"  -ErrorAction SilentlyContinue
        Remove-Item "$windowsApps\${name}~.bat" -ErrorAction SilentlyContinue
        continue
    }

    # "Ubuntu Terminal %.lnk" in WSLtty Start Menu folder (start in current dir)
    Make-Shortcut "$smfolder\$name Terminal %.lnk" `
        $target "$args0 -" $icon

    # "Ubuntu Terminal.lnk" in main Start Menu (start in WSL home)
    Make-Shortcut "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$name Terminal.lnk" `
        $target "$args0 -~" $icon

    # Desktop shortcut for the default "WSL" entry
    if ($name -eq 'WSL') {
        $desktop = [Environment]::GetFolderPath('Desktop')
        Make-Shortcut "$desktop\WSL Terminal.lnk" $target "$args0 -~" $icon
    }

    # .bat launchers (normal and ~ variants)
    Make-Launcher "$InstallDir\$name.bat"    $distro $false
    Make-Launcher "$InstallDir\${name}~.bat" $distro $true

    # Copy .bat launchers to WindowsApps so they appear on PATH
    Copy-Item "$InstallDir\$name.bat"    "$windowsApps\" -Force -ErrorAction SilentlyContinue
    Copy-Item "$InstallDir\${name}~.bat" "$windowsApps\" -Force -ErrorAction SilentlyContinue
}
