option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Realization Mapping
' Author: Knut Jetlund
' Purpose: Mapping for realizations from ISO 19107 concepts
' Date: 20191212
'
const path = "C:\DATA\GitHub\jetgeo\IFC2GML\UML\config\"
dim objMappingFile
dim replacable

sub recSpecializations(superClass, strSuperClassPackage)
	dim aCon as EA.Connector
	dim subEl as EA.Element
	dim subsubEl as EA.Element
	dim subElP as EA.Package
	For each aCon in superClass.Connectors
		If aCon.Type = "Generalization" and aCon.SupplierID = superClass.ElementID then
			'Associated class has subtype(s) that must be checked for realization
			
			set subEl = Repository.GetElementByID(aCon.ClientID)
			set subElP = Repository.GetPackageByID(subEl.PackageID)		
			Repository.WriteOutput "Script", Now & " Subtype of associated class " & superClass.Name & ": " & subElP.Name & "." & subEl.Name, 0
			'Not replacable if subtype is outside of the package of the supertype and subtype has specific attributes or associations.
			If subElP.Name <> strSuperClassPackage then
				If subEl.Attributes.Count > 0 then 
					replacable = false
				else
					Dim subElCon as EA.Connector
					for each subElCon in subEl.Connectors
						If subElCon.Type = "Association" then replacable = false
					next
				end if
			end if	
			recSpecializations subEl, strSuperClassPackage
			
		end if
	Next


end sub

sub typeMapping

	'intitiateFilesAndLists()
	outputTabs
	
	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0

	'set rootPackage = Repository.GetTreeSelectedObject()
	'Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0

	'Create mapping file and internal list
	Set objFSO=CreateObject("Scripting.FileSystemObject")
	Set objMappingFile = objFSO.CreateTextFile(path & "\ifcMapping.csv",True)	
	objMappingFile.Write "package;ifcStereotype;ifcType;tc211Stereotype;tc211Type" & vbCrLf

	dim lstMapRealizations
	Set lstMapRealizations = CreateObject("System.Collections.SortedList")
	dim lstMappings
	Set lstMappings = CreateObject("System.Collections.SortedList")

	dim lstUnmappable
	Set lstUnmappable = CreateObject("System.Collections.SortedList")

	'Create mapping list and file
	Dim layerPackage as EA.Package	
	Repository.WriteOutput "Script", Now & " ", 0
	Repository.WriteOutput "Script", Now & " Creating mapping list", 0

	For each layerPackage in rootPackage.Packages
		For each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " ", 0
			Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
			
			'Loop for all elements with Stereotype "DataType" or "FeatureType"
			For each el in thePackage.Elements
				If el.StereotypeEx = "DataType" or el.StereotypeEx = "FeatureType" then
					For each con in el.Connectors
						if con.Type = "Realisation" or con.Type = "Realization" then 
							Repository.WriteOutput "Script", Now & " " & el.StereotypeEx & " : " & el.Name & " (" & el.ElementId & ")", 0
							set relEl = Repository.GetElementByID(con.SupplierID)
							If not relEl is nothing and left(relEl.name,3) <> "Ifc" then
								Repository.WriteOutput "Script", Now & " " & con.Type & " Supplier: " & relEl.Name & " (" & con.SupplierID & ")", 0
								objMappingFile.Write thePackage.Name & ";" & el.Stereotype & ";" & el.Name & ";" & relEl.Stereotype & ";" & relEl.Name & vbCrLf		
								'Add element IDs to internal list
								lstMapRealizations.Add el.ElementID, relEl.ElementID
							end if	
						end if	
					Next
				end if		
			Next	
		Next		
	Next	
	
	objMappingFile.Close
	Repository.WriteOutput "Script", Now & " ", 0
	Repository.WriteOutput "Script", Now & " Mapping list established", 0
	Repository.WriteOutput "Script", Now & " ", 0
	Repository.WriteOutput "Script", Now & " Performing mapping", 0
	Repository.WriteOutput "Script", Now & " ", 0
	
	For each layerPackage in rootPackage.Packages
		For each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " ", 0
			Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
			
			dim keyIndex, relElId
			dim assEl as EA.Element
			dim assElPck as EA.Package
			
			'el : The element.
			'elAttr : Element attributes
			'con : element connectors
			'assEl : the element that is either the attribute datatype or the end of an association
			'relEl : the element connected through a realization from the associated element
			
			'Loop for all elements with Stereotype "DataType" or "FeatureType"
			For each el in thePackage.Elements
				If el.StereotypeEx = "DataType" or el.StereotypeEx = "FeatureType" then
					'Attributes	
					For each elAttr in el.Attributes
						if lstMapRealizations.Contains(elAttr.ClassifierID) then
							set assEl = Repository.GetElementByID(elAttr.ClassifierID)
							set assElPck = Repository.GetPackageByID(assEl.PackageID)
							keyIndex = lstMapRealizations.IndexofKey(elAttr.ClassifierID)
							relElId = lstMapRealizations.GetByIndex(keyIndex)
							set relEl = Repository.GetElementByID(relElId)
							Repository.WriteOutput "Script", Now & " Datatype mapping: " & el.Name & "." & elAttr.Name & " from type " & elAttr.Type & " to " & relEl.Name, 0

							'Further analysis of the associated class to find out if it can be mapped							
							replacable = true
							'Analyze substructure of associated class
							recSpecializations assEl, assElPck.Name
							If replacable then
								Repository.WriteOutput "Script", Now & " Performing datatype mapping: " & assEl.Name & " to " & relEl.Name, 0
								elAttr.Type = relEl.Name
								elAttr.ClassifierID = relEl.ElementID
								elAttr.Update
								If not lstMappings.Contains(relEl.ElementID) then lstMappings.Add relEl.ElementID, relEl.ElementID

								'Repository.WriteOutput "Specific", Now & " Association mapping: " & thePackage.Name & "." & el.Name & "." & con.SupplierEnd.Role & " from class " & assEl.Name & " to " & relEl.Name, 0
								'Repository.WriteOutput "Specific", Now & " Mapping can be performed: " & assEl.Name & " to " & relEl.Name, 0
							else
								Repository.WriteOutput "Script", Now & " Datatype mapping not possible for " & thePackage.Name & "." & el.Name & "." & elAttr.Name & ": " & assEl.Name & " to " & relEl.Name, 0								
							end if

						end if
					Next
					
					'Associations
					For each con in el.Connectors
						If con.Type = "Association" and con.ClientID = el.ElementID then
							if lstMapRealizations.Contains(con.SupplierID) then
								set assEl = Repository.GetElementByID(con.SupplierID)
								set assElPck = Repository.GetPackageByID(assEl.PackageID)
								keyIndex = lstMapRealizations.IndexofKey(con.SupplierID)
								relElId = lstMapRealizations.GetByIndex(keyIndex)
								set relEl = Repository.GetElementByID(relElId)
								Repository.WriteOutput "Script", Now & " Association mapping: " & thePackage.Name & "." & el.Name & "." & con.SupplierEnd.Role & " from class " & assEl.Name & " to " & relEl.Name, 0
							
								'Further analysis of the associated class to find out if it can be mapped							
								replacable = true
								'Analyze substructure of associated class
								recSpecializations assEl, assElPck.Name
								If replacable then
									Repository.WriteOutput "Script", Now & " Performing association mapping: " & assEl.Name & " to " & relEl.Name, 0
									con.SupplierID = relEl.ElementID
									con.Update		
									If not lstMappings.Contains(relEl.ElementID) then lstMappings.Add relEl.ElementID, relEl.ElementID
							
									'Repository.WriteOutput "Specific", Now & " Association mapping: " & thePackage.Name & "." & el.Name & "." & con.SupplierEnd.Role & " from class " & assEl.Name & " to " & relEl.Name, 0
									'Repository.WriteOutput "Specific", Now & " Mapping can be performed: " & assEl.Name & " to " & relEl.Name, 0
								else
									Repository.WriteOutput "Script", Now & " Association mapping not possible for " & thePackage.Name & "." & el.Name & "." & con.SupplierEnd.Role & ": " & assEl.Name & " to " & relEl.Name, 0								
									If not lstUnmappable.Contains(assEL.ElementID) then lstUnmappable.Add assEL.ElementID, relEl.ElementID
								end if
							
							end if
						end if
					Next				
				end if		
			Next	
		Next		
	Next	

	Repository.WriteOutput "Script", Now & " ", 0
	Repository.WriteOutput "Script", Now & " Unmappables:", 0
	
	'Loop for unmappable list
	dim idx
	for idx = 0 to lstUnmappable.Count - 1
		set assEl = Repository.GetElementByID(lstUnmappable.GetKey(idx))
		set relEl = Repository.GetElementByID(lstUnmappable.GetByIndex(idx))
		
		'Add attribute to assEl
		dim attrName
		attrName = Lcase(Left(relEl.Name,1)) & Mid(relEl.Name,2)
		set elAttr = assEl.Attributes.AddNew(attrName,relEl.Name)
		elAttr.LowerBound = 0
		elAttr.UpperBound = 1
		elAttr.ClassifierId = relEl.ElementId
		elAttr.Update
		assEl.Attributes.Refresh
		Repository.WriteOutput "Script", Now & " Added attribute " & attrName & "(" & relEl.Name & ") to " & assEl.Name, 0
	next
	
	'Loop for documenting unique mapped datatypes
	for idx = 0 to lstMappings.Count - 1
		set relEl = Repository.GetElementByID(lstMappings.GetByIndex(idx))
		Repository.WriteOutput "Script", Now & " Used realization: " & relEl.Name, 0
	next
	
	
	Repository.WriteOutput "Script", Now & " ", 0
	Repository.WriteOutput "Script", Now & " Done", 0

end sub

typeMapping