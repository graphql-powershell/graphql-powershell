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