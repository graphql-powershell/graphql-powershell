function Connect-GraphQLAPI {
    [CmdletBinding()]
    param (
        # Name of the dynamic module created. This will also be the noun prefix given to generated cmdlets.
        [Parameter(Mandatory = $true)]
        [String]
        $Name,
        # URI of the GraphQL API. e.g. https://example.com/api/graphql
        [Parameter()]
        [string]
        $Uri,
        # Hashtable of HTTP headers required by the GraphQL API. 
        [Parameter(Mandatory = $true)]
        [hashtable]
        $Headers,
        # If introspection is disabled on the API, you will need to provide the API schema in JSON format.
        [Parameter()]
        [string]
        $SchemaPath,
        # Depth to traverse objects within query
        [Parameter()]
        [Int]
        $Depth=3
    )
    
    begin {
        # Store information in global variable
        Write-Verbose -Message "Storing provided parameters in global variable (GraphQLInterfaceConnection)"
        $global:GraphQLInterfaceConnection = @{
            Headers     = $headers;
            Uri         = $Uri;
            Name        = $Name;
            Depth       = $Depth
        }
        # Test headers and authentication by running types introspection
        $path = (Split-Path $script:MyInvocation.MyCommand.Path) + "\queries"
        Write-Verbose -Message "Attempting initial connection to $($global:GraphQLInterfaceConnection.Uri) with provided headers"
        try {
            
            $response = runQuery -Path "$path\types.gql"
            Write-Verbose -Message "Connection Succeeded"
        }
        catch {
            Write-Error -Message "Connection Issue, Clearing global variable (GraphQLInterfaceConnection)"
            $global:GraphQLInterfaceConnection = ""
            throw $_.Exception | Out-String
        }
    }
    
    process {

        # Create the dynamic module, passing in 
        $DynamicModule = New-Module -Name $Name -ScriptBlock {

            # Variable used to pass individual cmdlet-specific configurations (like querysyntax, parameters, etc) into newly created cmdlets
            $__CommandInfo = @{}

            # Function to run Query (renamed to DynQuery to distinguish between powershell-graphql-interface function and embedded function for newly generated module)
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

            # Recursive function designed to recursively populate the fields for the query
            function getFieldsFromKind {
                param ($kind, $queryReturnType, $currentDepth)
                if ($currentDepth -lt $global:GraphQLInterfaceConnection.Depth) {
                    $currentDepth += 1
                    # Open up output
                    $output = " { "

                    # Get info about the kind
                    $type = $typelist | where {$_.name -eq "$kind"}

                    # Check here to see if we have edges and nodes
                    if ($type.fields.name -contains "edges" -and $type.fields.name -contains "nodes") {
                        # If both edges and nodes exist, let's just pull down edges
                        $type.fields = $type.fields | where {$_.name -eq "edges"}
                    }
                    
                    foreach ($field in $type.fields) {
                        $show = $true
                        $fieldType = getFieldType $field
                        # Probably need to add more to list here, adding as I find them
                        $normalTypeList = ('Int','String','Boolean','ID','Float','Date','Long','DateTime','URL','UUID')
                        $isNormalVar = ($normalTypeList -contains $fieldType)
                        
                        # If the field type is not like an INT or String, then it's probably a custom object,
                        # so let's recursively call our function on it to get it's embedded fields.
                        if (-Not ($isNormalVar)) {
                            if ($currentDepth -lt $global:GraphQLInterfaceConnection.Depth) {
                                # Yes, we are still under the maximum depth allowed, however, if we are only 1 more away from max
                                # we need to check to see if this object has any "NORMAL" fields - we can output those if it does
                                # but if it doesn't, we have don't want to as we would need to go to depth + 1 to get fields
                                # so if it has normal vars, keep going and call the recursive function again, if not, we need not 
                                # include this field - which means we need to get rid of the opening and closing " {  } " 

                                $temp = $typelist | where-object {$_.name -eq "$fieldType"} 

                                # If we are only one depth away we need to ensure we peak ahead so we don't have blank objects
                                #problem is with this statement
                                if ($global:GraphQLInterfaceConnection.Depth - $currentDepth -eq 1) {
                                    $scalarFields = $temp.fields.type | where {$_.name -in $normalTypeList}
                                    if ($null -eq $scalarFields) {
                                        $show = $false
                                    }
                                    else {
                                        $show = $true
                                    }

                                }
                                if ($show -eq $true) {
                                    $output += " $($field.name) "
                                    # Need to check here if field is an enum but I can't remember why lol
                                    if ($temp.kind -ne 'ENUM') {
                                        $output += getFieldsFromKind $fieldType $kind $currentDepth
                                    } else {
                                        Continue
                                    }
                                }
                            }      
                        } else {
                            $output += " $($field.name) "
                        }
                    }
                    # Close up and return output
                    $output += " } "
                    return  $output
                } else {
                   
                }
            }

            function getFieldsFromKind {
                param ($kind, $queryReturnType, $currentDepth)
                if ($currentDepth -lt $global:GraphQLInterfaceConnection.Depth) {
                    $currentDepth += 1
                    # Open up output
                    $output = " { "

                    # Get info about the kind
                    #$type = $typelist | where {$_.name -eq "$kind"}
                    $type = $typelisthash[$kind]
                    # Check here to see if we have edges and nodes
                    if ($type.fields.name -contains "edges" -and $type.fields.name -contains "nodes") {
                        # If both edges and nodes exist, let's just pull down edges
                        $type.fields = $type.fields | where {$_.name -eq "edges"}
                    }


                    $normalTypeList = ('Int','String','Boolean','ID','Float','Date','Long','DateTime','URL','UUID')

                    foreach ($field in $type.fields) {
                        $show = $true
                        $fieldType = getFieldType $field
   
                        
                        $isNormalVar = ($normalTypeList -contains $fieldType)
                        
                        # If the field type is not like an INT or String, then it's probably a custom object,
                        # so let's recursively call our function on it to get it's embedded fields.
                        if (-Not ($isNormalVar)) {
                            if ($currentDepth -lt $global:GraphQLInterfaceConnection.Depth) {

                                #$temp = $typelist | where-object {$_.name -eq "$fieldType"} 
                                $temp = $typelisthash[$fieldType]
                                # If we are only one depth away we need to ensure we peak ahead so we don't have blank objects
                                #problem is with this statement
                                if ($global:GraphQLInterfaceConnection.Depth - $currentDepth -eq 1) {
                                    $scalarFields = $temp.fields.type | where {$_.name -in $normalTypeList}
                                    if ($null -eq $scalarFields) {
                                        $show = $false
                                    }
                                    else {
                                        $show = $true
                                    }

                                }
                                if ($show -eq $true) {
                                    $output += " $($field.name) "
                                    # Need to check here if field is an enum but I can't remember why lol
                                    if ($temp.kind -ne 'ENUM') {
                                        $output += getFieldsFromKind $fieldType $kind $currentDepth
                                    } else {
                                        Continue
                                    }
                                }
                            }      
                        } else {
                            $output += " $($field.name) "
                        }
                    }
                    # Close up and return output
                    $output += " } "
                    return  $output
                } else {
                   
                }
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

            # This reference command is used to store the scriptblock of what we want our dynamically-created
            # cmdlets to do
            $ReferenceCommand = {
                [CmdletBinding()]
                param(
                )

                DynamicParam {
                    if (($Parameters = $__CommandInfo[$MyInvocation.MyCommand.Name]['Parameters'])) {
                        $Parameters
                    }
                }

                process {

                    # Get the query syntax from our CommandInfo
                    $querysyntax = $__CommandInfo[$MyInvocation.MyCommand.Name]['QueryString']
                    # Here is where specific code for each cmdlet will go!
                    Write-Verbose -Message "I'm the '$($PSCmdlet.MyInvocation.MyCommand.Name)' command!"
                    Write-Verbose -Message "Query Syntax: $querysyntax"
                    if ($PSBoundParameters.ContainsKey('QueryParams')) {
                        $queryparams = $PSBoundParameters['QueryParams']
                        $response = runDynQuery -QueryString $querysyntax -QueryParams $queryparams
                    } else {
                        $response = runDynQuery -QueryString $querysyntax
                    }
                    if ($null -ne $response.edges.node) {
                        return $response.edges.node
                    } else {
                    }
                    return $response
                }
            }
            # This function is used to build the actual dynamically generated cmdlets
            function BuildCmdlet {
                [CmdletBinding()]
                param(
                    [string] $CommandName,
                    [scriptblock] $Definition,
                    [ValidateSet('global','script','local')]
                    [string] $Scope = 'global',
                    [string] $querystring
                )
        
                begin {
                    # Another DSL keyword; this time for creating parameters
                    function parameter {
                        param(
                            [type] $ParameterType = [object],
                            [Parameter(Mandatory)]
                            [string] $ParameterName,
                            [System.Collections.ObjectModel.Collection[System.Attribute]] $Attributes = (New-Object parameter)
                        )
        
                        process {
        
                            # $CommandName coming from parent scope:
                            $MyCommandInfo = $__CommandInfo[$CommandName]
        
                            if ($MyCommandInfo -eq $null -or -not $MyCommandInfo.ContainsKey('Parameters')) {
                                Write-Error "Unable to find command definition for '$CommandName'"
                                return
                            }
                            # Create a runtime defined parameter that the reference script block will use in the DynamicParam{} block
                            $MyCommandInfo['Parameters'][$ParameterName] = New-Object System.Management.Automation.RuntimeDefinedParameter (
                                $ParameterName,
                                $ParameterType,
                                $Attributes
                            )
                        }
                    }
                }
                process {
                    $__CommandInfo[$CommandName] = @{
                        Parameters = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
                        QueryString = "$querystring"
                    }
                    & $Definition
                    $null = New-Item -Path function: -Name ${Scope}:${CommandName} -Value $ReferenceCommand -Force
                    
                    Export-ModuleMember -Function $CommandName
                }
            }

            # Introspect the schema, get a list of queries and types
            $modulebase = (Get-Module powershell-graphql-interface).ModuleBase
            $queries = runDynQuery -Path "$modulebase\queries\query.gql"
            $queries = $queries.queryType.fields
            $queries = $queries | Sort-Object -Property name



            $typelist = runDynQuery -Path "$modulebase\queries\types.gql"
            $typelist = $typelist.types

            # Let's convert to hash and see
            $typelisthash = @{}
            foreach ($_ in $typelist) {
                $typelisthash.Add($_.name, $_)
            }

            $totalqueries = ($queries | Measure-Object).count
            $track = 0




            foreach ($query in $queries) {
                $track = $track + 1
                $percentcomplete = ($track/$totalqueries)*100
                Write-Progress -Activity "Generating cmdlets from queries" -Status "Processing $($query.name) ($track of $totalqueries)" -PercentComplete $percentcomplete
                $cmdletname = "Get-$($global:GraphQLInterfaceConnection.name)"
                $cmdletname += $query.name.subString(0,1).toUpper() + $query.name.subString(1)

                #Write-Host "Processing Query: " -NoNewline
                #Write-Host " $($query.name)" -ForegroundColor Green -NoNewline
                #Write-Host " ( $track of $totalqueries )" -ForegroundColor Yellow
                #Write-Host "Creating cmdlet: " -NoNewline
                #Write-Host " $cmdletname" -ForegroundColor Green
                
                # Open up QueryString to hold entire query syntax
                $querystring = "query $($query.name) "
                #Write-Host "Getting args " -nonewline
                $arguments = $query.args
                $argString = getQueryArgs $query
                $querySTring += $argSTring
                #Write-Host "Done" -foregroundcolor "yellow"

                # Get Query Return Type
                $returnType = getQueryReturnType $query
                
                $currentDepth = 0
                if ($null -ne $returnType) {
                    $fieldlist = getFieldsFromKind $returnType $returnType $currentDepth
                    $queryString += $fieldlist
                } else {
                    # Need to figure out to do without a return type
                }

                # Close up QueryString
                $querystring += " } "

                #Write-Host "Query Syntax is: " -NoNewline
                #Write-Host " $querystring" -ForegroundColor Yellow
                
                # Let's build some cmdlets :)

                BuildCmdlet -CommandName $cmdletname -QueryString $querystring -Definition {
                    parameter hashtable QueryParams -Attributes (
                        [parameter] @{Mandatory = $false; }
                    )
                }
                #Write-Host "====================================="
            }
        } | Import-Module
    }
    end {
        
    }
}