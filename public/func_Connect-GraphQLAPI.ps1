function Connect-GraphQLAPI {
    [CmdletBinding()]
    param (
        # Name of the dynamic module created. This will also be the noun prefix given to generated cmdlets.
        [Parameter(Mandatory = $true)]
        [String]
        $Name,
        # URI of the GraphQL API. e.g. https://example.com/api/graphql
        [Parameter]
        [string]
        $Uri,
        # Hashtable of HTTP headers required by the GraphQL API. 
        [Parameter]
        [hashtable]
        $Headers,
        # If introspection is disabled on the API, you will need to provide the API schema in JSON format.
        [Parameter]
        [string]
        $SchemaPath
    )
    
    begin {
        
    }
    
    process {
        
    }
    
    end {
        
    }
}