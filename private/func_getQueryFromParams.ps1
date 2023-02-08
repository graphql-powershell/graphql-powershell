function getQueryFromParams {
    param (
        [String[]]$array,
        [string]$cmdlet
    )

    # Let's get the argument Syntax
    $cmd = $allqueries[$cmdlet]




    $array = $array | Sort
    # Get the longest item
    $longestItem = 0
    foreach ($item in $array) {
        $length = $item.split(".").count - 1
        if ($longestItem -lt $length) {
            $longestItem = $length
        }
    }
    
    $objArray = @()
    foreach ($item in $array) {
        $fields = $item.split(".")
        $obj = New-Object -TypeName PScustomObject
        $i = 1
        while ($i -le $longestItem) {
            $propName = "Item$i"
            
            if ($fields[$i]) {
                $propValue = $fields[$i]
            } else {
                $propValue = ""
            }
            $obj | Add-Member -NotePropertyName $propName -NotePropertyValue $propValue
            $i++
        }
        $objArray += $obj
    }



    $argumentSyntax = buildArgumentSyntax -query $cmd
    $strTest = $argumentSyntax + " { "
    $group = $objArray | Group-Object -Property "Item1"
    $strTest += buildFieldsFromLongNames -group $group -level 1 -maxLevel $longestItem
    $strTest += " } } "
    return $strTest

}