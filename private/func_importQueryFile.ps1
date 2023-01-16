function importQueryFile {
    param (
        [String]$Name,
        [String]$Path
    )
    
    if ($Name) {
        $Path = (Split-Path $script:MyInvocation.MyCommand.Path) + "\queries\" + $Name + ".gql"
    }
    
    # Open a file to read a query, then return it as a string to be executed.
    if (Test-Path -Path $Path) {
        Get-Content -Path ($Path) -Raw
    }
    else {
        Write-Output "Valid Name (for built-in queries) or Path (to a graphql query file) required."
    }
}