
param (
    [string]$Name

)

#$Name = 'SpaceTimes'
$DyanmicModule = New-Module -Name $Name -ScriptBlock {

    $ReferenceCommand = {
        [CmdletBinding()]
        param()

        process {
            Write-Host "I'm the '" -NoNewline
            Write-Host $PSCmdlet.MyInvocation.MyCommand.Name -NoNewline -ForegroundColor Green
            Write-Host "' command"
        }
    }

    function DynCommand {
        param(
            [string] $CommandName,
            [ValidateSet('global','script','local')]
            [string] $Scope = 'script'
        )

        $null = New-Item -Path function: -Name ${Scope}:${CommandName} -Value $ReferenceCommand -Force
        Export-ModuleMember -Function $CommandName
    }

    DynCommand MyNewCommand
    
} | Import-Module
