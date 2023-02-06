function getArgumentHash {
    param(
        [Object[]] $queryArguments
    )
    # Set base variables
    $argHash = @{}

    
    if ($queryArguments) {
        foreach ($arg in $queryArguments) {
            $required = $false
            $list = $false
            $validateSet = ""
            # If argument is required
            if ($arg.type.kind -eq "NON_NULL") {
                $required = $true
            }
            if ($arg.type.kind -eq "LIST") {
                $list = $true
                if ($arg.type.ofType.kind -eq "NON_NULL") {
                    $required = $true
                }
            }

            $argumentType = getArgumentType($arg)

            if ($typelisthash[$argumentType].kind -eq 'ENUM') { 
                $validateSet = $($($typelisthash[$argumentType].enumValues.Name)) 
            }

            # If argument type is an ENUM, get the validateset info
            $argument = @{
                type = $argumentType
                list = $list
                required = $required
                validateset = $validateSet
            }

            $argHash.Add($($arg.name),$argument)
        }
        return $argHash
    } else {
        return $null
    }
}