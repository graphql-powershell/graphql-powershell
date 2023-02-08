function buildFieldsFromLongNames {
    param (
        [Object[]]$group,
        [Int]$level,
        [Int]$maxLevel
    )

    foreach ($grp in $group) {
        if ($grp.Count -gt 1) {
            $strGroup += " $($grp.Name)  { "
            $p = $level + 1
            $itgrp = "Item$p"
            $newGroup = $grp.Group | Group-Object -Property $itgrp
            $strGroup += buildFieldsFromLongNames -group $newGroup -level $p -maxLevel $maxLevel
            $strGroup += " } "
        } else {
            $n = $level + 1
            $nextItem = "Item$n"
            if ($grp.Group.$nextItem) {
                $strGroup += " $($grp.Name) { "
                $newgroup = $grp.Group | Group-Object -Property $nextItem
                $strGroup += buildFieldsFromLongNames -group $newGroup -level $n -maxLevel $maxLevel
                $strGroup += " } "
            } else {
               $strGroup += " $($grp.Name) "
            }     
        } 
    }
    return $strGroup
}