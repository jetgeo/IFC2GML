option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Types to datatypes
' Author: Knut Jetlund
' Purpose: Import TYPES from IFC EXPRESS Schema files
' Date: 20190904
'

sub types2datatypes

	intitiateFilesAndLists()
	dim lstIFCSubtypes
	Set lstIFCSubtypes = CreateObject("System.Collections.SortedList")
	
	dim exists	
	'Read all types in each EXPRESS file and add to schema package
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			Set objTextFile = objFSO.OpenTextFile(strMainFolder & "\" & objFile.Name,1)
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			Session.Output(Now & " Types in schema: " & strPackageName)
			set thePackage = getPackageFromList(lstPck, strPackageName)

			If thePackage is nothing then 
				Session.Output(Now & " Package not found: " & strPackageName)
				exit sub
			end if
			
			exists = false
			
			'Type diagram
			set eDiagram = nothing
			For each eD in thePackage.Diagrams
				if eD.Name = thePackage.Name & " Types" then 
					set eDiagram = eD
				end if	
			Next
			if eDiagram is nothing then 
				Session.Output(Now & " Create type diagram")
				set eDiagram = thePackage.Diagrams.AddNew(thePackage.Name & " Types","Class")
				eDiagram.Update
			end if		
			
			'Add existing types to list
			'For each el in thePackage.Elements
			'	Session.Output(Now & " Adding " & el.Stereotype & " to list: " & el.Name)
			'	lstTypes.Add el.Name,el.ElementGUID
			'Next
			Session.Output(Now & " -----------------------------------------------------------------")
			
			'Make sure types exsists
			Do Until objTextFile.AtEndOfStream 
				strNextLine = objTextFile.Readline 
				If left(strNextLine, 5) = "TYPE " then
					dim strName, strDef
					strDef = mid(strNextLine, 6)
					'Create complete defintion string
					Do until right(strNextLine,9) = "END_TYPE;" or objTextFile.AtEndOfStream 
						strNextLine = LTrim(objTextFile.Readline)
						strDef = strDef & strNextLine
					Loop	

					Session.Output(Now & " Express Type definition: " & strDef)
					strName = left(strDef,instr(strDef, " ")-1)
					Session.Output(Now & " Express Type name: " & strName)
					
					dim strType, ifcSubType
					strType = ""
					ifcSubType = false
					if instr(strDef, "ENUMERATION") > 0 then 
						strType = "enumeration"
					elseif instr(strDef, " SELECT") > 0 then 
						strType = "Union"
					elseif instr(strDef, " SET [") >0 or instr(strDef, " LIST [") > 0 or instr(strDef, " ARRAY [") > 0 or _
						instr(strDef, " REAL") > 0 or instr(strDef, " INTEGER") > 0 or instr(strDef, " NUMBER") > 0 or instr(strDef, " STRING") > 0 or _
						instr(strDef, " BINARY") > 0 or instr(strDef, " BOOLEAN") > 0 or instr(strDef, " LOGICAL") > 0 then
						strType = "DataType"
					elseif instr(strDef, "= Ifc") then
						strType = "DataType"
						ifcSubType = true
					else
						Session.Output(Now & " Unsupported Express Type : " & strDef)
						strType = "Unsupported"
					end if

					'Set element
					if strType <> "Unsupported" then
						set el = getElementFromList(lstClasses, strName)
						if el is nothing then 
							Session.Output(Now & " Create " & strType & ": " & strName)
							set el = thePackage.Elements.AddNew(strName,"Class")	
							el.Update 
							Session.Output(Now & " Adding  " & strType & " to list: " & el.Name)
							lstClasses.Add el.Name,el.ElementGUID	
						end if			
						el.Type = "Class"
						el.StereoTypeEx = ""
						if strType = "enumeration" then 
							el.Type = "Enumeration"
						else
							el.StereotypeEX = "GML::" & strType
						end if	
						el.Update					
						addElement2Diagram	
						'Remove all existing values
						dim i 
						for i = 0 to el.Attributes.Count - 1
							el.Attributes.DeleteAt i, False
						next
						el.Attributes.Refresh						
					end if	

					'Datatypes 
					if strType = "DataType" then
						dim startPos, colonPos, endPos
						'Define ISO 19103 datatypes realization
						dim pDT as EA.Element
						set pDT = Nothing
						if instr(strDef, " REAL") > 0 then
							set pDT = Repository.GetElementByGuid(dtRealGUID)
						elseif instr(strDef, " INTEGER") > 0 then
							set pDT = Repository.GetElementByGuid(dtIntegerGUID)
						elseif instr(strDef, " NUMBER") > 0 then
							set pDT = Repository.GetElementByGuid(dtNumberGUID)
						elseif instr(strDef, " STRING") > 0 then
							set pDT = Repository.GetElementByGuid(dtCharacterStringGUID)
						elseif instr(strDef, " BOOLEAN") > 0 then
							set pDT = Repository.GetElementByGuid(dtBooleanGUID)
						elseif instr(strDef, " LOGICAL") > 0 then
							set pDT = Repository.GetElementByGuid(dtLogicalGUID)
						end if 
						
						if not pDT is nothing then
							Session.Output(Now & " Adding realization from ISO 19103 " & pDT.Name)
							set con = el.Connectors.AddNew("", "Realization")
							con.ClientID = el.ElementID
							con.SupplierID = pDT.ElementID
							con.Update()
						end if

						'Identify IFC supertypes of datatypes
						if ifcSubType = true then
							'Extract from strDef
							dim ifcSuperType
							ifcSuperType=""
							startPos = instr (strDef, "= Ifc")  + 2
							endPos = instr(startPos, strDef, ";")
							if endPos > 0 then
								ifcSuperType = mid(strDef,startPos,endPos-startPos)
							else
								ifcSuperType = mid(strDef,startPos)
							end if	
							Session.Output(Now & " Subtype of " & ifcSuperType)	
							lstIFCSubtypes.Add el.ElementGUID, ifcSuperType
						end if
												
						'Define collection attribute names
						dim strAttrName
						strAttrName = ""
						if instr(strDef, " SET [") > 0 then 
							strAttrName = "component"
							'Add tagged value aggregationType = SET
						elseif instr(strDef, " LIST [") > 0 then 
							strAttrName = "component"
							'Add tagged value aggregationType = LIST
						elseif instr(strDef, " ARRAY [") > 0 then 
							strAttrName = "component"
							'Add tagged value aggregationType = ARRAY
							'Add tagged value lowerBound = ....
						end if
						
						'Define content for collections
						if instr(strDef, " SET [") >0 or instr(strDef, " LIST [") > 0 or instr(strDef, " ARRAY [") > 0 then
							'Extract type
							startPos = instr(strDef, " OF ") + 4
							endPos = instr(startPos, strDef, ";")
							dim attrType 
							if endPos > 0 then
								attrType = mid(strDef,startPos,endPos-startPos)
							else
								attrType = mid(strDef,startPos)
							end if	
							
							'Extract cardinality
							startPos = instr(strDef, "[") + 1
							colonPos = instr(startPos, strDef,":")
							endPos = instr(colonPos, strDef,"]") - 1 
							dim minCard
							minCard	= mid(strDef,startPos,colonPos-startPos)
							dim maxCard
							maxCard = mid(strDef, colonPos+1, endPos-colonPos)
							if maxCard = "?" then maxCard="*"
							
							'Add attribute 
							Session.Output(Now & " Attribute in " & strType & ": " & strAttrName & ":" & attrType & " [" & minCard & ".." & maxCard & "]")	
							set elAttr = el.Attributes.AddNew(strAttrName,attrType)
							elAttr.Visibility = "Public"
							elAttr.LowerBound = minCard
							elAttr.UpperBound = maxCard
							'Ordered if LIST or ARRAY
							if instr(strDef, " LIST [") > 0 or instr(strDef, " ARRAY [") > 0 then elAttr.isOrdered = true
							
							elAttr.Update
						end if
					end if
					
					'Define content for enumerations and unions					
					if strType = "enumeration" then 
						'Cleanup string
						strDef = LTrim(Replace(strDef,strName,""))
						strDef = LTrim(Replace(strDef,"ENUMERATION OF",""))
					elseif strType = "Union" then 
						'Cleanup string
						strDef = LTrim(Replace(strDef,strName & " = SELECT",""))
						strDef = LTrim(Replace(strDef,"SELECT",""))
					end if
		
					if strType = "enumeration" or strType = "Union" then 	
						strDef = LTrim(Replace(strDef,"=",""))
						strDef = LTrim(Replace(strDef,"(",""))
						strDef = LTrim(Replace(strDef,")",""))
						strDef = LTrim(Replace(strDef,";",""))
						strDef = LTrim(Replace(strDef,"END_TYPE",""))
						strDef = LTrim(Replace(strDef,"=",""))
						strDef = TrimTabs(strDef)
						Session.Output(Now & " Express " & strType & " values: " & strDef)
						
						'Create list of values
						dim valList			
						valList=Split(strDef,",")
						'Add all values
						for each strName in valList
							strName = TrimTabs(strName)
							Session.Output(Now & " Value in " & strType & ": " & strName)	
							set elAttr = el.Attributes.AddNew(strName,"")
							elAttr.Visibility = "Public"
							elAttr.Update
						next
					end if
					
				end if	
			Loop
			
			eDiagram.DiagramObjects.Refresh
			ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
			repository.CloseDiagram(eDiagram.DiagramID)
			Session.Output(Now & " -----------------------------------------------------------------")
		end if
	Next
	
	'Loop through subtype list and add generalizations
	For i = 0 To lstIFCSubtypes.Count - 1
		Session.Output(Now & " Adding subtyping of " & lstIFCSubtypes.GetKey(i) & " from " & vbTab & lstIFCSubtypes.GetByIndex(i))
		set el = Repository.GetElementByGuid(lstIFCSubtypes.GetKey(i))
		set relEl = getElementFromList(lstClasses, lstIFCSubtypes.GetByIndex(i))
		'add generalization
		set con = el.Connectors.AddNew("", "Generalization")
		con.ClientID = el.ElementID
		con.SupplierID = RelEl.ElementID
		con.Update()
	Next 
	
	Session.Output(Now & " Done.")

end sub

types2datatypes