option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Fix constraint type
' Author: Knut Jetlund
' Purpose: Set correct constraint type
' Date: 20191017
'

sub fixConstraints

	outputTabs
	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0
	
	for each thePackage in rootPackage.Packages
		Session.Output(Now & " -----------------------------------------------------------------")
		Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
		'Loop for all elements with Stereotype "FeatureType" 
		For each el in thePackage.Elements
			If el.Stereotype = "FeatureType" then
				Repository.WriteOutput "Script",Now & " Element: " & el.Name, 0
				
				for each elConstraint in el.Constraints
					if instr(elConstraint.Notes,"EXPRESS WHERE") > 0 then 
						elConstraint.Type = "EXPRESS_WHERE"
						elConstraint.Notes = Mid(elConstraint.Notes, 14)
						elConstraint.Status = "Approved"
						elConstraint.Update()
						Repository.WriteOutput "Script", Now & " EXPRESS WHERE Constraint: " & elConstraint.Notes, 0
					elseif instr(elConstraint.Notes,"EXPRESS DERIVE") > 0 then 
						elConstraint.Type = "EXPRESS_DERIVE"
						elConstraint.Notes = Mid(elConstraint.Notes, 15)
						elConstraint.Status = "Approved"
						elConstraint.Update()
						Repository.WriteOutput "Script", Now & " EXPRESS DERIVE Constraint: " & elConstraint.Notes, 0
					elseif Left(elConstraint.Notes, 2) = ": " then
						elConstraint.Notes = Mid(elConstraint.Notes, 3)
						elConstraint.Update()
						Repository.WriteOutput "Script", Now & " Fixed EXPRESS Constraint: " & elConstraint.Notes, 0
					else
						elConstraint.Notes = LTrim(TrimTabs(elConstraint.Notes))
						'elConstraint.Notes = Replace(elConstraint.Notes, vbCrlf," ")
						elConstraint.Update()
						Repository.WriteOutput "Script", Now & " Fixed EXPRESS Constraint: " & elConstraint.Notes, 0					
					end if	
				next
			end if	
		next
	next
	
	Session.Output(Now & " -----------------------------------------------------------------")
	Repository.WriteOutput "Script", Now & " Done.",0

	
end sub

fixConstraints()
