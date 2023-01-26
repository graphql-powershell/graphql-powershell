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