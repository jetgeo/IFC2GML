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

sub main

	outputTabs
	set el = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Element: " & el.Name, 0
	set ePIF = Repository.GetProjectInterface

	el.StereotypeEx = "GML::FeatureType"
	el.Update
	
end sub

main