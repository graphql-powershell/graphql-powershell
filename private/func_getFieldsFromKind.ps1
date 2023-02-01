# Recursive function designed to recursively populate the fields for the query
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
                    
                    $temp = $typelisthash[$fieldType]
                    # If we are only one depth away we need to ensure we peak ahead so we don't have blank objects
                    #problem is with this statement
                    if ($global:GraphQLInterfaceConnection.Depth - $currentDepth -eq 1) {

                        $show = shouldShowField $temp.fields
                        <#
                        $scalarFields = $temp.fields.type | where {$_.name -in $normalTypeList}
                        if ($null -eq $scalarFields) {
                            $show = $false
                        }
                        else {
                            Write-Host "Found scalar for $fieldType which is $scalarFields"
                            $show = $true
                        }
                        #>

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