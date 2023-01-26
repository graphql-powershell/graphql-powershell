# Function used to get the return type of a given query
function getQueryReturnType {
    param ($query)
    
    # Need to modify to look in certain areas for return type, if none defined, check for top level fields, if still nothing, skip this cmdlet
    # Also, ensure whatever we find is in $typelist
    #Write-Host "Return Type is: " -NoNewline
    if ($query.type.name) {
        #Write-Host "$($query.type.name)" -ForegroundColor Red
        if (returnTypeExists $query.type.name) {
            return $query.type.name
        }
    }
    if ($query.type.ofType.name) {
        #rite-Host "$($query.type.ofType.name)" -ForegroundColor Red
        if (returnTypeExists $query.type.ofType.name) {
            return $query.type.ofType.name
        }
    }
    if ($query.type.ofType.ofType.name) {
        #Write-Host "$($query.type.ofType.ofType.name)" -ForegroundColor Red
        if (returnTypeExists $query.type.ofType.ofType.name) {
            return $query.type.ofType.ofType.name
        }
    }
    if ($query.type.ofType.ofType.ofType.name) {
        #Write-Host "$($query.type.ofType.ofType.ofType.name)" -ForegroundColor Red
        if (returnTypeExists $query.type.ofType.ofType.ofType.name) {
            return $query.type.ofType.ofTYpe.ofType.name
        }
    }
    #Write-Host "Not Found" -ForegroundColor Red
    return $null
}