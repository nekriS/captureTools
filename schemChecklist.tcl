package require Tcl 8.4
package require utils 0.0.1
package require stcXls
package require twapi

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

proc getPinTypeName { pinType } {
	switch $pinType $::DBO_IN {
		return "Input"
	} $::IO {
		return "Bidirectional"
	} $::DBO_OUT {
		return "Output"
	} $::OC {
		return "Open Collector"
	} $::PAS {
		return "Passive"
	} $::HIZ {
		return "3 State"
	} $::OE {
		return "Open Emitter"
	} $::POWER {
		return "Power"
	}
}

proc getStatus { sPinNumber sPinName sPinType sNetName } {
	if { ($sPinType == "Power") && ($sNetName == "N/C") } {
		return "Нет"
	} else {
		return "Не проверено"
	}
}

proc formatComponentList {inputList} {
    set groups [dict create]
    
    # 1. Группируем элементы по названию компонента
    foreach item $inputList {
        set refDes [lindex $item 0]
        set compName [lindex $item 1]
        
        # Добавляем RefDes в список для этого компонента
        dict lappend groups $compName $refDes
    }
    
    set resultParts {}
    
    # 2. Формируем строки для каждой группы
    dict for {compName refDesList} $groups {
        # Объединяем элементы через запятую, например: DD8, DD7, DD6
        set refDesStr [join $refDesList ", "]
        
        # Собираем кусок строки: Название (Элементы)
        lappend resultParts "$compName ($refDesStr)"
    }
    
    # 3. Соединяем все группы через запятую с пробелом
    return [join $resultParts ", "]
}

proc getNets { pDesign pInstOcc lInstOcc } {
	
	set lNullObj NULL
	set lStatus [DboState]
	#set lNets [list]
	#puts 1

	set lPartInst [$lInstOcc GetPartInst $lStatus]
	#puts 2
	if {$lPartInst != $lNullObj} {
		set lPinsIter [$lPartInst NewPinsIter $lStatus]
		set lPin [$lPinsIter NextPin $lStatus]
		set lNets [list]
		
		
					
		while {$lPin != $lNullObj} {

            set lPinName [DboTclHelper_sMakeCString]
            $lPin GetPinName $lPinName
            set sPinName [DboTclHelper_sGetConstCharPtr $lPinName]

			set lPinNumber [DboTclHelper_sMakeCString]
			$lPin  GetPinNumber $lPinNumber
			set sPinNumber [DboTclHelper_sGetConstCharPtr $lPinNumber]

			set sPinType [getPinTypeName [$lPin GetPinType $lStatus]]

			set lNet [$lPin GetNet $lStatus]
			if {$lNet != $lNullObj} {
				set lNetName [DboTclHelper_sMakeCString]
				$lNet GetNetName $lNetName 
				set sNetName [DboTclHelper_sGetConstCharPtr $lNetName]
				#puts 1
				#puts "$sPinNumber $sPinName $sPinType $sNetName"
				set value [::utils::getPropertyValue $pDesign $lInstOcc "Value"]
				#puts [::utils::getPropertyValue $pDesign $lInstOcc "Reference"]
				#puts $value
				if { ($sPinType != "Power") && ($sNetName != "GND")} {
					#puts a
					#puts [getInterconnect $pDesign $lPin [list $value]]
					lappend lNets [list [getStatus $sPinNumber $sPinName $sPinType $sNetName] $sPinNumber $sPinName $sPinType " $sNetName" [formatComponentList [getInterconnect $pDesign $pInstOcc $lInstOcc $lPin [list $value]]]]
				} else {
					#puts b
					lappend lNets [list [getStatus $sPinNumber $sPinName $sPinType $sNetName] $sPinNumber $sPinName $sPinType " $sNetName" ""]
				}
				#puts 2
			} else {
				lappend lNets [list [getStatus $sPinNumber $sPinName $sPinType "N/C"] $sPinNumber $sPinName $sPinType "N/C" ""]
			}
			set lPin [$lPinsIter NextPin $lStatus]
		}
		delete_DboPartInstPinsIter $lPinsIter
	}

	#puts $lNets
	return $lNets
}

proc getComponents { pDesign pInstOcc } {
    set table [list]

	set lStatus [DboState]
	set lNullObj NULL
	
    set lInstOccIter [$pInstOcc NewChildrenIter $lStatus  $::IterDefs_INSTS]
    set lChildOcc [$lInstOccIter NextOccurrence $lStatus]

	set i 1

    while { $lChildOcc!= $lNullObj} {
        set lInstOcc [DboOccurrenceToDboInstOccurrence $lChildOcc]
        
		set sRefDes [::utils::getPropertyValue $pDesign $lInstOcc "Reference"]

		#if { ($sRefDes == "RF1") || ($sRefDes == "DD12") || ($sRefDes == "DD31") } {

			if {[::utils::getPropertyValue $pDesign $lInstOcc "Implementation Type"] == "Schematic View"} {
				#puts "000"
				#puts $lInstOcc
				set hierarhtable [getComponents $pDesign $lInstOcc]
				#puts "111"
				set table [concat $table $hierarhtable]
				#puts "222"
				#puts $hierarhtable

			} else {

				set Nets [getNets $pDesign $pInstOcc $lInstOcc]

				if {[llength $Nets] > 2} {
					#puts $sRefDes
					#puts $Nets

					lappend table [list $sRefDes $Nets]
				}
			}


		#}

        set lChildOcc [$lInstOccIter NextOccurrence $lStatus]

		if {$i >= 200} {
			break
		}
		#set i [expr {$i + 1}]
	}
	
	delete_DboOccurrenceChildrenIter $lInstOccIter
    $lNullObj -delete
	$lStatus -delete
	
	return $table
}

proc combineList { source_list } {
	set grouped_dict [dict create]

	# Перебираем элементы исходного списка
	foreach item $source_list {
		set key [lindex $item 0]
		set val [lindex $item 1]
		
		# dict lappend автоматически создаст список для ключа, 
		# либо добавит новые элементы в уже существующий список
		dict lappend grouped_dict $key {*}$val
	}

	# Превращаем сгруппированный словарь обратно в список списков
	set result_list [list]
	dict for {key sublist} $grouped_dict {
		lappend result_list [list $key $sublist]
	}

	# Вывод результата
	return $result_list
}

proc getDboNetOccurrence { lPin {lTargetRef ""}} {
    set lStatus [DboState]
    set lNullObj NULL
    set lNetOcc $lNullObj

    set lNet [$lPin GetNet $lStatus]
    set lSchNet [$lNet GetSchematicNet]
    
    if {$lSchNet != $lNullObj} {
        
        $lSchNet GetOccurrences

        set OccCount [$lSchNet GetOccurrencesCount]
        #puts $OccCount
        if { $OccCount > 1 } {

            for {set i 0} {$i < $OccCount} {incr i} {
            
                set lOcc [$lSchNet GetOccurrencesAtPos $i]

                set lPathName [DboTclHelper_sMakeCString]
                $lOcc GetRefPathName $lPathName
                set sPathName [DboTclHelper_sGetConstCharPtr $lPathName]

                if { $lTargetRef eq [lindex [split $sPathName "/"] 0] } {
                    set lNetOcc [DboOccurrenceToDboNetOccurrence $lOcc]
                    break
                }
            }

        } else {
            set lDesign [GetActivePMDesign]
            set lRootInstOcc [$lDesign GetRootOccurrence $lStatus]
            set lSchOcc $lRootInstOcc
            set lNetOcc [$lSchOcc GetNetOccurrence $lSchNet $lStatus]
        }

    } else {
        set lNetOcc NULL
    }
    return $lNetOcc
}

proc getFlatNet { lInstOcc lInst } {

    set lStatus [DboState]

    set lNullObj NULL
	#puts $lInstOcc

	set pathName [DboTclHelper_sMakeCString]
	$lInstOcc GetPathName $pathName
	#puts "!!! [DboTclHelper_sGetConstCharPtr $pathName]"

	#puts "getflat portinst $lInst"
	set lPartInst [$lInst GetOwner]
	#puts "getflat partinst $lPartInst"

    if {$lInst != $lNullObj} {
        set lObjType [$lInst GetObjectType]
        set lFlatNet $lNullObj
        set lPinOcc $lNullObj

        if {$lObjType == 16} {
			set lPin $lInst
			set lNetOcc [getDboNetOccurrence $lPin "RF1"]

			if {$lNetOcc != $lNullObj} {
				set lFlatNet [$lNetOcc GetFlatNet $lStatus]
			}

        }
    }
    return $lFlatNet
}

proc getAllSchematicOccurences { pDesign lFlatNet lTopSchOcc } {
	set lStatus [DboState]
    set lNullObj NULL

	set SchOccus [list]
	lappend SchOccus $lTopSchOcc

	if {$lFlatNet != $lNullObj} {

		set lPortIter [$lFlatNet NewPortOccurrencesIter $lStatus]
		set lPort [$lPortIter NextPortOccurrence $lStatus]

		while {$lPort != $lNullObj} {

			set lPortInst [$lPort GetPortInst $lStatus]
			set lPartInst [$lPortInst GetOwner]
			set lPartOcc [$lPartInst GetObjectOccurrence $lTopSchOcc]

			if {$lPartOcc != $lNullObj} {

				set lInstOcc [DboOccurrenceToDboInstOccurrence $lPartOcc]
				if {[::utils::getPropertyValue $pDesign $lInstOcc "Implementation Type"] == "Schematic View"} {
					
					lappend SchOccus $lInstOcc

					set hierSchOccus [getAllSchematicOccurences $pDesign $lFlatNet $lInstOcc]
					set SchOccus [concat $SchOccus $hierSchOccus]
				}
			}

			set lPort [$lPortIter NextPortOccurrence $lStatus]
		}
	}

	return [lsort -unique $SchOccus]
}

proc getInterconnect { pDesign pInstOcc lInstOcc lPin {exception [list]} } {

    set lStatus [DboState]
    set lNullObj NULL
    #set pDesign [GetActivePMDesign]
	#set lhierarhInstOcc NULL
	

    set ic [list]

    if {$lPin != $lNullObj} {

        set lFlatNet [getFlatNet $lInstOcc $lPin]
        #puts "FLATNET !!! $lFlatNet"

		if {$lFlatNet != $lNullObj} {

			set lRootInstOcc [$pDesign GetRootOccurrence $lStatus]
			# Только дочерние элементы
			#set lSchOccs [getAllSchematicOccurences $pDesign $lFlatNet $pInstOcc]
			# Все элементы от рута
			set lSchOccs [getAllSchematicOccurences $pDesign $lFlatNet $lRootInstOcc]
			lappend lSchOccs $pInstOcc

			set lPortIter [$lFlatNet NewPortOccurrencesIter $lStatus]
			set lPort [$lPortIter NextPortOccurrence $lStatus]

			while {$lPort != $lNullObj} {
				#puts "port $lPort"

				set lPortName [DboTclHelper_sMakeCString]
				$lPort GetName $lPortName 
				set sPortName [DboTclHelper_sGetConstCharPtr $lPortName]
				#puts "name $sPortName"

				
				

				set lPortInst [$lPort GetPortInst $lStatus]
				#puts "$lPortInst"

				set lPortType [$lPortInst GetObjectType]
				#puts $lPortType


				set lPartInst [$lPortInst GetOwner]

				#set lSchOcc [GetInstanceOccurrence]
				 ###problem


				# set lRootInstOcc [$pDesign GetRootOccurrence $lStatus]
				# set lSchOcc $pInstOcc

				# if { $lhierarhInstOcc != $lNullObj } {
				# 	set pInstOcc $lhierarhInstOcc
				# }
				# set lSchOcc [[$lInstOcc GetParent] GetObjectOccurrence $lRootInstOcc]
				# puts $lSchOcc
				# set lName [DboTclHelper_sMakeCString]
				# $lSchOcc GetPathName $lName
				# puts [DboTclHelper_sGetConstCharPtr $lName]

				foreach lSchOcc $lSchOccs {
					set lPartOcc [$lPartInst GetObjectOccurrence $lSchOcc]

					if {$lPartOcc != $lNullObj} {

						set lInstOcc [DboOccurrenceToDboInstOccurrence $lPartOcc]
						#puts $lPartOcc
						
						

						if {[getPropertyValue $pDesign $lInstOcc "Implementation Type"] == "Schematic View"} {
					
							#puts "hernya"
							#set lhierarhInstOcc $lInstOcc

						} else {

							set lRef [DboTclHelper_sMakeCString]
							$lInstOcc GetReference $lRef 
							set sRef [DboTclHelper_sGetConstCharPtr $lRef]
							#puts "A!!!! $sRef"
							set value [::utils::getPropertyValue $pDesign $lInstOcc "Value"]

							if {[lsearch $exception $value] == -1} {
								lappend ic [list $sRef $value]
							}
						
						}

					}
				}

				set lPort [$lPortIter NextPortOccurrence $lStatus]

			}
			delete_DboFlatNetPortOccurrencesIter $lPortIter
		}

    }
    #return $ic
	return [lsort -unique $ic]
}

proc writeToExcel { table } {

	set excel [twapi::comobj Excel.Application]

	$excel Visible false

	set workbooks [$excel Workbooks]
    set workbook [$workbooks Add]
    set worksheets [$workbook Worksheets]
    set worksheet [$worksheets Item [expr 1]]

	$worksheet Select
    $worksheet Name "Schematic Checklist"
	set row 1
	::stcXls::paste $worksheet "A${row}" [list {"Не проверено"}]

	set row 2
	set header [list {"Статус" "Номер контакта" "Имя контакта" "Тип контакта" "Цепь" "Подключение" "Комментарий"}]
	::stcXls::paste $worksheet "A${row}" $header

	set resultColumn [$worksheet Range "A${row}:G${row}"]
	$resultColumn HorizontalAlignment $::stcChkLst::alignCenter
	$resultColumn VerticalAlignment   $::stcChkLst::alignCenter
	set font [$resultColumn Font]
	$font Bold 1
	$font -destroy

	set rangeObj [$worksheet Range "A2:B2"]
	$rangeObj RowHeight 24
	$rangeObj -destroy

	::stcXls::freeze $excel $worksheet "A3"

	set row 3
	set element 1
	foreach item $table {
		#puts "row $row"
		#puts "item [lindex $item 0]"
		#puts "item [lindex $item 1]"
		::stcXls::paste $worksheet "A${row}" [list [lindex $item 0]]
		set row [expr {$row + 1}]
		#puts "row $row"
		::stcXls::paste $worksheet "A${row}" [lindex $item 1]

		set nextRow [expr {$row + [llength [lindex $item 1]]}]
		for {set rowi $row} {$rowi <= $nextRow} {incr rowi} {
			::stcXls::chkFill $worksheet "\$A${rowi}" "A${rowi}:G${rowi}"
		}

		set nextRow_ [expr {$nextRow - 1}]
		set resultColumn [$worksheet Range "A${row}:A${nextRow_}"]
		$resultColumn HorizontalAlignment $::stcChkLst::alignCenter
		$resultColumn VerticalAlignment   $::stcChkLst::alignCenter
		set font [$resultColumn Font]
		$font Bold 1
		$font -destroy

		if { 1 } {
			set val [$resultColumn Validation]
			$val -callnamedargs Add Type [expr 3] AlertStyle [expr 1] Operator [expr 1] Formula1 {Не проверено; Нет; Да}
			#$val InputTitle {Выберите значение из списка}
			#$val InputMessage {Для заполнения всего столбца ниже текущей ячейки её значением нажмите Ctrl + Shift + 'Стрелка вниз', а затем Ctrl + D}
			$val ErrorTitle {Недопустимый ввод!}
			$val ErrorMessage {Допустимые значения: "Да", "Нет" и "Не проверено".}
			$val -destroy
		}

		set row $nextRow

		puts "${element} / [llength $table]"
		set element [expr {$element + 1}]
	}
	
	

	

	

	#::stcXls::autoFit $worksheet "A1:E$row"
	::stcXls::widths  $worksheet  {18 18 30 18 18 50 70}

	set row [expr {$row - 1}]
	set tabl [$worksheet Range "A2:G$row"]
	set borders [$tabl Borders]
	$borders Weight 2

	$tabl -destroy
	$borders -destroy


	$resultColumn -destroy


	$worksheet -destroy
	$worksheets -destroy
	$workbook -destroy
	$workbooks -destroy

	$excel Visible true
	$excel -destroy
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

    set tableComponents [combineList [getComponents $pDesign $lRootOcc]]

	writeToExcel $tableComponents
} 

::schemChecklist::registerMenuActions