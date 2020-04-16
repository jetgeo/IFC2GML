option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: INverse relations 
' Author: Knut Jetlund
' Purpose: Handle INVERSE declarations from IFC EXPRESS Schema files
' Date: 201908918
'

sub inverseRelations

	'Intitiate file ovbject and fill lists with existing packages and elements
	intitiateFilesAndLists()
	'outputTabs
	'set rootPackage = Repository.GetTreeSelectedObject()
	'Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0
	
	dim exists
	dim stList			
	dim strName
	
	'Loop trough all files to identify INVERSE declarations
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			Set objTextFile = objFSO.OpenTextFile(strMainFolder & "\" & objFile.Name,1)
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			Repository.WriteOutput "Script", Now & " Schema: " & strPackageName,0

			packageAndDiagram		

			Do Until objTextFile.AtEndOfStream 
				strNextLine = TrimTabs(objTextFile.Readline)
				If left(strNextLine, 6) = "ENTITY" then

					strName = mid(strNextLine, 8)
					strName= LTrim(Replace(strName,";",""))
					Repository.WriteOutput "Script", Now & " Express Entity: " & strName,0
					set el = getElementFromList(lstClasses, strName)
					if el is nothing then 
						Repository.WriteOutput "Script", Now & " Feature type not found: " & strName,0
						exit sub
					end if	
					
					'Delete all existing INVERSE Constraints
					dim i
					for i = 0 to el.Constraints.Count - 1
						set elConstraint = el.Constraints.GetAt(i)
						if instr(elConstraint.Notes,"EXPRESS INVERSE") > 0 then 
							Repository.WriteOutput "Specific", Now &" Delete INVERSE constraint: " & thePackage.Name & "." & el.Name & "." & elConstraint.Name,0
							el.Constraints.DeleteAt i, False
						end if
					next
					el.Constraints.Refresh						


					dim roleName, dtName, attrDefList,subStr
					
					'Check for attribute definitions in subsequent lines
					Do until Left(strNextLine,10) ="END_ENTITY" or objTextFile.AtEndOfStream 
						strNextLine = TrimTabs(objTextFile.Readline)
					
						'INVERSE
						If Left(strNextLine,7) ="INVERSE" then
							Repository.WriteOutput "Script", Now &" INVERSE " & thePackage.Name & "." & el.Name,0
							strNextLine = TrimTabs(objTextFile.Readline)
							Do until Left(strNextLine,5) ="WHERE" or Left(strNextLine,6) = "DERIVE" or Left(strNextLine,6) ="UNIQUE" or Left(strNextLine,10) ="END_ENTITY" or objTextFile.AtEndOfStream 
								'Repository.WriteOutput "Specific", Now &" INVERSE " & strNextLine,0
								
								'Decode INVERSE statement
								attrDefList = Split(strNextLine," ")
								If Ubound(attrDefList) > 0 then 
									roleName = Trim(attrDefList(0))
									roleName = Lcase(Left(roleName,1)) & Mid(roleName,2)

									dim startPos, colonPos, endPos
									dim minCard, maxCard
									For each subStr in attrDefList
										'cardinality
										if left(subStr, 1) = "[" then
											'Extract cardinality
											minCard = "1"
											maxCard = "1"
											startPos = instr(subStr, "[") + 1
											colonPos = instr(startPos, subStr,":")
											endPos = instr(colonPos, subStr,"]") - 1 
											minCard	= mid(subStr,startPos,colonPos-startPos)
											maxCard = mid(subStr, colonPos+1, endPos-colonPos)
											if maxCard = "?" then maxCard="*"
										end if
									Next
									dtName = Trim(attrDefList(Ubound(attrDefList)-2))
									dim relRoleName
									relRoleName = Trim(Replace(attrDefList(Ubound(attrDefList)),";",""))
									relRoleName = Lcase(Left(relRoleName,1)) & Mid(relRoleName,2)
									'Repository.WriteOutput "Specific", Now &" INVERSE - own role " & el.Name & "." & roleName & " [" & minCard & ".." & maxCard & "], external role " & dtName & "." & relRoleName ,0
									
									set relEl = getElementFromList(lstClasses, dtName)
									if not relEl is nothing then
										'Repository.WriteOutput "Specific", Now &" INVERSE - Related element found:" & relEl.name & "(" & relEl.ElementID & ")",0

										set con = Nothing
										dim tmpCon as EA.Connector
										dim found
										found = false
										For each tmpCon in el.Connectors
											'Repository.WriteOutput "Specific", Now &" INVERSE - Connector - Client: " & tmpCon.ClientID & " Supplier: " & tmpCon.SupplierID & " rolename: " & tmpCon.SupplierEnd.Role,0
											if tmpCon.ClientID = relEl.ElementID and tmpCon.SupplierID = el.ElementID and tmpCon.SupplierEnd.Role = relRoleName then
												Repository.WriteOutput "Script", Now &" INVERSE - Updating connector - Client: " & relEl.Name & "." & roleName & " Supplier: " & el.Name & "." & tmpCon.SupplierEnd.Role,0
												found = true
												set con = tmpCon
												'Set local role name and multiplicity
												con.ClientEnd.Role = roleName
												con.ClientEnd.Cardinality = minCard & ".." & maxCard	
												con.Update	
											end if
												
										next
										'Add constraint
										set elConstraint = el.Constraints.AddNew("inverse " & roleName, "EXPRESS_INVERSE")
										elConstraint.Notes = strNextLine '"EXPRESS INVERSE: " & vbCrLf & strNextLine
										elConstraint.Status = "Approved"
										elConstraint.Update()
										Repository.WriteOutput "Script", Now & " EXPRESS_INVERSE Constraint: " & strNextLine, 0
										if not found then Repository.WriteOutput "Error", Now &" INVERSE - Connector not found from " & relEl.name & " (rolename " & relRoleName & ") to " & el.Name,0			
									else
										Repository.WriteOutput "Error", Now &" INVERSE - Related element from " & el.Name & " not found:" & dtName,0
									end if

								end if
								strNextLine = TrimTabs(objTextFile.Readline)
							Loop
						end if
				
					Loop
				end if	
			Loop
									
		end if
	next	
	
	Repository.WriteOutput "Script", Now & " Done.",0

end sub

inverseRelations