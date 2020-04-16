option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: RemoveSemicolonsInConstraints
' Author: Knut Jetlund
' Purpose: Remove Semicolons In Constraints
' Date: 20191022
'

sub removeSemicolonsInConstraints

	outputTabs
	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0
	
	dim layerPackage as EA.Package
	for each layerPackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------", 0
		Repository.WriteOutput "Script", Now & " Package: " & layerPackage.Name, 0
	
		for each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------", 0
			Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name & "(" & thePackage.Element.ElementID & ")", 0
			'Loop for all elements  
			For each el in thePackage.Elements
				Repository.WriteOutput "Script",Now & " Element: " & el.Name, 0

				for each elConstraint in el.Constraints
					if elConstraint.Type = "EXPRESS_WHERE" or elConstraint.Type = "EXPRESS_DERIVE" or elConstraint.Type = "EXPRESS_INVERSE" then									
						elConstraint.Notes = Replace(elConstraint.Notes,";","")
						elConstraint.Update()
						Repository.WriteOutput "Script", Now & " Fixed EXPRESS Constraint: " & elConstraint.Notes, 0					
					end if	
				next
			next
		next
	next
	
	Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------",0
	Repository.WriteOutput "Script", Now & " Done.",0

	
end sub

removeSemicolonsInConstraints()
