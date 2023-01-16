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
        [Parameter()]
        [hashtable]
        $Headers,
        # If introspection is disabled on the API, you will need to provide the API schema in JSON format.
        [Parameter()]
        [string]
        $SchemaPath
    )
    
    begin {
        # Store information in global variable
        Write-Verbose -Message "Storing provided parameters in global variable (GraphQLInterfaceConnection)"
        $global:GraphQLInterfaceConnection = @{
            Headers     = $headers;
            Uri         = $Uri;
            Name        = $Name;
        }
        # Test headers and authentication by running types introspection
        Write-Verbose -Message "Attempting initial connection to $($global:GraphQLInterfaceConnection.Uri) with provided headers"
        try {
            $response = runQuery -Path "queries/types.gql" 
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
                    throw $_.Exception | Out-String
                }
            
                $response.data.objects
            }
            
            # Function used to determine what type of object the query returns
            # This will possibly need to be modified and/or new logic created to support other GQL Endpoints than SpaceX

            function getQueryReturnType {
                param ($query)

                # Let's see what the query wants to return
                $returnType = $query.type.kind
                if ($returnType -eq 'OBJECT') {
                    # If it is an object, usually that custom objects' name is in name
                    if ($null -ne $query.type.name) {
                        return $query.type.name
                    } else {
                        # More hunting
                        return ""
                    }
                    
                }
                elseif ($returnType -eq 'LIST') {
                    # if it is a list, it's normally defined in the typeOf.name
                    if ($null -ne $query.type.ofType.name) {
                        return $query.type.ofType.name   
                    } else {
                        # More Hunting
                        return ""
                    }
                }
                else {
                    # Need to figure out more here
                    return ""
                }
            }

            # Function to determine what the field type is
            function getFieldType {
                param ($field)

                # Check obvious spot first
                $type = $field.type.name
                if ($null -ne $type) {
                    return $type
                } else {
                    # Looks like type is null, let's go further...
                    $type = $field.type.ofType.name
                    if ($null -ne $type) {
                        return $type
                    }
                    else {
                        # No idea what to do here
                        return $null
                    }
                }
            }

            # Recursive function designed to recursively populate the fields for the query
            function getFieldsFromKind {
                param ($kind)

                # Open up output
                $output = " { "

                # Get info about the kind
                $type = $typelist | where {$_.name -eq "$kind"}

                # Loop through fields
                foreach ($field in $type.fields) {
                    $output += " $($field.name) "

                    $fieldType = getFieldType $field
                    
                    # Probably need to add more to list here
                    $isNormalVar = (('Int','String','Boolean','ID','Float','Date') -contains $fieldType)
                    
                    # If the field type is not like an INT or String, then it's probably a custom object,
                    # so let's recursively call our function on it to get it's embedded fields.
                    if (-Not ($isNormalVar)) {
                        # Check to see if definition is in name
                        $output += getFieldsFromKind $fieldType
                    }
                }

                # Close up and return output
                $output += " } "
                return  $output
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

                    # Only here for testing
                    <#
                    Write-Host "I'm the '" -NoNewline
                    Write-Host $PSCmdlet.MyInvocation.MyCommand.Name -NoNewline -ForegroundColor Green
                    Write-Host "' command!"
                    Write-Host "I will run the following GQL Query"
                    Write-Host "$querysyntax"
                    Write-Host "I have the following parameters:"
                    $PSBoundParameters
                    #>
                    
                    
                    if ($PSBoundParameters.ContainsKey('QueryParams')) {
                        $queryparams = $PSBoundParameters['QueryParams']
                        $response = runDynQuery -QueryString $querysyntax -QueryParams $queryparams
                    } else {
                        $response = runDynQuery -QueryString $querysyntax
                    }
                    return $response
                }
            }

            function getQueryArgs {
                param ($query)
                $argString = ""
                

                $arguments = $query.args
                
                if ($arguments) {
                    $argString += "("
                    foreach ($argument in $arguments) {
                      # Is it required
                      if ($argument.type.kind -eq "NON_NULL") {
                        $required = "!"
                      } else {
                        $required = ""
                      }
                      if ($null -eq $argument.type.name ) {
                        # We need to find the argument type
                        if ($null -ne $argument.type.ofType.name) {

                          $argString += '$' + $argument.name + ': ' + "$($argument.type.ofType.name)$required "
                        } else {

                          # Let's go deeper - this can probably be ported out to a function and recursion eventually
                          if ($null -ne $argument.type.ofType.ofType.name) {
                            $argSTring += '$' + $argument.name + ': ' + " $($argument.type.ofType.ofType.name)$required "
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
            $queries = runDynQuery -Path "queries/query.gql"
            $queries = $queries.queryType.fields
            $typelist = runDynQuery -Path "queries/types.gql"
            $typelist = $typelist.types



            foreach ($query in $queries) {

                $cmdletname = "Get-$($global:GraphQLInterfaceConnection.name)"
                $cmdletname += $query.name.subString(0,1).toUpper() + $query.name.subString(1)

                Write-Host "Processing Query: " -NoNewline
                Write-Host " $($query.name)" -ForegroundColor Green
                Write-Host "Creating cmdlet: " -NoNewline
                Write-Host " $cmdletname" -ForegroundColor Green

                # Open up QueryString to hold entire query syntax
                $querystring = "query myQuery "

                #region process arguments
                $arguments = $query.args

                $argString = getQueryArgs $query
                $querySTring += $argSTring

                #
                <#
                if ($null -eq $arguments -or "" -eq $arguments ) {
                    $querystring += "{ objects: $($query.name) "
                } else {
                    $querystring += "("
                    foreach ($argument in $arguments) {
                      # Is it required
                      if ($argument.type.kind -eq "NON_NULL") {
                        $required = "!"
                      } else {
                        $required = ""
                      }
                      if ($null -eq $argument.type.name ) {
                        # We need to find the argument type
                        if ($null -ne $argument.type.ofType.name) {

                          $querystring += '$' + $argument.name + ': ' + "$($argument.type.ofType.name)$required "
                        } else {

                          # Let's go deeper - this can probably be ported out to a function and recursion eventually
                          if ($null -ne $argument.type.ofType.ofType.name) {
                            $querystring += '$' + $argument.name + ': ' + " $($argument.type.ofType.ofType.name)$required "
                          } else {
                            $querystring += '$' + $argument.name + ': ' + " ISSUE FINDING ARG "
                          }
                          
                        }
                       
                      } else {
                        $querystring += '$' + $argument.name + ': ' + $argument.type.name + "$required "
                      }
                
                    }
                    $querystring += " ) "
                    $querystring += "{ objects: $($query.name) ("
                    foreach ($argument in $arguments) {
                      $querystring += $argument.name + ': $' + $argument.name + " "
                    }
                    $querystring += ") " 
                }
                #>

                <#
                if ($null -ne $arguments) {
                    $querystring += "("
                    foreach ($argument in $arguments) {
                      # Is it required
                      if ($argument.type.kind -eq "NON_NULL") {
                        $required = "!"
                      } else {
                        $required = ""
                      }
                      if ($null -eq $argument.type.name ) {
                        # We need to find the argument type
                        if ($null -ne $argument.type.ofType.name) {

                          $querystring += '$' + $argument.name + ': ' + "$($argument.type.ofType.name)$required "
                        } else {

                          # Let's go deeper - this can probably be ported out to a function and recursion eventually
                          if ($null -ne $argument.type.ofType.ofType.name) {
                            $querystring += '$' + $argument.name + ': ' + " $($argument.type.ofType.ofType.name)$required "
                          } else {
                            $querystring += '$' + $argument.name + ': ' + " ISSUE FINDING ARG "
                          }
                          
                        }
                       
                      } else {
                        $querystring += '$' + $argument.name + ': ' + $argument.type.name + "$required "
                      }
                
                    }
                    $querystring += " ) "
                    $querystring += "{ objects: $($query.name) ("
                    foreach ($argument in $arguments) {
                      $querystring += $argument.name + ': $' + $argument.name + " "
                    }
                    $querystring += ") "
                } else {
                    $querystring += "{ objects: $($query.name) "
                }

                #>

                

                

                #endregion


                #region Process Fields
                $queryfields = $query.type.fields

                # Get Query Return Type
                $returnType = getQueryReturnType $query

                if ($null -ne $returnType) {
                    $fieldlist = getFieldsFromKind $returnType
                    $queryString += $fieldlist
                }
            

                #endregion

                # Close up QueryString
                $querystring += " } "

                Write-Host "Query Syntax is: " -NoNewline
                Write-Host " $querystring" -ForegroundColor Yellow
                

                # Let's build some cmdlets :)

                #BuildCmdlet -CommandName $cmdletname -Definition {} -QueryString $querystring
                BuildCmdlet -CommandName $cmdletname -QueryString $querystring -Definition {
                    parameter hashtable QueryParams -Attributes (
                        [parameter] @{Mandatory = $false; }
                    )
                }
                Write-Host "====================================="
            }
        } | Import-Module
        
    }
    
    end {
        
    }
}