!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters

dim ePIF as EA.Project
dim rootPackage as EA.Package
dim thePackage as EA.Package
dim relatedPackage as EA.Package
dim pckConnector as EA.Connector
dim con as EA.Connector
dim eDiagram as EA.Diagram
dim eD as EA.Diagram
dim eDiagramObject as EA.DiagramObject
dim eDO as EA.DiagramObject
dim el as EA.Element
dim relEl as EA.Element
dim elAttr as EA.Attribute
dim elConstraint as EA.Constraint
dim elOperation as EA.Method
dim tagVal as EA.TaggedValue
dim attrTag as EA.AttributeTag
dim conTag as EA.ConnectorTag

dim strPackageName

dim objFSO, objFolder, objFiles, objFile, objTextFile, strNextLine
dim lstPck, lstUCasePck, lstClasses, lstTypes
dim exists

sub packageAndDiagram
	set thePackage = getPackageFromList(lstPck, strPackageName)
	'Class diagram
	set eDiagram = nothing
	For each eD in thePackage.Diagrams
		if eD.Name = thePackage.Name & " Classes" then 
			set eDiagram = eD
		end if	
	Next
	if eDiagram is nothing then 
		Repository.WriteOutput "Script", Now & " Create class diagram",0
		set eDiagram = thePackage.Diagrams.AddNew(thePackage.Name & " Classes","Class")
		eDiagram.Update
	end if		
end sub

sub outputTabs()
	'Faner for informasjon om kjøringen
	Repository.EnsureOutputVisible "Script"
	Repository.ClearOutput "Script"
	Repository.CreateOutputTab "Error"
	Repository.ClearOutput "Error"
	Repository.CreateOutputTab "Specific"
	Repository.ClearOutput "Specific"
end sub

Function TrimTabs(str)
	Dim re
    Set re = New RegExp
    re.Pattern = "^\s+|\s+$"
    re.Global  = True
    TrimTabs = re.Replace(str, "")
End Function

sub addElement2Diagram
'Add element to diagram
	exists = false
	for each eDO in eDiagram.DiagramObjects
		if eDO.ElementID = el.ElementID then exists = true
	next
	if exists = false then 
		set eDiagramObject = eDiagram.DiagramObjects.AddNew("","")
		eDiagramObject.ElementID = el.ElementID
		eDiagramObject.update
	end if
end sub

sub intitiateFilesAndLists
	'Create objects containing Express files and UML Packages
	' Show and clear the script output window
	
	outputTabs
	'Repository.EnsureOutputVisible "Script"
	'Repository.ClearOutput "Script" 

	set ePIF = Repository.GetProjectInterface

	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0
	
	'Create list of package and element names and GUIDs
	Set lstPck = CreateObject("System.Collections.SortedList")
	Set lstUcasePck = CreateObject("System.Collections.SortedList")
	Set lstClasses = CreateObject("System.Collections.SortedList")

	Repository.WriteOutput "Script", Now & " Create list of existing packages and elements",0
	Dim layerPackage as EA.Package
	For each layerPackage in rootPackage.Packages
		For each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " Adding package to list: " & thePackage.Name, 0
			'Add packages to lists
			lstPck.Add thePackage.Name,thePackage.packageGUID
			lstUcasePck.Add Ucase(thePackage.Name),thePackage.packageGUID
			'Add classes to list
			For each el in thePackage.Elements
				if el.Type = "Class" or el.Type = "Enumeration" then
					Repository.WriteOutput "Script", Now & " Adding class to list: " & el.Name, 0
					lstClasses.Add el.Name,el.ElementGUID
				end if
			Next
		Next
	Next
	
	Session.Output(Now & " -----------------------------------------------------------------")
	
	'Read all files in folder into object
	Set objFSO = CreateObject("Scripting.FileSystemObject") 
	Session.Output(Now & " Folder: " & strMainFolder)
	Set objFolder = objFSO.GetFolder(strMainFolder)
	Set objFiles = objFolder.Files

end sub

function getPackageFromList(lst, pckName)
	if lst.Contains(pckName) then 
		dim keyIndex
		keyIndex = lst.IndexofKey(pckName)
		dim guid
		guid = lst.GetByIndex(keyIndex)
		set getPackageFromList = Repository.GetPackageByGuid(guid)
	else
		Session.Output(Now & " " & pckName & " not found")
		set getPackageFromList = Nothing
	end if 
end function

function getElementFromList(lst, elName)
	if lst.Contains(elName) then 
		dim keyIndex
		keyIndex = lst.IndexofKey(elName)
		dim guid
		guid = lst.GetByIndex(keyIndex)
		set getElementFromList = Repository.GetElementByGuid(guid)
	else
		'Session.Output(Now & " " & elName & " not found")
		set getElementFromList = Nothing
	end if 
end function

Sub hideAttributes(eDobj)
	'Hide attributes for a diagramobject
	Dim strDOS
	strDOS = eDobj.Style
	If InStr(strDOS, "AttPub=1") > 0 Then
		eDobj.Style = Replace(strDOS, "AttPub=1", "AttPub=0")
	ElseIf InStr(strDOS, "AttPub=0") = 0 Then
		eDobj.Style = strDOS & "AttPub=0;"
	End If
	eDobj.Update()
End Sub

Sub setSize(eDobj, h, w)
	'Set size for diagram objects
	eDobj.bottom = eDobj.top - h
	eDobj.right = eDobj.left + w
	eDobj.Update()
End Sub