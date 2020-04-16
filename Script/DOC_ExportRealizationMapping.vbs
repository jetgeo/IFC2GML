option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Export Realization Mapping
' Author: Knut Jetlund
' Purpose: Export mapping table for realizations from ISO 19107 concepts
' Date: 20191204
'
const path = "C:\DATA\GitHub\jetgeo\IFC2GML\UML\config\"
dim objMappingFile

sub exportMapping

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
	
	'Loop for all packages
	Dim layerPackage as EA.Package
	
	For each layerPackage in rootPackage.Packages
		For each thePackage in layerPackage.Packages
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
	
	
	Session.Output(Now & " Done.")

end sub

exportMapping