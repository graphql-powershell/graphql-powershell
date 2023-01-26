# function used to get all arguments/input from query
function getQueryArgs {
    param ($query)
    # initialize argument string
    $argString = ""

    # initialize empty hashtable to store args
    $queryArgs = @{}

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
            $argType = getArgumentType ($argument)

            if ($list -eq "true") {
                $argString += '$' + $argument.name + ': ' + "[ $($argtype)$required] "
            } else {
                $argString += '$' + $argument.name + ': ' + "$($argType)$required "
            }

            $indArg = @{
                Type = "$argType"
            }

            $queryArgs.Add("$($argument.name)",$indArg)
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
    return $argString,$queryArgs
}