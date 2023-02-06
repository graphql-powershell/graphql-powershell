function buildQuerySyntax {
    param (
        [Hashtable]$query
    )

    $containsArguments = $query.arguments.count -gt 0
    $querySyntax = "query $($query['queryname'])"
    if ($containsArguments) {
        $querySyntax += " ( "
        foreach ($argument in $query.arguments.GetEnumerator()) {
            if ($argument.Value.required) {
                $required = "!"
            } else {
                $required = ""
            }
    
            $querySyntax += "`$$($argument.name): "
            if ($argument.Value.list) {
                $querySyntax += " [$($argument.Value.type)$required] "
            } else {
                $querySyntax += "$($argument.Value.type)$required "
            }
        }
        $querySyntax += " ) "
    }
    
    $querySyntax += " { objects: $($query['queryname']) "
    
    if ($containsArguments) {
        $querySyntax += " ( "
        foreach ($argument in $query.arguments.GetEnumerator()) {
            $querySyntax += " $($argument.name): `$$($argument.name) "
        }
        $querySyntax += " ) "
    }
    
    #Loop through fields
    $querySyntax += buildFieldSyntax -fields $query.fields 
    
    $querySyntax += " } "

    return $querySyntax
}