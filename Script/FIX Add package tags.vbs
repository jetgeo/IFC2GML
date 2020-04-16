option explicit

!INC Local Scripts.EAConstants-VBScript

' Script Name: Add package tags 
' Author: Knut Jetlund
' Purpose: Add xml tags for subpackages 
' Date: 20191128
'
' NOTE: Requires a package to be selected in the Project Browser
' 

'Recursive loop through subpackages, and do the thing
sub recPros(p)
	Repository.WriteOutput "Script", Now & " Package: " & p.Name, 0
	dim pEl as EA.Element
	set pEl = p.Element
	
	'Fjerner alle tagged values 
	Dim idxT
	For idxT = 0 To pEl.TaggedValues.Count - 1
		pEl.TaggedValues.DeleteAt idxT, False
	Next
	
	dim tagVal as EA.TaggedValue
	set tagVal = pEl.TaggedValues.AddNew ("xmlns", "ifc")
	tagVal.Update()
	set tagVal = pEl.TaggedValues.AddNew ("xsdDocument", p.Name & ".xsd")
	tagVal.Update()
	set tagVal = pEl.TaggedValues.AddNew ("xsdEncodingRule", "iso19136_2007")
	tagVal.Update()
	pEl.Update
	
	dim subP as EA.Package
	for each subP in p.packages
	    recPros(subP)
	next
end sub

sub main()
	' Show and clear the script output window
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"
		
	' Get the currently selected package in the tree to work on
	dim thePackage as EA.Package
	set thePackage = Repository.GetTreeSelectedPackage()
		
	if not thePackage is nothing and thePackage.ParentID <> 0 then
		recPros(thePackage)
		Repository.WriteOutput "Script", Now & " Finished, check the Error and Types tabs", 0 
		Repository.EnsureOutputVisible "Script"
	else
		' No package selected in the tree
		MsgBox( "This script requires a package to be selected in the Project Browser." & vbCrLf & _
			"Please select a package in the Project Browser and try again." )
	end if
end sub

main
