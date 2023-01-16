function parseFields {
    param ($fields, $query)
    $output = ""
  
    if ($null -ne $fields) {
      foreach ($field in $fields) {
        $output += " $($field.name) "
      }
    }
  
    return $output
  }