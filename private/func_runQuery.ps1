function runQuery {
    param (
        [String]$Path,
        [Hashtable]$QueryParams,
        [String]$QueryString
    )
    # Retrieve info from Global Variable
    $Uri = $global:GraphQLInterfaceConnection.Uri
    $Headers = $global:GraphQLInterfaceConnection.Headers

    # If we aren't passing a querystring, then use Path
    if ($null -eq $querystring -or $querystring -eq '') { 
        $queryString = importQueryFile -Path $Path
    }
    
    $query = @{query = $queryString; variables = $QueryParams} | ConvertTo-Json -Depth 50

    try {
        $response = Invoke-RestMethod -Method POST -Uri $Uri -Body $query -Headers $Headers
    }
    catch {
        throw $_ | Out-String
    }

    $response.data.objects
}
