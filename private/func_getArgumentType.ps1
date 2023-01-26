function getArgumentType {
    param ($argument)

    if ($argument.type.name) {
        return $argument.type.name
    }

    if ($argument.type.ofType.name) {
        return $argument.type.ofType.name
    }
    
    if ($argument.type.ofType.ofType.name) {
        return $argument.type.ofType.ofType.name
    }

    return "ISSUEFINDINGARGTYPE"

}