function getLongNameFields {
    param (
        [hashtable]$fields
    )
    foreach ($field in $fields.GetEnumerator()) {
        if ($field.Value.longName) {
            [array]$longNameFields += $field.value.longName
        }
        if ($field.Value.hasMore) {
            [array]$longNameFields += getLongNameFields -Fields $field.Value.fields 
        }
    }
    return $longNameFields
}