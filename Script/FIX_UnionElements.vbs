option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: FIX Union Elements
' Author: Knut Jetlund
' Purpose: change from typename to attribute with datatype in unions
' Date: 20190917
'

sub unionReferences

	intitiateFilesAndLists()
	'outputTabs
	'set rootPackage = Repository.GetTreeSelectedObject()
	'Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0

	'Loop for all packages
	Dim layerPackage as EA.Package
	
	For each layerPackage in rootPackage.Packages
		For each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
			
			'Loop for all elements with Stereotype "Union"
			For each el in thePackage.Elements
				If el.Stereotype = "Union" then
					Repository.WriteOutput "Script", Now & " Union: " & el.Name, 0

					'Loop for all attributes
					For each elAttr in el.Attributes
						Repository.WriteOutput "Script", Now & " Union member: " & elAttr.Name, 0
						'Find attribute data type element in list
						Dim strType, strName
						strType = TrimTabs(elAttr.Name)
						strName = Lcase(Mid(strType,4,1)) & Mid(strType,5)
						set relEl = getElementFromList(lstClasses, strType)
						
						if not relEl is nothing then
							'set attribute type id = related elementID
							elAttr.Name = strName
							elAttr.Type = strType
							elAttr.ClassifierID = relEl.ElementId 
							elAttr.Update
							Repository.WriteOutput "Script", Now & " Set data type for " &  strName & " to: " & relEl.Name & " (id " & relEl.ElementID & ")", 0
						else		
							Repository.WriteOutput "Error", Now & " Union member data type not found: " & thePackage.Name & "." & el.Name & "." & strName & " type: " & strType, 0
						end if
						
					Next
					
				end if		
			Next	
		Next		
	Next	
	
	Session.Output(Now & " Done.")

end sub

unionReferences