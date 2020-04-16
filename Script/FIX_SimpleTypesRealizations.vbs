option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Types to datatypes
' Author: Knut Jetlund
' Purpose: Fix realizations from ISO 19103 Simple types
' Date: 20200103
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
							Session.Output(Now & " Missing type " & strType & ": " & strName)
							'set el = thePackage.Elements.AddNew(strName,"Class")	
							'el.Update 
							'Session.Output(Now & " Adding  " & strType & " to list: " & el.Name)
							'lstClasses.Add el.Name,el.ElementGUID	
						end if			
						'el.Type = "Class"
						'el.StereoTypeEx = ""
						'if strType = "enumeration" then 
						'	el.Type = "Enumeration"
						'else
						'	el.StereotypeEX = "GML::" & strType
						'end if	
						'el.Update					
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

					end if
				end if	
			Loop
		end if
	Next
	
	Session.Output(Now & " Done.")

end sub

types2datatypes