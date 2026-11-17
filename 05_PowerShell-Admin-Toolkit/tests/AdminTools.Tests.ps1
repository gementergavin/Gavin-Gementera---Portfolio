#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
<#
    Pester 5 tests for the AdminTools module.

    Run from the 05_PowerShell-Admin-Toolkit folder:
        Invoke-Pester -Path .\tests -Output Detailed

    The Active Directory commands are mocked, so these tests run on any
    Windows PC, with or without the ActiveDirectory module.
#>

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\AdminTools\AdminTools.psd1') -Force
}

AfterAll {
    Remove-Module AdminTools -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-PcusdUsername' {
    It 'builds first.last in lowercase' {
        ConvertTo-PcusdUsername -FirstName 'Maria' -LastName 'Lopez' | Should -Be 'maria.lopez'
    }

    It 'removes accents, apostrophes and hyphens' {
        # Jos(e-acute) Nu(n-tilde)ez, written with character codes so the file encoding can't break the test
        $jose  = "Jos$([char]0x00E9)"
        $nunez = "N$([char]0x00FA)$([char]0x00F1)ez"
        ConvertTo-PcusdUsername -FirstName $jose -LastName $nunez | Should -Be 'jose.nunez'
        ConvertTo-PcusdUsername -FirstName 'Liam' -LastName "O'Brien" | Should -Be 'liam.obrien'
        ConvertTo-PcusdUsername -FirstName 'Ethan' -LastName 'Smith-Jones' | Should -Be 'ethan.smithjones'
    }

    It 'adds a number when the name is taken' {
        ConvertTo-PcusdUsername Maria Lopez -ExistingNames 'maria.lopez' | Should -Be 'maria.lopez2'
        ConvertTo-PcusdUsername Maria Lopez -ExistingNames 'maria.lopez', 'Maria.Lopez2' | Should -Be 'maria.lopez3'
    }

    It 'keeps usernames to 20 characters' {
        $name = ConvertTo-PcusdUsername -FirstName 'Alexandria' -LastName 'Montgomery-Smithfield'
        $name | Should -Be 'alexandria.montgomer'
        $name.Length | Should -BeLessOrEqual 20
    }

    It 'stays within 20 characters when it adds a number' {
        ConvertTo-PcusdUsername -FirstName 'Alexandria' -LastName 'Montgomery-Smithfield' `
            -ExistingNames 'alexandria.montgomer' | Should -Be 'alexandria.montgome2'
    }

    It 'never ends with the dot' {
        ConvertTo-PcusdUsername -FirstName 'Bartholomewjohnsonx' -LastName 'Lee' | Should -Be 'bartholomewjohnsonx'
    }

    It 'throws when a name has no letters' {
        { ConvertTo-PcusdUsername -FirstName '123' -LastName 'Lee' } | Should -Throw
    }
}

Describe 'New-PcusdTempPassword' {
    It 'is the requested length' {
        (New-PcusdTempPassword -Length 16).Length | Should -Be 16
    }

    It 'always has an uppercase letter, lowercase letter, digit and symbol' {
        foreach ($i in 1..25) {
            $pw = New-PcusdTempPassword
            $pw | Should -MatchExactly '[A-Z]'
            $pw | Should -MatchExactly '[a-z]'
            $pw | Should -Match '[0-9]'
            $pw | Should -Match '[!@#$%*?+=-]'
        }
    }

    It 'leaves out characters that are easy to misread' {
        foreach ($i in 1..25) {
            New-PcusdTempPassword | Should -Not -MatchExactly '[0O1lI]'
        }
    }

    It 'is different each time' {
        New-PcusdTempPassword | Should -Not -Be (New-PcusdTempPassword)
    }

    It 'refuses lengths under 12' {
        { New-PcusdTempPassword -Length 8 } | Should -Throw
    }
}

Describe 'Test-PcusdUserRow' {
    It 'accepts a complete row' {
        $row = [pscustomobject]@{ FirstName = 'Maria'; LastName = 'Lopez'; Role = 'Teacher'; IdNumber = '100231' }
        @(Test-PcusdUserRow -Row $row).Count | Should -Be 0
    }

    It 'reports a missing first name' {
        $row = [pscustomobject]@{ FirstName = ''; LastName = 'Morris'; Role = 'Office' }
        @(Test-PcusdUserRow -Row $row) | Should -Contain 'FirstName is missing'
    }

    It 'reports a missing column' {
        $row = [pscustomobject]@{ FirstName = 'Owen'; LastName = 'Price' }
        @(Test-PcusdUserRow -Row $row) | Should -Contain 'Role is missing'
    }

    It 'reports an unknown role' {
        $row = [pscustomobject]@{ FirstName = 'Carlos'; LastName = 'Diaz'; Role = 'Coach' }
        (@(Test-PcusdUserRow -Row $row) -join ' ') | Should -Match "Role 'Coach'"
    }

    It 'reports an ID number that is not digits' {
        $row = [pscustomobject]@{ FirstName = 'Grace'; LastName = 'Wu'; Role = 'Student'; IdNumber = 'ABC123' }
        (@(Test-PcusdUserRow -Row $row) -join ' ') | Should -Match 'IdNumber'
    }

    It 'finds the 3 bad rows in the sample error file' {
        $rows = Import-Csv -Path (Join-Path $PSScriptRoot '..\data\new-users-with-errors.csv') -Encoding UTF8
        $bad = @($rows | Where-Object { @(Test-PcusdUserRow -Row $_).Count -gt 0 })
        $bad.Count | Should -Be 3
    }

    It 'finds no bad rows in the main user file' {
        $rows = Import-Csv -Path (Join-Path $PSScriptRoot '..\data\new-users.csv') -Encoding UTF8
        $bad = @($rows | Where-Object { @(Test-PcusdUserRow -Row $_).Count -gt 0 })
        $bad.Count | Should -Be 0
    }
}

Describe 'Get-PcusdRoleSettings' {
    It 'puts <Role> accounts in <OU> and <Group>' -TestCases @(
        @{ Role = 'Teacher'; OU = 'OU=Teachers,OU=Staff,OU=PCUSD'; Group = 'GG-Teachers' }
        @{ Role = 'Office';  OU = 'OU=Office,OU=Staff,OU=PCUSD';   Group = 'GG-Office' }
        @{ Role = 'IT';      OU = 'OU=IT,OU=Staff,OU=PCUSD';       Group = 'GG-IT' }
        @{ Role = 'Student'; OU = 'OU=Students,OU=PCUSD';          Group = 'GG-Students' }
    ) {
        $settings = Get-PcusdRoleSettings -Role $Role
        $settings.OU    | Should -Be $OU
        $settings.Group | Should -Be $Group
    }

    It 'throws for an unknown role' {
        { Get-PcusdRoleSettings -Role 'Coach' } | Should -Throw
    }
}

Describe 'Get-PasswordExpiryStatus' {
    BeforeAll {
        $now = Get-Date -Year 2026 -Month 11 -Day 17 -Hour 9 -Minute 0 -Second 0
    }

    It 'returns nothing when the password never expires' {
        Get-PasswordExpiryStatus -ExpiryFileTime ([Int64]::MaxValue) -Now $now | Should -BeNullOrEmpty
    }

    It 'flags a password that must be changed at sign-in' {
        (Get-PasswordExpiryStatus -ExpiryFileTime 0 -Now $now).Status | Should -Be 'Must change at sign-in'
    }

    It 'counts the days left' {
        $result = Get-PasswordExpiryStatus -ExpiryFileTime $now.AddDays(10).AddHours(1).ToFileTime() -Now $now
        $result.DaysLeft | Should -Be 10
        $result.Status   | Should -Be 'Expiring'
    }

    It 'flags an expired password' {
        $result = Get-PasswordExpiryStatus -ExpiryFileTime $now.AddDays(-3).ToFileTime() -Now $now
        $result.Status   | Should -Be 'Expired'
        $result.DaysLeft | Should -BeLessThan 0
    }
}

Describe 'Get-DiskStatus' {
    It 'is OK with plenty of space' {
        (Get-DiskStatus -SizeBytes 100GB -FreeBytes 40GB).Status | Should -Be 'OK'
    }
    It 'is Low under 15% free' {
        (Get-DiskStatus -SizeBytes 100GB -FreeBytes 10GB).Status | Should -Be 'Low'
    }
    It 'is Critical under 5% free' {
        (Get-DiskStatus -SizeBytes 100GB -FreeBytes 3GB).Status | Should -Be 'Critical'
    }
    It 'rounds percent free to one decimal' {
        (Get-DiskStatus -SizeBytes 3GB -FreeBytes 1GB).PercentFree | Should -Be 33.3
    }
    It 'refuses a zero-size disk' {
        { Get-DiskStatus -SizeBytes 0 -FreeBytes 0 } | Should -Throw
    }
}

Describe 'New-BulkADUser (Active Directory mocked)' {
    BeforeAll {
        # Stand-ins for the AD commands on PCs without the ActiveDirectory module.
        # Pester needs a command to exist (with its parameters) before it can mock it.
        $script:stubs = @()
        if (-not (Get-Command Get-ADDomain -ErrorAction SilentlyContinue)) {
            function global:Get-ADDomain { [CmdletBinding()] param() }
            $script:stubs += 'Get-ADDomain'
        }
        if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
            function global:Get-ADUser {
                [CmdletBinding()]
                param([string] $Filter, [string] $SearchBase, [string] $SearchScope, [object] $Identity, [string[]] $Properties)
            }
            $script:stubs += 'Get-ADUser'
        }
        if (-not (Get-Command New-ADUser -ErrorAction SilentlyContinue)) {
            function global:New-ADUser {
                [CmdletBinding()]
                param([string] $Name, [string] $GivenName, [string] $Surname, [string] $DisplayName,
                      [string] $SamAccountName, [string] $UserPrincipalName, [string] $Path, [string] $Department,
                      [securestring] $AccountPassword, [bool] $ChangePasswordAtLogon, [bool] $Enabled,
                      [string] $Title, [string] $Office, [string] $EmployeeID)
            }
            $script:stubs += 'New-ADUser'
        }
        if (-not (Get-Command Add-ADGroupMember -ErrorAction SilentlyContinue)) {
            function global:Add-ADGroupMember { [CmdletBinding()] param([object] $Identity, [object[]] $Members) }
            $script:stubs += 'Add-ADGroupMember'
        }

        Mock -ModuleName AdminTools Assert-ADModule { }
        Mock -ModuleName AdminTools Get-ADDomain {
            [pscustomobject]@{ DistinguishedName = 'DC=pcusd,DC=internal'; DNSRoot = 'pcusd.internal' }
        }
        Mock -ModuleName AdminTools Get-ADUser { }        # no existing users or name clashes
        Mock -ModuleName AdminTools New-ADUser { }
        Mock -ModuleName AdminTools Add-ADGroupMember { }

        $csv        = Join-Path $PSScriptRoot '..\data\new-users-with-errors.csv'
        $resultFile = Join-Path $TestDrive 'results.csv'
    }

    AfterAll {
        foreach ($name in $script:stubs) { Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue }
    }

    It 'creates nothing with -WhatIf' {
        $results = New-BulkADUser -CsvPath $csv -ResultPath $resultFile -WhatIf
        Should -Invoke -ModuleName AdminTools New-ADUser -Times 0 -Exactly
        @($results | Where-Object Status -eq 'WhatIf').Count  | Should -Be 2
        @($results | Where-Object Status -eq 'Skipped').Count | Should -Be 3
    }

    It 'creates the valid rows in the right OU and group and skips the bad ones' {
        $results = New-BulkADUser -CsvPath $csv -ResultPath $resultFile -WarningAction SilentlyContinue

        Should -Invoke -ModuleName AdminTools New-ADUser -Times 2 -Exactly
        Should -Invoke -ModuleName AdminTools New-ADUser -Times 1 -Exactly -ParameterFilter {
            $SamAccountName -eq 'hannah.lee' -and
            $Path -eq 'OU=Teachers,OU=Staff,OU=PCUSD,DC=pcusd,DC=internal' -and
            $ChangePasswordAtLogon -eq $true
        }
        Should -Invoke -ModuleName AdminTools Add-ADGroupMember -Times 1 -Exactly -ParameterFilter {
            "$Identity" -eq 'GG-Students' -and "$Members" -match 'owen\.price'
        }
        @($results | Where-Object Status -eq 'Created').Count | Should -Be 2
        @($results | Where-Object Status -eq 'Skipped').Count | Should -Be 3
    }

    It 'saves temporary passwords to the result file but not to the screen output' {
        $results = @(New-BulkADUser -CsvPath $csv -ResultPath $resultFile -WarningAction SilentlyContinue)
        $results[0].PSObject.Properties.Name | Should -Not -Contain 'TempPassword'

        $saved = @(Import-Csv -Path $resultFile)
        $saved.Count | Should -Be 2
        $saved[0].TempPassword.Length | Should -Be 14
    }
}
