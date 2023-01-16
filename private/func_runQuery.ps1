function runQuery {
    param (
        [String]$Path,
        [Hashtable]$QueryParams,
        [String]$queryString
    )
    $Uri = $global:GraphQLInterfaceConnection.Uri
    $Headers = $global:GraphQLInterfaceConnection.Headers

    if ($null -ne $Path) {

        $queryString = importQueryFile -Path $Path
    }
    

    $query = @{query = $queryString; variables = $QueryParams} | ConvertTo-Json -Depth 50

    
    try {
        $response = Invoke-RestMethod -Method POST -Uri $Uri -Body $query -Headers $Headers
    }
    catch {
        throw $_.Exception | Out-String
    }

    $response
    
}