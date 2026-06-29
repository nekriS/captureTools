package require Tcl 8.4
package require utils 0.0.1
if { [catch {clipboard clear}] } {
  package require Tk 8.4
  wm withdraw .
}

package provide schemChecklist 0.0.1

namespace eval ::schemChecklist {
	proc registerMenuActions { args } {
		catch {
			InsertXMLMenu [list [list "captureToolsMenu"]                "" "" [list "popup"  "&Capture Tools"    "0"                               ]]
			InsertXMLMenu [list [list "captureToolsMenu" "Generate Schematic Checklist"] "" "" [list "action" "Generate Schematic &Checklist" "0" "Generate Schematic Checklist" "updateMenu"]]
			
			RegisterAction "Generate Schematic Checklist"  "capTrue" "" "::schemChecklist::generateSchemChecklist" "Schematic"
			RegisterAction "updateMenu" "capTrue" "" "capTrue"               ""
		}
	}
}

proc getNets { lInstOcc } {
	
	set lNullObj NULL
	set lStatus [DboState]
	#set lNets [list]


	set lPartInst [$lInstOcc GetPartInst $lStatus]
	if {$lPartInst != $lNullObj} {
		set lPinsIter [$lPartInst NewPinsIter $lStatus]
		set lPin [$lPinsIter NextPin $lStatus]
		set lNets [list]
		
		
					
		while {$lPin != $lNullObj} {
            set lPinName [DboTclHelper_sMakeCString]
            $lPin GetPinName $lPinName
            set sPinName [DboTclHelper_sGetConstCharPtr $lPinName]

			set lNet [$lPin GetNet $lStatus]
			if {$lNet != $lNullObj} {
			
				set lNetName [DboTclHelper_sMakeCString]
				$lNet GetNetName $lNetName 
				set sNetName [DboTclHelper_sGetConstCharPtr $lNetName]
				lappend lNets [list $sPinName $sNetName]

			} else {
				lappend lNets "N/C"
			}
			set lPin [$lPinsIter NextPin $lStatus]
		}
		delete_DboPartInstPinsIter $lPinsIter
	}
	return $lNets
}

proc getComponents { pDesign pInstOcc } {
    set table [list]

	set lStatus [DboState]
	set lNullObj NULL

    set lInstOccIter [$pInstOcc NewChildrenIter $lStatus  $::IterDefs_INSTS]
    set lChildOcc [$lInstOccIter NextOccurrence $lStatus]

    while { $lChildOcc!= $lNullObj} {
        set lInstOcc [DboOccurrenceToDboInstOccurrence $lChildOcc]
        set sRefDes [::utils::getPropertyValue $pDesign $lInstOcc "Reference"]

        
        set Nets [getNets $lInstOcc]
        
        if {[llength $Nets] > 2} {
            puts $sRefDes
            puts $Nets
        }
        

        set lChildOcc [$lInstOccIter NextOccurrence $lStatus]
	}
	
	delete_DboOccurrenceChildrenIter $lInstOccIter
    $lNullObj -delete
	$lStatus -delete
	
	return $table
}

proc ::schemChecklist::generateSchemChecklist { } {
    puts 0

    set lNullObj NULL
    set lStatus [DboState]

    if { [catch {set pDesign [GetActivePMDesign]}] } {
		puts "Error : No active design (1)"
		return -1
    }
	
	if { $pDesign == $lNullObj } {
		puts "Error : No active design (2)"
		return -1
    }

    set lRootOcc [$pDesign GetRootOccurrence $lStatus]
    
    set tableComponents [getComponents $pDesign $lRootOcc]
} 

::schemChecklist::registerMenuActions