function buildCmdletList {
    param (
        [object[]] $queries
    )

    $allqueries = @{}

    $totalqueries = ($queries | Measure-Object).count
    $track = 0
    
    foreach ($query in $queries ) {
        $track = $track + 1
        $percentcomplete = ($track/$totalqueries)*100
        Write-Progress -Activity "Generating cmdlets from queries" -Status "Processing $($query.name) ($track of $totalqueries)" -PercentComplete $percentcomplete
        $queryReturnType = getQueryReturnType -query $query
        $fields = getFieldHash -fieldType $queryReturnType -currentDepth 0 -parentnode "root"

        $args = getArgumentHash -queryArguments $query.args
    
        $queryNameUpper = $($query.name).SubString(0,1).ToUpper()+$($query.name).substring(1)
        $cmdletname = "Get-$($global:GraphQLInterfaceConnection.name)" + $queryNameUpper
        $allqueries.Add($cmdletName, @{
            queryname = $($query.name)
            fields = $fields
            returnType = $queryReturnType
            arguments = $args
            allFields = $longFields
        }
        )
    
        # Generate Syntax
        $querySyntax = buildQuerySyntax -Query $allqueries[$cmdletName]
        $allqueries[$cmdletName].Add("QuerySyntax", $querySyntax)

        #Get All fields which have a long name
        $fields = $allqueries[$cmdletName].fields
        $longNameFields = getLongNameFields -fields $fields 
        $allqueries[$cmdletName].Add("SelectableFields", $longNameFields)
    
    }
    return $allqueries
}