
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

# Function to determine what the field type is
function getFieldType {
    param ($field)

    # Check obvious spot first
    if ($field.type.name) {
        return $field.type.name
    }
    if ($field.type.ofType.Name) {
        return $field.type.ofType.name
    }
    if ($field.type.ofType.ofType.Name) {
        return $field.type.ofType.ofType.name
    }
    if ($field.type.ofType.ofType.ofType.Name) {
        return $field.type.ofType.ofType.ofType.name
    }
    return ""
}

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

function runDynQuery {
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
        $queryString = importDynQueryFile -Path $Path
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

# Function used to get query syntax from a file
# renamed to seperate it from the function already included in the main module
function importDynQueryFile {
    param (
        [String]$Name,
        [String]$Path
    )
    
    if ($Name) {
        $Path = (Split-Path $script:MyInvocation.MyCommand.Path) + "\queries\" + $Name + ".gql"
    }
    
    # Open a file to read a query, then return it as a string to be executed.
    if (Test-Path -Path $Path) {
        Get-Content -Path ($Path) -Raw
    }
    else {
        Write-Output "Valid Name (for built-in queries) or Path (to a graphql query file) required."
    }
}

function getFieldHash {
    param (
        [string]$fieldType,
        [int]$currentDepth
    )

    $normalTypeList = ('Int','String','Boolean','ID','Float','Date','Long','DateTime','URL','UUID')
    $currentDepth += 1


    if ($currentDepth -le $global:GraphQLInterfaceConnection.Depth) {

        $type = $typelisthash[$fieldType]

        # if we contain edges and nodes then let's only move forward with edges (IE, purge nodes)
        if ($type.fields.name -contains "edges" -and $type.fields.name -contains "nodes") {
            $type.fields = $type.fields | Where-Object {$_.name -eq "edges"}
        }

    
        $fieldsHash = @{}

        foreach ($field in $type.fields) {
            $fieldType = getFieldType $field
            $showField = $true
            $innerFields = $null
            $hasMore = $false

            if (-Not ($normalTypeList -contains $fieldType)) {
                # This isn't a common data type, must be custom and must contains more fields
                # Lets recursively get them!
                $hasMore = $true
                $innerFields = getFieldHash -fieldType $fieldType -currentDepth $currentDepth
            }

            # Check on count before proceeding
            $normalvar = $normalTypeList -contains $fieldType
            if ($($innerfields.count) -eq 0 -and $normalvar -eq $false) {
                $showField = $false
            }
            # If we are on the last depth and innerfields is null, don't add it
            if ($currentDepth -eq $global:GraphQLInterfaceConnection.Depth -and ($innerFields -eq "" -or $null -eq $innerFields)) {
                $showField = $false
            }

            # If inner field has arguments, then let's just skip for now
            if ($field.args.count -gt 0 ) {
                $showField = $false
            }

            if ($showField -eq $true) {
                $fieldsHash.Add($($field.name), @{
                    fieldtype  = "$fieldType"
                    arguments  = $($field.args)
                    fields     = $innerFields
                    hasMore    = $hasMore
                })
            }
        }
        return $fieldsHash
    } else {
        return $null
    }
}

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
                $validateSet = $($($typelisthash[$argumentType].enumValues.Name)) -Join ", "
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

function buildFieldSyntax {
    param (
        [Hashtable]$fields
    )

    $returnString = " { "
    foreach ($field in $fields.GetEnumerator()) {
        $returnString += " $($field.name) "

        if ($field.Value.hasMore) {
            $returnString += buildFieldSyntax -Fields $field.Value.fields
        }
    }
    $returnString += " } "
    return $returnString

}

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
        $fields = getFieldHash -fieldType $queryReturnType -currentDepth 0
    
        $args = getArgumentHash -queryArguments $query.args
    
        $queryNameUpper = $($query.name).SubString(0,1).ToUpper()+$($query.name).substring(1)
        $cmdletName = "Get-$queryNameUpper"
        $allqueries.Add($cmdletName, @{
            queryname = $($query.name)
            fields = $fields
            returnType = $queryReturnType
            arguments = $args
        }
        )
    
        # Generate Syntax
        $querySyntax = buildQuerySyntax -Query $allqueries[$cmdletName]
        $allqueries[$cmdletName].Add("QuerySyntax", $querySyntax)
    
    }
    return $allqueries
}

$queries = runDynQuery -Path "$modulebase\queries\query.gql"
$queries = $queries.queryType.fields
$queries = $queries | Sort-Object -Property name

$queries = $queries | where {$_.name -eq 'sladomains'}
$typelist = runDynQuery -Path "$modulebase\queries\types.gql"
$typelist = $typelist.types

$typelisthash = @{}
foreach ($_ in $typelist) {
    $typelisthash.Add($_.name, $_)
}

$allqueries = buildCmdletList -queries $queries

return $allqueries



<#
Code to save



                # Loop through queryArguments to build out Comment Based Help
                $strcommentbasedhelp = ""
                foreach ($arg in $queryArguments.GetEnumerator()) {
                    if ($powershelldatatypes -contains  $($arg.value['Type'])) {
                        $strcommentbasedhelp += "-$($arg.name) <$($arg.Value['Type'])>`n"
                    } else {
                        if ($typelisthash[$($arg.Value['Type'])].kind -eq 'ENUM') { 
                            $possibleValues = $($($typelisthash[$($arg.value['Type'])].enumValues.Name)) -Join ", "
                            $strcommentbasedhelp += "-$($arg.name) <String> - Valid Values: $possiblevalues`n"
                            
                        } else {
                            $strcommentbasedhelp += "-$($arg.name) <hastable> representing $($arg.Value['Type']) - For more information run Get-$($global:GraphQLInterfaceConnection.name)TypeDefinition -Type $($arg.Value['Type'])`n"
                        }
                    }
                }
                $sbcommentbasedhelp = @"
                <#
                    .DESCRIPTION
                    $($query.DESCRIPTION)
                    
                    DYNAMIC PARAMETERS

                    $strcommentbasedhelp


                #>

"@

#>
