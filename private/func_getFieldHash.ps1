function getFieldHash {
    param (
        [string]$fieldType,
        [int]$currentDepth,
        [string]$parentnode
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
                $newparentnode = "$parentnode.$($field.name)"
                $innerFields = getFieldHash -fieldType $fieldType -currentDepth $currentDepth -parentnode $newparentnode
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
                if ($normalvar) {
                    $fieldsHash[$($field.name)].Add("longName","$parentnode.$($field.name)")
                }
            }
        }
        return $fieldsHash
    } else {
        return $null
    }
}