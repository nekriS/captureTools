package provide utils 0.0.1

namespace eval ::utils {

}

proc ::utils::getPropertyValue { pDesign pInstOcc pPropertyName } {

  set lNullObj NULL
  set lValue ""
  #$lNullObj

  set lPropName [DboTclHelper_sMakeCString $pPropertyName]
  set lPropValue [DboTclHelper_sMakeCString]

  set lStatus [DboState]
  set lPartInst [$pInstOcc GetPartInst $lStatus]
  
  set lIsVariantInst 0
  if { [$pInstOcc IsVariantPropMapEmpty] == 0} {
    set lIsVariantInst 1
  } elseif { $lPartInst != $lNullObj && [$lPartInst IsVariantPropMapEmpty] == 0} {
    set lIsVariantInst 2
  }


  if {$lIsVariantInst == 1 } {

    set lFindValue [$pInstOcc GetVariantProp $lPropName $lPropValue]

    if { $lFindValue == 1} {
      set lPropValueString [DboTclHelper_sGetConstCharPtr $lPropValue]
      set lDesignCISNotStuffedString [DboTclHelper_sGetConstCharPtr [$pDesign GetCISNotStuffedString]]

      if { $lPropValueString !=  $lDesignCISNotStuffedString} {
        set lValue $lPropValueString
      }
    }

  } elseif {$lIsVariantInst == 2 } {

    set lFindValue [$lPartInst GetVariantProp $lPropName $lPropValue]

    if { $lFindValue == 1} {
      set lPropValueString [DboTclHelper_sGetConstCharPtr $lPropValue]
      set lDesignCISNotStuffedString [DboTclHelper_sGetConstCharPtr [$pDesign GetCISNotStuffedString]]

      if { $lPropValueString !=  $lDesignCISNotStuffedString} {
        set lValue $lPropValueString
        #puts [concat "Variant Part Number (Instance)" $lValue]
      }
    }

  } else {

    set lStatus [$pInstOcc GetEffectivePropStringValue $lPropName $lPropValue]
    if {[$lStatus OK] == 1} {
      set lValue [DboTclHelper_sGetConstCharPtr $lPropValue]
    }
    $lStatus -delete

  }

  return $lValue
}