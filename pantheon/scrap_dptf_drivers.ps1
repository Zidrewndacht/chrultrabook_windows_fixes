# Define the hardware IDs that threw critical device errors
$TargetIDs = @(
    "ACPI\INT3400",
    "ACPI\INT3403",
    "ACPI\INT3404",
    "PCI\VEN_8086&DEV_1903&SUBSYS_19038086&REV_08"
)

foreach ($Id in $TargetIDs) {
    # Split path to find base location in Enum registry branch
    $RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$Id"
    
    if (Test-Path $RegistryPath) {
        # Get all subkeys (individual device instances)
        $Instances = Get-ChildItem -Path $RegistryPath | Select-Object -ExpandProperty PSChildName
        
        foreach ($Instance in $Instances) {
            $FullControlPath = "$RegistryPath\$Instance"
            Write-Host "Force-disabling: $Id\$Instance" -ForegroundColor Cyan
            
            # Apply the system disabled bitmask flag
            New-ItemProperty -Path $FullControlPath -Name "ConfigFlags" -PropertyType DWord -Value 1 -Force | Out-Null
        }
    } else {
        Write-Host "Hardware ID path not found, skipping: $Id" -ForegroundColor Yellow
    }
}
