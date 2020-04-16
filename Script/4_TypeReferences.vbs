option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Type references
' Author: Knut Jetlund
' Purpose: Reference attribute data types to correct elementId.
' Date: 20190917
'

sub typeReferences

	intitiateFilesAndLists()
	'outputTabs
	'set rootPackage = Repository.GetTreeSelectedObject()
	'Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0

	Dim i

	'Loop for all packages
	For each thePackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
		
		'Class diagram
		set eDiagram = nothing
		For each eD in thePackage.Diagrams
			if eD.Name = thePackage.Name & " Classes" then 
				set eDiagram = eD
			end if	
		Next

		'Loop for all elements with Stereotype "FeatureType" or "DataType"
		For each el in thePackage.Elements
			If el.Stereotype = "FeatureType" or el.Stereotype = "DataType" then
				Repository.WriteOutput "Script",Now & " Element: " & el.Name, 0
				
				'for i = 0 to el.Connectors.Count -1
				'	set con = el.Connectors.GetAt(i)
				'	if not con.Type = "Generalization" and not con.Type = "Realization" and not con.Type = "Realisation" then el.Connectors.DeleteAt i, False
				'next
				'el.Connectors.Refresh

				'Loop for all attributes
				For i = 0 To el.Attributes.Count - 1
					set elAttr = el.Attributes.GetAt(i)
					'Repository.WriteOutput "Script",Now & " Attribute: " & elAttr.Name & " type: " & elAttr.Type & " (id " & elAttr.ClassifierId & ")", 0
					'Find attribute data type element in list
					set relEl = getElementFromList(lstClasses, elAttr.Type)
					If relEl is nothing then
						'Special handling for REAL, INTEGER etc. 
						'Repository.WriteOutput "Specific",Now & " Specific conversion for attribute: " & elAttr.Name & " type: " & elAttr.Type & " (id " & elAttr.ClassifierId & ")", 0
						Select case elAttr.Type
							case "REAL" 
								set relEl = Repository.GetElementByGuid(dtRealGUID)
							case "INTEGER" 
								set relEl = Repository.GetElementByGuid(dtIntegerGUID)
							case "NUMBER" 
								set relEl = Repository.GetElementByGuid(dtNumberGUID)
							case "STRING" 
								set relEl = Repository.GetElementByGuid(dtCharacterStringGUID)
							case "BOOLEAN" 
								set relEl = Repository.GetElementByGuid(dtBooleanGUID)
							case "LOGICAL"
								set relEl = Repository.GetElementByGuid(dtLogicalGUID)
						end select
					end if
					
					if not relEl is nothing then
						If relEl.Stereotype = "FeatureType" then 
							Repository.WriteOutput "Script",Now & " Convert attribute " &  elAttr.Name & " to association to: " & relEl.Stereotype & " " & relEl.Name & " (id " & relEl.ElementID & ")", 0
						
							'add association 
							set con = Nothing
							dim tmpCon as EA.Connector
							For each tmpCon in el.Connectors
								if tmpCon.ClientID = relEl.ElementID and tmpCon.SupplierID=el.ElementID then
									set con = tmpCon
								end if
							next
							If con is nothing then
								'Add new connector
								Repository.WriteOutput "Script",Now & " Adding association from " &  el.Name & " to: " & relEl.Stereotype & " " & relEl.Name & " (id " & relEl.ElementID & ")", 0
								set con = el.Connectors.AddNew("", "Association")
								con.ClientID = el.ElementID
								con.SupplierID = relEl.ElementID
								con.Update()
							end if

							'Set role name, navigability and multiplicity
							con.SupplierEnd.Navigable = "Navigable"
							con.SupplierEnd.Role = elAttr.Name
							con.SupplierEnd.Cardinality = elAttr.LowerBound & ".." & elAttr.UpperBound						
							con.ClientEnd.Navigable = "Non-Navigable"
							con.Direction = "Source -> Destination"
							if elAttr.AllowDuplicates = false then 
								con.SupplierEnd.AllowDuplicates = false
							else
								con.SupplierEnd.AllowDuplicates = true
							end if
							if elAttr.isOrdered = true then con.SupplierEnd.Ordering = 1
							if elAttr.isDerived = true then con.SupplierEnd.Derived = true
							con.Update
							
							'Check that associated feature type is in class diagram		
							
							exists = false
							for each eDO in eDiagram.DiagramObjects
								if eDO.ElementID = relEl.ElementID then
									set eDiagramObject = eDO
									exists = true
								end if
							next
							if exists = false then 
								set eDiagramObject = eDiagram.DiagramObjects.AddNew("","")
								eDiagramObject.ElementID = relEl.ElementID
							end if
							eDiagramObject.ShowConstraints = true
							eDiagramObject.ElementDisplayMode = 1
							eDiagramObject.update

							'remove attribute
							el.Attributes.DeleteAt i, False

						Else
							'set attribute type id = elementID
							Repository.WriteOutput "Script",Now & " Set attribute data type for " &  elAttr.Name & " to: " & relEl.Stereotype & " " & relEl.Name & " (id " & relEl.ElementID & ")", 0
							elAttr.ClassifierID = relEl.ElementId 
							elAttr.Update
						end if	
					else
						Repository.WriteOutput "Error",Now & " Attribute data type not found: " & thePackage.Name & "." & el.Name & "." & elAttr.Name & " type: " & elAttr.Type, 0
					end if
				Next
				
			end if		
		Next	
		
		if not eDiagram is nothing then
			ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
			repository.CloseDiagram(eDiagram.DiagramID)
		end if		

	Next				
	
	Session.Output(Now & " Done.")

end sub

typeReferences