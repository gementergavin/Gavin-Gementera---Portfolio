@{
    RootModule        = 'AdminTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '143163f0-34f0-40de-a3d3-add1d129bfe7'
    Author            = 'Gavin Gementera'
    Description       = 'Help desk and sysadmin tools for the Pacific Crest USD (fictional) Active Directory lab: bulk user creation, password resets, expiring-password and inactive-account reports, and a PC health report.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'ConvertTo-PcusdUsername', 'New-PcusdTempPassword', 'Test-PcusdUserRow', 'Get-PcusdRoleSettings',
        'Get-PasswordExpiryStatus', 'Get-DiskStatus',
        'New-BulkADUser', 'Get-PasswordExpiryReport', 'Get-InactiveUserReport', 'Disable-InactiveUser',
        'Reset-HelpDeskPassword', 'Get-SystemHealthReport'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
