function shouldShowField {
    param(
        [object[]]$fields
    )


    $normalTypeList = ('Int','String','Boolean','ID','Float','Date','Long','DateTime','URL','UUID','DateTime')
    # Loop through fields and determine types
    foreach ($field in $fields) {
        # Get the type of the field, if it is in the list, return immidiately
        $fieldtype = getFieldType $field
        if ($normalTypeList -contains $fieldType) {
            return $true
        }
    }
    return $false
}