option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: 101_LayerPackageDependencies
' Author: Knut Jetlund
' Purpose: Find layer package dependencies from schema packages
' Date: 20191020
'

sub layerPckDependencies

	outputTabs
	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0
	
	dim layerPackage as EA.Package
	dim relatedLayerPackage as EA.Package
	dim layerConnector as EA.Connector
	dim newConnector as EA.Connector

	'Create list of package and element ids and GUIDs
	Set lstPck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Create list of existing packages and elements",0
	For each layerPackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " Adding package to list: " & layerPackage.Name & "(" & layerPackage.Element.ElementID & ")", 0
		'Add packages to lists
		lstPck.Add layerPackage.Element.ElementID,layerPackage.packageGUID
		For each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " Adding package to list: " & thePackage.Name & "(" & thePackage.Element.ElementID & ")", 0
			'Add packages to lists
			lstPck.Add thePackage.Element.ElementID,thePackage.packageGUID
		Next
		
		dim i 
		for i = 0 to layerPackage.Connectors.Count -1
			layerPackage.Connectors.DeleteAt i, False
		next
	Next
	
	for each layerPackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------", 0
		Repository.WriteOutput "Script", Now & " Package: " & layerPackage.Name, 0
	
		for each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------", 0
			Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name & "(" & thePackage.Element.ElementID & ")", 0
			
			'Loop for all connectors in the package, identify related package and its layer package. Remove duplicate dependencies
			for each pckConnector in thePackage.Connectors
				'Repository.WriteOutput "Specific", Now & " Dependency #: " & i, 0	
				if pckConnector.Type = "Dependency" then
					if pckConnector.ClientID = thePackage.Element.ElementID then 
						'Repository.WriteOutput "Script", Now & " Dependency on " & pckConnector.SupplierID, 0
						set relatedPackage = getPackageFromList(lstPck, pckConnector.SupplierID)
						if not relatedPackage is nothing then					
							'Find related layer package
							set relatedLayerPackage = Repository.GetPackageByID(relatedPackage.ParentID)
							Repository.WriteOutput "Script", Now & " Dependency on " & relatedLayerPackage.Name & "." & relatedPackage.Name, 0
							'Check if layer package dependency exists
							dim exists
							exists = false								
							for each layerConnector in layerPackage.Connectors
								if layerConnector.SupplierId = relatedLayerPackage.Element.ElementID then
									exists = true
									Repository.WriteOutput "Specific", Now & " Dependency on " & relatedLayerPackage.Name & " exists" , 0
								end if
							next	
							if not exists and relatedLayerPackage.PackageID <> layerPackage.PackageID then
								'Add layer package dependency
								Repository.WriteOutput "Script", Now & " Adding dependency from " & layerPackage.Name & " to " & relatedLayerPackage.Name, 0
								set newConnector = layerPackage.Connectors.AddNew("", "Dependency")
								newConnector.SupplierID = relatedLayerPackage.Element.ElementID
								newConnector.Update
							end if
							layerPackage.Connectors.Refresh

						end if	
					end if	
				end if
			next
			thePackage.Connectors.Refresh
		next		
	next
	
	Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------", 0
	Repository.WriteOutput "Script", Now & " Done.",0
	
end sub

layerPckDependencies()
