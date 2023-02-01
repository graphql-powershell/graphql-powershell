function Connect-GraphQLAPI {
    [CmdletBinding()]
    param (
        # Name of the dynamic module created. This will also be the noun prefix given to generated cmdlets.
        [Parameter(Mandatory = $true )]
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
        $commandPath = (Split-Path $script:MyInvocation.MyCommand.Path)
        $path = (Split-Path $script:MyInvocation.MyCommand.Path) + "\queries"
        Write-Verbose -Message "Attempting initial connection to $($global:GraphQLInterfaceConnection.Uri) with provided headers"
        try {
            
            $response = runQuery -Path "$path\types.gql"
            Write-Verbose -Message "Connection Succeeded"
        }
        catch {
            Write-Error -Message "Connection Issue, Clearing global variable (GraphQLInterfaceConnection)"
            $global:GraphQLInterfaceConnection = ""
            throw $_ | Out-String
        }
    }
    
    process {

        # Create the dynamic module, passing in 
        $DynamicModule = New-Module -Name $Name -ScriptBlock {

            $modulebase = (Get-Module powershell-graphql-interface).ModuleBase

            # Import module functions
            Get-ChildItem ($modulebase + "/private") | ForEach-Object {
                . $_.FullName
            }

            # Variable used to pass individual cmdlet-specific configurations (like querysyntax, parameters, etc) into newly created cmdlets
            $__CommandInfo = @{}            

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
                    $queryArguments = $__CommandInfo[$MyInvocation.MyCommand.Name]['Arguments']
                    # Here is where specific code for each cmdlet will go!
                    Write-Verbose -Message "I'm the '$($PSCmdlet.MyInvocation.MyCommand.Name)' command!"
                    Write-Verbose -Message "Query Syntax: $querysyntax"
                    if ($PSBoundParameters.ContainsKey('QueryParams')) {
                        $queryparams = $PSBoundParameters['QueryParams']
                    } else {
                        # Build QueryParams from Bound Params
                        if ($PSBoundParameters.Count -gt 0) {
                            $queryparams = @{}
                            foreach ($param in $PSBoundParameters.GetEnumerator()) {
                                $queryparams.Add("$($param.key)", $($param.value))
                            }
                        }
                        
                    }
                    $response = runDynQuery -QueryString $querysyntax -QueryParams $queryparams
                    if ($null -ne $response.edges.node) {
                        return $response.edges.node
                    } else {
                    }
                    return $response
                }
            }

            # Introspect the schema, get a list of queries and types
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

            $powershelldatatypes = @('Boolean','String','Int','Character','Integer','float','double')
            
            foreach ($query in $queries) {
                $track = $track + 1
                $percentcomplete = ($track/$totalqueries)*100
                Write-Progress -Activity "Generating cmdlets from queries" -Status "Processing $($query.name) ($track of $totalqueries)" -PercentComplete $percentcomplete
                $cmdletname = "Get-$($global:GraphQLInterfaceConnection.name)"
                $cmdletname += $query.name.subString(0,1).toUpper() + $query.name.subString(1)
                
                # Open up QueryString to hold entire query syntax
                $querystring = "query $($query.name) "

                # Include arguments
                $argString, $queryArguments = getQueryArgs $query
                $queryString += $argString
                
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
                # Let's build some cmdlets :)
                BuildCmdlet -CommandName $cmdletname -QueryString $querystring -queryArguments $queryArguments -commentbasedhelp $sbcommentbasedhelp  -Definition {
                    parameter -ParameterType hashtable -ParameterName QueryParams -HelpMessage "Send Query Parameters Manually via hashtable" -Attributes (
                        [parameter] @{Mandatory = $true; ParameterSetName="QueryParams";}
                    )
                    # Loop through queryArguments and add parameters to cmdlet
                    foreach ($arg in $queryArguments.GetEnumerator() ) { 
                        
                        # For now, let's filter out anything that isn't a PS variable type
                        if ($powershelldatatypes -contains  $($arg.value['Type'])) {
                            parameter -ParameterType $($arg.Value['Type']) -ParameterName $arg.Name -Attributes (
                                [parameter] @{
                                    Mandatory = $false;  
                                    ParameterSetName="IndividualParams";
                                }
                            )
                        }
                        else {
                            # Let's see if its an enum, if so, we will instantiate a ValidateSet
                            if ($typelisthash[$($arg.Value['Type'])].kind -eq 'ENUM') {
                                $possibleValues = $($($typelisthash[$($arg.value['Type'])].enumValues.Name))
                                parameter -ParameterType String -ParameterName $arg.Name -ValidateSet $possibleValues -Attributes (
                                    [parameter] @{
                                        Mandatory = $false;  
                                        ParameterSetName="IndividualParams"; 
                                    }
                                )
                            } else {
                                # We are dealing with a custom type, let's just add the parameter as a hashtable
                                parameter -ParameterType hashtable -ParameterName $($arg.name) -HelpMessage "Provide hashtable representing a $($arg.Value['Type'])" -Attributes (
                                    [parameter] @{
                                        Mandatory = $false;
                                        ParameterSetName = "IndividualParams";

                                    }
                                )

                               
                            }
                        }

                    }
                }
            }

            # Build out generic cmdlet to retrieve a list of all the types
            # This will help users when looking at how to define certain parameters
            $cmd = "Get-$($global:GraphQLInterfaceConnection.name)TypeDefinition"
            $GetTypeCommand = {
                
                [CmdletBinding()]
                param(
                )

                DynamicParam {
                    if (($Parameters = $__CommandInfo[$MyInvocation.MyCommand.Name]['Parameters'])) {
                        $Parameters
                    }
                }

                process {
                    if ($PSBoundParameters.ContainsKey('Type')) {
                        $Type = $PSBoundParameters['Type']
                        return $typelisthash[$Type]
                    } else {
                        return $typelisthash
                    }
                    
                }
            }
          
            BuildCmdlet -CommandName $cmd -ReferenceOverride $GetTypeCommand -Definition {

                parameter -ParameterType String -ParameterName Type -HelpMessage "Type definition to look up" -Attributes (
                        [parameter] @{Mandatory = $false; }
                )


            }
        } | Import-Module
    }
    end {
        
    }
}