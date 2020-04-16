option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Functions2Interfaces 
' Author: Knut Jetlund
' Purpose: Import Functions and Rules from IFC EXPRESS Schema files
' Date: 20191024
'
sub functions2Interfaces

	'Intitiate file ovbject and fill lists with existing packages and elements
	outputTabs
	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0
	
	dim layerPackage as EA.Package

	'Create list of package and element ids and GUIDs
	Set lstPck = CreateObject("System.Collections.SortedList")
	Repository.WriteOutput "Script", Now & " Create list of existing packages and elements",0
	For each layerPackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " Adding package to list: " & layerPackage.Name & "(" & layerPackage.Element.ElementID & ")", 0
		'Add packages to lists
		'lstPck.Add layerPackage.Element.ElementID,layerPackage.packageGUID
		For each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " Adding package to list: " & thePackage.Name & "(" & thePackage.Element.ElementID & ")", 0
			'Add packages to lists
			lstPck.Add thePackage.Name,thePackage.packageGUID
			dim i 
			for i = 0 to thePackage.Elements.Count -1
				set el = thePackage.Elements.GetAt(i)
				if el.type = "Interface" then
					thePackage.Elements.DeleteAt i, False
				end if	
			next
		Next
	Next

	'Read all files in folder into object
	Repository.WriteOutput "Script", Now & " Connect to folder with EXPRESS files",0
	Set objFSO = CreateObject("Scripting.FileSystemObject") 
	Session.Output(Now & " Folder: " & strMainFolder)
	Set objFolder = objFSO.GetFolder(strMainFolder)
	Set objFiles = objFolder.Files
	
	Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------",0
	
	dim strList, strName
	dim e as EA.Element
	dim fIExists, rIExists
	'Read all functions and rules in each EXPRESS file and add to schema package
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			Set objTextFile = objFSO.OpenTextFile(strMainFolder & "\" & objFile.Name,1)
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			set thePackage = getPackageFromList(lstPck, strPackageName)
			If thePackage is nothing then
				Repository.WriteOutput "Error", Now & " Package not found: " & strPackageName,0
			else
				fIExists = false
				rIExists = false
				Repository.WriteOutput "Script", Now & " Functions and rules in schema: " & strPackageName,0
				'Process functions and rules
				Do Until objTextFile.AtEndOfStream 
					strNextLine = objTextFile.Readline 
					If left(strNextLine, 8) = "FUNCTION" or left(strNextLine, 4) = "RULE" then
						dim fType
						If left(strNextLine, 8) = "FUNCTION" then
							fType = "Function"
						else
							fType = "Rule"
						end if
						if (FType = "Function" and not fIExists) or (fType = "Rule" and not rIExists) then
							set el = nothing
							For each e in thePackage.Elements
								If e.Name=thePackage.name & fType & "s" then set el=e
							Next
							If el is nothing then
								Repository.WriteOutput "Script", Now & " Create " & fType & " interface: " & thePackage.name & fType &"s",0
								set el = thePackage.Elements.AddNew(thePackage.name & fType & "s","Interface")					
								el.update 
							end if	
							if fType = "Function" then fIExists = true
							if fType = "Rule" then rIExists = true
						end if								
						strList = Split(strNextLine," ")
						strName = strList(1)
						strName = Lcase(Left(strList(1),1)) & Mid(strList(1),2)
						Repository.WriteOutput "Script", Now & " Add " & fType & " as operation: " & strName,0
						set elOperation = el.Methods.AddNew(strName,"")
						elOperation.update
						dim strCode 
						strCode = strNextLine
						Do until strNextLine = "END_FUNCTION;" or strNextLine = "END_RULE;"
							strNextLine = objTextFile.Readline
							strCode = strCode & vbCrLf & strNextLine						
							'Repository.WriteOutput "Script", Now & " " & strNextLine,0
						Loop
						elOperation.Code = strCode
						'elOperation.Notes = strCode
						elOperation.update
					end if	
				Loop

			end if

			Session.Output(Now & " -----------------------------------------------------------------")
		end if
	Next
	Repository.WriteOutput "Script", Now & " Done.",0


end sub

functions2Interfaces