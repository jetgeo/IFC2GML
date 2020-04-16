option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Fix type constraints
' Author: Knut Jetlund
' Purpose: Fix Constraints on types
' Date: 20191018
'

sub fixTypeConstraints

	intitiateFilesAndLists()
	dim lstIFCSubtypes
	Set lstIFCSubtypes = CreateObject("System.Collections.SortedList")
	
	dim exists	
	'Read and handle all types in each EXPRESS file 
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			Set objTextFile = objFSO.OpenTextFile(strMainFolder & "\" & objFile.Name,1)
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			Repository.WriteOutput "Script", Now & " Types in schema: " & strPackageName,0
			set thePackage = getPackageFromList(lstPck, strPackageName)

			If  thePackage is nothing then 
				Repository.WriteOutput "Script", Now & " Package not found: " & strPackageName,0
				exit sub
			end if
			
			exists = false
			
			Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------",0
			
			'Find type element
			Do Until objTextFile.AtEndOfStream 
				strNextLine = objTextFile.Readline 
				If left(strNextLine, 5) = "TYPE " then
					dim strName, strDef, attrDefList, attrName, derive
					attrDefList = Split(strNextLine," ")
					strName = Trim(TrimTabs(attrDefList(1)))
					Repository.WriteOutput "Script", Now & " Express Type name: " & strName,0
					
					'Set element
					set el = getElementFromList(lstClasses, strName)
					if el is nothing then 
						Repository.WriteOutput "Error", Now & " Datatype not found :" & strName,0
					else
						Repository.WriteOutput "Specific", Now & " Datatype element :" & el.Name,0
						dim i
						for i = 0 to el.Constraints.Count - 1
							el.Constraints.DeleteAt i, False
						next
					
						Do until Left(strNextLine,9) = "END_TYPE;" or objTextFile.AtEndOfStream 
							strNextLine = LTrim(TrimTabs(objTextFile.Readline))

							'UNIQUE, INVERSE, DERIVE: Not used for types?
							'UNIQUE
							If Left(strNextLine,6) = "UNIQUE" then
								'Attributes following this keyword are defined as unique. They are defined earlier and updated to unique
								strNextLine = LTrim(TrimTabs(objTextFile.Readline))
								Do until Left(strNextLine,5) ="WHERE" or Left(strNextLine,6) = "DERIVE" or Left(strNextLine,7) ="INVERSE" or Left(strNextLine,8) ="END_TYPE" or objTextFile.AtEndOfStream 
									attrDefList=Split(strNextLine," ")
									If Ubound(stList) > 0 then
										attrName = Trim(Replace(attrDefList(Ubound(attrDefList)),";",""))	
										attrName = Lcase(Left(attrName,1)) & Mid(attrName,2)
										Repository.WriteOutput "Script", Now & " UNIQUE attribute: " & attrName,0
										For each elAttr in el.Attributes
											if elAttr.Name = attrName then
												'Session.Output(Now & " UNIQUE attribute found: " & attrName)
												elAttr.AllowDuplicates = false
												elAttr.Update
											end if
										next
									end if
									strNextLine = LTrim(TrimTabs(objTextFile.Readline))						
								Loop
							end if
							
							'INVERSE
							If Left(strNextLine,7) ="INVERSE" then
								Repository.WriteOutput "Specific", Now &" INVERSE " & thePackage.Name & "." & el.Name,0
								derived = false
								strNextLine = LTrim(objTextFile.Readline)
								Do until Left(strNextLine,5) ="WHERE" or Left(strNextLine,6) = "DERIVE" or Left(strNextLine,6) ="UNIQUE" or Left(strNextLine,10) ="END_ENTITY" or objTextFile.AtEndOfStream 
									Repository.WriteOutput "Specific", Now &" INVERSE " & strNextLine,0
									strNextLine = LTrim(objTextFile.Readline)
								Loop
							end if
							
							'DERIVE
							If Left(strNextLine,6) = "DERIVE" then
								'Attributes following this keyword are set as derived
								Repository.WriteOutput "Specific", Now &" DERIVE " & strNextLine,0
								strNextLine = LTrim(objTextFile.Readline)
								derived = true
							end if

							'WHERE
							If Left(strNextLine,5) ="WHERE" then
								dim whereRule
								whereRule = ""
								strNextLine = LTrim(objTextFile.Readline)
								Do until Left(strNextLine,6) ="UNIQUE" or Left(strNextLine,6) = "DERIVE" or Left(strNextLine,7) ="INVERSE" or Left(strNextLine,8) ="END_TYPE" or objTextFile.AtEndOfStream 
									'Create one long line with complete definition (until ";")
									Do until Right(strNextLine,1) =";" or objTextFile.AtEndOfStream 
										strNextLine = strNextLine & LTrim(objTextFile.Readline)
									loop	
									whereRule = TrimTabs(strNextLine)
									'Repository.WriteOutput "Specific", Now & " WHERE " & whereRule,0
									attrDefList = Split(whereRule,":")
									attrName = ""
									If Ubound(attrDefList) > 0 then attrName = Trim(attrDefList(0))
									'Create constraint
									set elConstraint = el.Constraints.AddNew("where " & attrName, "EXPRESS_WHERE")
									elConstraint.Notes = whereRule 
									elConstraint.Status = "Approved"
									elConstraint.Update()
									Repository.WriteOutput "Script", Now & " Constraint: " & whereRule, 0
									strNextLine = LTrim(objTextFile.Readline)
								Loop
							end if
						Loop	
						Repository.WriteOutput "Script", Now & " -----------------------------------------------------------------",0
					End if
				end if		
	
			Loop
		end if
	Next
	
Repository.WriteOutput "Script", Now & " Done",0	

end sub

fixTypeConstraints