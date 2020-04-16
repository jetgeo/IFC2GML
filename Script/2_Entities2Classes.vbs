option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Entities to classes 
' Author: Knut Jetlund
' Purpose: Import Entities from IFC EXPRESS Schema files
' Date: 20190830
'

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

sub entities2Classes

	'Intitiate file ovbject and fill lists with existing packages and elements
	intitiateFilesAndLists()
	
	dim exists
	dim stList			
	
	'Read all entities in each EXPRESS file and add to schema package
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			Set objTextFile = objFSO.OpenTextFile(strMainFolder & "\" & objFile.Name,1)
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			Repository.WriteOutput "Script", Now & " Entities in schema: " & strPackageName,0
			
			packageAndDiagram()	
			dim strName
			
			'Make sure enities exsists
			Do Until objTextFile.AtEndOfStream 
				strNextLine = objTextFile.Readline 
				If left(strNextLine, 6) = "ENTITY" then
					strName = mid(strNextLine, 8)
					strName = LTrim(Replace(strName,";",""))
					if right(strName,1)=";" then strName=left(strName, len(strName)-1)
					Repository.WriteOutput "Script", Now & " Express Entity: " & strName,0
					set el = getElementFromList(lstClasses, strName)
					if el is nothing then 
						Repository.WriteOutput "Script", Now & " Create class: " & strName,0
						set el = thePackage.Elements.AddNew(strName,"Class")
						el.update 
						Repository.WriteOutput "Script", Now & " Adding class to list: " & el.Name,0
						lstClasses.Add el.Name,el.ElementGUID
					end if
					el.StereoTypeEx = ""
					el.StereoType = "FeatureType"
					'Read next line
					strNextLine = LTrim(objTextFile.Readline)
					If left(strNextLine, 8) = "ABSTRACT" then el.Abstract = "1"
					el.update
					
					exists = false
					for each eDO in eDiagram.DiagramObjects
						if eDO.ElementID = el.ElementID then
							set eDiagramObject = eDO
							exists = true
						end if
					next
					if exists = false then 
						set eDiagramObject = eDiagram.DiagramObjects.AddNew("","")
						eDiagramObject.ElementID = el.ElementID
					end if
					eDiagramObject.ShowConstraints = true
					eDiagramObject.ElementDisplayMode = 1
					eDiagramObject.update
				end if	
			Loop
			
			eDiagram.DiagramObjects.Refresh
			Session.Output(Now & " -----------------------------------------------------------------")
		end if
	Next
	
	'Second loop trough all files to identify generalizations and attributes
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			Set objTextFile = objFSO.OpenTextFile(strMainFolder & "\" & objFile.Name,1)
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			Repository.WriteOutput "Script", Now & " Generalization of entities in schema: " & strPackageName,0

			packageAndDiagram		

			Do Until objTextFile.AtEndOfStream 
				strNextLine = objTextFile.Readline 
				If left(strNextLine, 6) = "ENTITY" then

					strName = mid(strNextLine, 8)
					strName= LTrim(Replace(strName,";",""))
					Repository.WriteOutput "Script", Now & " Express Entity: " & strName,0
					set el = getElementFromList(lstClasses, strName)
					if el is nothing then 
						Repository.WriteOutput "Script", Now & " Feature type not found: " & strName,0
						exit sub
					end if	
					
					'Check for supertype definitions in second line 
					strNextLine = LTrim(TrimTabs(objTextFile.Readline))
					If left(strNextLine, 21) = "ABSTRACT SUPERTYPE OF" or left(strNextLine, 12) = "SUPERTYPE OF" then
						'Read subsequent lines until ";"
						dim strSubtypes
						strSubtypes = strNextLine
						Do until right(strNextLine,1) = ")" or right(strNextLine,2) = ");" or objTextFile.AtEndOfStream 
							strNextLine = LTrim(objTextFile.Readline)
							strSubtypes = strSubtypes & strNextLine
						Loop	

						'Cleanup string
						strSubtypes = LTrim(Replace(strSubtypes,"ABSTRACT SUPERTYPE OF",""))
						strSubtypes = LTrim(Replace(strSubtypes,"SUPERTYPE OF",""))
						strSubtypes = LTrim(Replace(strSubtypes,"(ONEOF",""))
						strSubtypes = LTrim(Replace(strSubtypes,"(",""))
						strSubtypes = LTrim(Replace(strSubtypes,"))",""))
						strSubtypes = LTrim(Replace(strSubtypes,")",""))
						strSubtypes = LTrim(Replace(strSubtypes,";",""))
								
						stList=Split(strSubtypes,",")
						for each strName in stList
							Repository.WriteOutput "Script", Now & " Supertype of: " & strName,0
							set relEl = getElementFromList(lstClasses, strName)
							if relEl is nothing then 
								Session.Output(Now & " Subtype not found: " & strName)
								'exit sub
							else
								'Add or update generalization
								set con = Nothing
								dim tmpCon as EA.Connector
								For each tmpCon in el.Connectors
									if tmpCon.Type = "Generalization" and tmpCon.ClientID=relEl.ElementID then
										set con = tmpCon
									end if
								next
								If con is nothing then
									'Add connector
									Repository.WriteOutput "Script", Now & " Adding generalization from " & strName,0
									set con = el.Connectors.AddNew("", "Generalization")
									con.ClientID = relEl.ElementID
									con.SupplierID = el.ElementID
									con.Update()
								end if	
							end if
						next
						strNextLine = LTrim(TrimTabs(objTextFile.Readline))
					end if
					el.update
					
					'Remove all existing attributes, associations (not generalizations) and constraints
					dim i 
					for i = 0 to el.Attributes.Count - 1
						el.Attributes.DeleteAt i, False
					next
					el.Attributes.Refresh						
					for i = 0 to el.Constraints.Count - 1
						el.Constraints.DeleteAt i, False
					next
					el.Constraints.Refresh						
					for i = 0 to el.Connectors.Count -1
						set con = el.Connectors.GetAt(i)
						if not con.Type = "Generalization" and not con.Type = "Realization" then el.Connectors.DeleteAt i, False
					next
					
					
					dim AttrName, dtName, attrDefList, derived, deriveRule
					derived = false
					
					'Check for attribute definitions in subsequent lines
					Do until Left(strNextLine,10) ="END_ENTITY" or objTextFile.AtEndOfStream 
						If Left(strNextLine,10) ="SUBTYPE OF" then strNextLine = LTrim(TrimTabs(objTextFile.Readline))
						
						'UNIQUE
						If Left(strNextLine,6) = "UNIQUE" then
							'NB! Handle as constraint instead!
						
							'Attributes following this keyword are defined as unique. They are defined earlier and updated to unique
							strNextLine = LTrim(TrimTabs(objTextFile.Readline))
							Do until Left(strNextLine,5) ="WHERE" or Left(strNextLine,6) = "DERIVE" or Left(strNextLine,7) ="INVERSE" or Left(strNextLine,10) ="END_ENTITY" or objTextFile.AtEndOfStream 
								stList=Split(strNextLine," ")
								If Ubound(stList) > 0 then
									attrName = Trim(Replace(stList(Ubound(stList)),";",""))	
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
							strNextLine = LTrim(objTextFile.Readline)
							derived = true
						end if
												
						'WHERE
						If Left(strNextLine,5) ="WHERE" then
							derived = false
							dim whereRule
							whereRule = ""
							strNextLine = LTrim(objTextFile.Readline)
							Do until Left(strNextLine,6) ="UNIQUE" or Left(strNextLine,6) = "DERIVE" or Left(strNextLine,7) ="INVERSE" or Left(strNextLine,10) ="END_ENTITY" or objTextFile.AtEndOfStream 
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
								elConstraint.Notes = whereRule '"EXPRESS WHERE: " & vbCrLf & whereRule
								elConstraint.Status = "Approved"
								elConstraint.Update()
								Repository.WriteOutput "Script", Now & " Constraint: " & whereRule, 0
								strNextLine = LTrim(objTextFile.Readline)
							Loop
						end if
						
						if not Left(strNextLine,10) ="END_ENTITY" or objTextFile.AtEndOfStream then
							'Remove tabs
							strNextLine = TrimTabs(strNextLine)
							dim newAttr
							newAttr = true
							deriveRule = ""
							if derived then
								'Create one long line with complete attribute and derive definition (until ";")
								Do until Right(strNextLine,1) =";" or objTextFile.AtEndOfStream 
								'	Repository.WriteOutput "Specific", Now & " DERIVE attribute definition (" & thePackage.Name & "." & el.Name & "): " & strNextLine, 0
									strNextLine = strNextLine & LTrim(objTextFile.Readline)
								Loop
								deriveRule = strNextLine

								if Left(strNextLine, 5) = "SELF\" then
									'not a new attribute, only derivation rule for existing. Add as element constraint
									newAttr = false
									'Split on ":", to identify attribute name
									attrDefList = Split(strNextLine,":")
									If Ubound(attrDefList) > 0 then
										attrName = Mid(attrDefList(0),5)
										if instr(attrName,".") > 0 then attrname = Mid(attrName, instr(attrName,".") +1)
										attrName = Lcase(Left(attrName,1)) & Mid(attrName,2)
									else
										attrName = ""
									end if

								else
									'Split attribute defintion and derive rule (before and after ":"=)
									attrDefList = Split(strNextLine,":=")
									If Ubound(attrDefList) > 0 then
										strNextLine = Trim(TrimTabs(attrDefList(0)))
										'deriveRule = Trim(Replace(attrDefList(Ubound(attrDefList)),";",""))
									end if
								end if	
							end if
							
							if newAttr then
								attrDefList = Split(strNextLine," ")
								If Ubound(attrDefList) > 0 then
									attrName = Trim(TrimTabs(attrDefList(0)))
									attrName = Lcase(Left(attrName,1)) & Mid(attrName,2)
									dtName = Trim(Replace(attrDefList(Ubound(attrDefList)),";",""))
									
									'Extract cardinality
									dim subStr, startPos, colonPos, endPos
									dim minCard, maxCard
									dim ordered, opt
									minCard = "1"
									maxCard = "1"
									ordered = false
									opt = false
									For each subStr in attrDefList
										'Set Ordered if LIST or ARRAY
										if instr(subStr, "LIST") > 0 or instr(subStr, "ARRAY") > 0 then 
											ordered = true
											'Session.Output(Now & " Ordered")
										end if	

										if left(subStr,1) = "[" then									
											startPos = instr(subStr, "[") + 1
											colonPos = instr(startPos, subStr,":")
											endPos = instr(colonPos, subStr,"]") - 1 
											minCard	= mid(subStr,startPos,colonPos-startPos)
											maxCard = mid(subStr, colonPos+1, endPos-colonPos)
											if maxCard = "?" then maxCard="*"
										end if
										'Check for the keyword OPTIONAL
										if instr(subStr,"OPTIONAL") > 0 then
											opt = true
										end if
									Next
									
									if opt then minCard = 0
									'Add attribute 
									set elAttr = el.Attributes.AddNew(attrName,dtName)
									elAttr.Visibility = "Public"
									elAttr.LowerBound = minCard
									elAttr.UpperBound = maxCard
									elAttr.isOrdered = ordered
									elAttr.isDerived = derived
									elAttr.AllowDuplicates = true
									elAttr.Update
									el.Attributes.Refresh
									Repository.WriteOutput "Script", Now & " Attribute: " & attrName & ":" & dtName & " [" & minCard & ".." & maxCard & "]" & ", defintion: " & strNextLine, 0
									'if derived then deriveRule = "self." & attrName & "=" & deriveRule						
								end if
							end if
							
							'Add derive constraint
							if derived then
								set elConstraint = el.Constraints.AddNew("derive " & attrName, "EXPRESS_DERIVE")
								elConstraint.Notes = deriveRule '"EXPRESS DERIVE: " & vbCrLf & deriveRule
								elConstraint.Status = "Approved"
								elConstraint.Update()
								Repository.WriteOutput "Script", Now & " Constraint: " & deriveRule, 0
							end if
							
							strNextLine = LTrim(objTextFile.Readline)
						end if
					Loop
				end if	
			Loop
									
			ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
			repository.CloseDiagram(eDiagram.DiagramID)
			Session.Output(Now & " -----------------------------------------------------------------")
		end if
	next	
	
	Repository.WriteOutput "Script", Now & " Done.",0

end sub

entities2Classes