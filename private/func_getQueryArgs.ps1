# function used to get all arguments/input from query
function getQueryArgs {
    param ($query)
    # initialize argument string
    $argString = ""

    $arguments = $query.args
    
    if ($arguments) {
        $argString += "("
        foreach ($argument in $arguments) {
            $list = "false"
            # Is it required
            
            if ($argument.type.kind -eq "NON_NULL") {
                $required = "!"
            } elseif ($argument.type.kind -eq "LIST" ) {
                if ($argument.type.ofType.kind -eq "NON_NULL") {
                    $required = "!"
                    $list = "true"
                }
            } else {
                $required=""
            }
            if ($null -eq $argument.type.name ) {
                # We need to find the argument type
                if ($null -ne $argument.type.ofType.name) {
                    if ($list -eq "true") {
                        $argString += '$' + $argument.name + ': ' + "[$($argument.type.ofType.name)$required] "
                    }else {
                        $argString += '$' + $argument.name + ': ' + "$($argument.type.ofType.name)$required "
                    }
                } else {
                    # Let's go deeper - this can probably be ported out to a function and recursion eventually
                    if ($null -ne $argument.type.ofType.ofType.name) {
                        if ($list -eq "true") {
                            $argSTring += '$' + $argument.name + ': ' + " [$($argument.type.ofType.ofType.name)$required] "
                        } else {
                            $argSTring += '$' + $argument.name + ': ' + " $($argument.type.ofType.ofType.name)$required "
                        }
                        
                    } else {
                        $argSTring += '$' + $argument.name + ': ' + " ISSUE FINDING ARG "
                    }
                }
            } else {
                $argString += '$' + $argument.name + ': ' + $argument.type.name + "$required "
            }
        }
        $argString += " ) "
        $argSTring += "{ objects: $($query.name) ("
        foreach ($argument in $arguments) {
            $argSTring += $argument.name + ': $' + $argument.name + " "
        }
        $argSTring += ") "
    } else {
        $argSTring += "{ objects: $($query.name) "
    }
    return $argString
}