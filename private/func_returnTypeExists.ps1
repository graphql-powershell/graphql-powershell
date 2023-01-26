# Function used to determine what type of object the query returns
# This will possibly need to be modified and/or new logic created to support other GQL Endpoints than SpaceX
function returnTypeExists {
    param ($returnType)
    
    $occurances = ($typelist | Where-Object {$_.name -eq $returnType} | Measure-Object).Count
    if ($occurances -gt 0) {    
        return $true
    } else {
        return $false
    }
}