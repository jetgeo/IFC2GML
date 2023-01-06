option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Context diagrams
' Author: Knut Jetlund
' Purpose: Generate context diagrams for each class
' Date: 20190917
'
sub elementInDiagram(e)

	'Add class to diagram, if not there
	set eDiagramObject = Nothing
	for each eDO in eDiagram.DiagramObjects
		if eDO.ElementId = e.elementID then set eDiagramObject = eDO 
	next
	if eDiagramObject is nothing then 
		Repository.WriteOutput "Script", Now & " Add Class: " & e.Name ,0
		set eDiagramObject = eDiagram.DiagramObjects.AddNew("","")
		eDiagramObject.ElementID = e.ElementID	
	end if

	eDiagramObject.ShowConstraints = true
	eDiagramObject.ElementDisplayMode = 1
	eDiagramObject.update
	eDiagram.DiagramObjects.Refresh
	eDiagram.Update
end sub

sub recLoopRelatedTypes(re)
'Recursive loop for adding related types (attribute data types and associated types) to diagram

	'Add class to diagram, if not there
	elementInDiagram(re)
	'Loop for attributes
	For each elAttr in re.Attributes
		'Find datatype element and add to diagram
		set relEl = Nothing
		if not isnull(elAttr.ClassifierID) and elAttr.ClassifierID <> 0 then 
			Repository.WriteOutput "Script", Now & " Attribute: " & re.Name & "." & elAttr.Name & " (" & elAttr.Type & ")",0
			set relEl = Repository.GetElementByID(elAttr.ClassifierID)
			'Recursive  - Find data types for attributes in the data types
			if not relEl is Nothing then recLoopRelatedTypes(relEl)	
		end if
	Next	

	'Loop for connectors
	for each con in re.Connectors
		'Repository.WriteOutput "Specific", Now & " Connector from: " & re.Name & " :" & con.Type,0
		if con.ClientID <> con.SupplierID then
			if con.ClientID = re.elementID and con.Type = "Association" then 
				set relEl = Repository.GetElementByID(con.SupplierID) 
				Repository.WriteOutput "Script", Now & " Association: " & re.Name & "." & con.SupplierEnd.Role & " (" & relEl.Name & ")",0
				recLoopRelatedTypes(relEl)	
			elseif con.ClientID = re.elementID and con.Type = "Generalization" then 
				set relEl = Repository.GetElementByID(con.SupplierID) 
				Repository.WriteOutput "Script", Now & " Generalization: " & re.Name & " to supertype " & relEl.Name,0
				recLoopRelatedTypes(relEl)	
			'Realization
			elseif con.ClientID = re.elementID and (con.Type = "Realization" or con.Type = "Realisation") then 
				set relEl = Repository.GetElementByID(con.SupplierID) 
				Repository.WriteOutput "Specific", Now & " Realization: " & re.Name & " to supertype " & relEl.Name,0
				'recLoopRelatedTypes(relEl)		
			end if
		end if
	Next

end sub

sub contextDiagrams

	outputTabs
	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0
	set ePIF = Repository.GetProjectInterface

	'Loop for all packages
	For each thePackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
		'Loop for all elements with Stereotype "FeatureType" 
		For each el in thePackage.Elements
			If el.Type = "Class" then
				Repository.WriteOutput "Script",Now & " Element: " & el.Name, 0
				
				'Context diagram
				set eDiagram = nothing
				dim i
				for i = 0 to thePackage.Diagrams.Count  -1 
					set eD = thePackage.Diagrams.GetAt(i)
						if eD.Name = "Context diagram: " & el.Name then 
						thePackage.Diagrams.DeleteAt i, false
						Repository.WriteOutput "Specific", Now & " Delete context diagram: " & el.Name ,0
					end if			
				next
				thePackage.Diagrams.refresh
				
				For each eD in thePackage.Diagrams
					if eD.Name = "Context diagram: " & el.Name then 
						set eDiagram = eD
					end if	
				Next
				if eDiagram is nothing then 
					Repository.WriteOutput "Script", Now & " Create context diagram: " & el.Name ,0
					set eDiagram = thePackage.Diagrams.AddNew("Context diagram: " & el.Name,"Class")
					eDiagram.Update
					'repository.CloseDiagram(eDiagram.DiagramID)
				end if	
				
				'Add classes to diagram, if not there
				recLoopRelatedTypes(el)
								
				'Layout diagram						
				'ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 10, 8, 20, 20, True
				'repository.CloseDiagram(eDiagram.DiagramID)
				Session.Output(Now & " -----------------------------------------------------------------")
				
			end if		
		Next	
		'if thePackage.Name <> "Overview" and thePackage.Name <> "Test" then exit sub
	Next				

	'Extra loop for layout 
	For each thePackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
		'Loop for all elements with Stereotype "FeatureType" 
		For each el in thePackage.Elements
			If el.Stereotype = "FeatureType" then
				
				'Context diagram
				set eDiagram = nothing
				
				For each eD in thePackage.Diagrams
					if eD.Name = "Context diagram: " & el.Name then 
						set eDiagram = eD
						'Layout diagram						
						Repository.WriteOutput "Script",Now & " Layout diagram: " & eD.Name, 0
						ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 10, 8, 20, 20, True
						repository.CloseDiagram(eDiagram.DiagramID)
					end if	
				Next
											
			end if		
		Next	
		Repository.WriteOutput "Script",Now & " -----------------------------------------------------------------", 0
		'if thePackage.Name <> "Overview" and thePackage.Name <> "Test" then exit sub
	Next				


	Session.Output(Now & " Done.")

end sub

contextDiagrams