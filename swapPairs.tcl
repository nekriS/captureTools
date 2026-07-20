# set startPosition 2
# set endPosition 27
# set ypos 0
# set lengthPin 1

proc swapPairs {startPosition endPosition ypos lengthPin} {

	if {$ypos > 1} {
		set direction [expr {$lengthPin * 0.1}]
	} else {
		set direction [expr {$lengthPin * -0.1}]
	}

	set step [expr {$direction / 2}]

	set json_template {{"Pins":[{"StartX":%s,"StartY":%s,"HotSpotX":%s,"HotSpotY":%s}]}}

	for {set i $startPosition} {$i < [expr {$endPosition + 1}]} {incr i 2} {

		set realposition1 [expr {$i / 10.0}]
		set realposition2 [expr {($i + 1) / 10.0}]
		
		set realposition1 [format "%.1f" $realposition1]
		set realposition2 [format "%.1f" $realposition2]
		
		puts "$ypos $realposition1"
		puts "$ypos $realposition2"

		OrSymbolEditor::execute selectObjectsAtPoint [expr {$ypos + $step}] $realposition1 false false true
		OrSymbolEditor::execute dragSelectedPinObject [format $json_template $ypos 0 [expr {$ypos + $direction}] 0]
		OrSymbolEditor::execute selectObjectsAtPoint [expr {$ypos + $step}] $realposition2 false false true
		OrSymbolEditor::execute dragSelectedPinObject [format $json_template $ypos $realposition1 [expr {$ypos + $direction}] $realposition1]
		OrSymbolEditor::execute selectObjectsAtPoint [expr {$ypos + $step}] 0 false false true
		OrSymbolEditor::execute dragSelectedPinObject [format $json_template $ypos $realposition2 [expr {$ypos + $direction}] $realposition2]
	}

}

# пример использования, 2.2 - ширина схемсимвола
# foreach Y {0 2.2} {
	# swapPairs 1 12 $Y 1
# }


