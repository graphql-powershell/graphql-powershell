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

        # dot source internal functions to parent module
        $modulebase = (Get-Module powershell-graphql-interface).ModuleBase
        # Import module functions
        Get-ChildItem ($modulebase + "/private") | ForEach-Object {
            . $_.FullName
        }

        # Test headers and authentication by running types introspection

        $path = $modulebase + "\queries"
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


            # Dot source internal functions to in-memory module
            $modulebase = (Get-Module powershell-graphql-interface).ModuleBase
            # Import module functions
            Get-ChildItem ($modulebase + "/private") | ForEach-Object {
                . $_.FullName
            }

            # Variable used to pass individual cmdlet-specific configurations (like querysyntax, parameters, etc) into newly created cmdlets
            $__CommandInfo = @{} 
            
            # Variable to hold common powershell data types
            $powershelldatatypes = @('Boolean','String','Int','Character','Integer','float','double')

            # This reference command is used to store the scriptblock of what we want our dynamically-created
            # cmdlets to do
            $ReferenceCommand = {
                
                [CmdletBinding(DefaultParameterSetName='QueryParams')]
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
                    } else {
                        # Build QueryParams from Bound Params
                        if ($PSBoundParameters.Count -gt 0) {
                            $queryparams = @{}
                            foreach ($param in $PSBoundParameters.GetEnumerator()) {
                                $queryparams.Add("$($param.key)", $($param.value))
                            }
                        }
                    }
                    $response = runQuery -QueryString $querysyntax -QueryParams $queryparams
                    if ($null -ne $response.edges.node) {
                        return $response.edges.node
                    } else {
                    }
                    return $response
                }
            }





            # Introspect the schema, get a list of queries and types
            $queries = runQuery -Path "$modulebase\queries\query.gql"
            $queries = $queries.queryType.fields
            $queries = $queries | Sort-Object -Property name

            #$queries = $queries | where {$_.name -eq 'slaDomains'}
            
            $typelist = runQuery -Path "$modulebase\queries\types.gql"
            $typelist = $typelist.types


            # Convert TypeList to Hashtable
            $typelisthash = @{}
            foreach ($_ in $typelist) {
                $typelisthash.Add($_.name, $_)
            }

            # Get a hashtable of all cmdlets and associated information
            $allqueries = buildCmdletList -queries $queries


            foreach ($cmdlet in $allqueries.GetEnumerator()) {
                BuildCmdlet -CommandName $cmdlet.name -QueryString $cmdlet.Value.QuerySyntax  -Definition {

                    # QueryParams
                    parameter -ParameterType hashtable -ParameterName QueryParams -HelpMessage "Send Query Parameters Manually via hashtable" -Attributes (
                        [parameter] @{Mandatory = $false; ParameterSetName="QueryParams";}
                    )

                    # New Properties parameter to specify individual properties
                    $selectableProperties = $cmdlet.Value.SelectableFields
                    if ($selectableProperties) {
                        $strSelectable = [string[]]$selectableProperties
                        parameter -ParameterType "String[]" -ParameterName "Properties" -ValidateSet $strSelectable -Attributes (
                            [parameter] @{
                                Mandatory = $false;  
                                ParameterSetName="Properties"; 
                            }
                        )
                    }
                    # Loop through queryArguments and add parameters to cmdlet
                    if ($cmdlet.Value.arguments.count -gt 0) {
                        foreach ($arg in $cmdlet.Value.arguments.GetEnumerator() ) { 
                            # For now, let's filter out anything that isn't a PS variable type
                            if ($powershelldatatypes -contains  $($arg.value['Type'])) {
                                parameter -ParameterType $($arg.Value['Type']) -ParameterName $arg.Name -Attributes (
                                    [parameter] @{
                                        Mandatory = $false;  
                                        ParameterSetName="IndividualParams";
                                    }
                                )
                            }
                            elseif ($($arg.value['Type']) -eq "UUID") {
                                parameter -ParameterType "String" -ParameterName $arg.Name -Attributes (
                                    [parameter] @{
                                        Mandatory = $false;  
                                        ParameterSetName="IndividualParams";
                                    }
                                )
                            }
                            else {
                                # Let's see if its an enum, if so, we will instantiate a ValidateSet
                                if ($typelisthash[$($arg.Value['Type'])].kind -eq 'ENUM') {
                                    $possibleValues = $arg.Value['validateset']
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