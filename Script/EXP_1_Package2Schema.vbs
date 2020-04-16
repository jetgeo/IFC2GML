option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Package 2 Schema
' Author: Knut Jetlund
' Purpose: Export package to EXPRESS Schema
' Date: 20200102
'
const path = "C:\DATA\GitHub\jetgeo\IFC2UML\EXPRESS"

sub pck2Sch

	outputTabs
	
	set rootPackage = Repository.GetTreeSelectedObject()
	Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0

	'set rootPackage = Repository.GetTreeSelectedObject()
	'Repository.WriteOutput "Script", Now & " Root package: " & rootPackage.Name, 0

	Set objFSO=CreateObject("Scripting.FileSystemObject")
	'Create root schema file 
	dim rootFile
	Set rootFile = objFSO.CreateTextFile(path & "\" & rootPackage.Name & ".exp",True)	
	rootFile.Write "(* Exported from UML " & Now & " *)" & vbCrLf
	rootFile.Write " " & vbCrLf
	rootFile.Write "SCHEMA " & Ucase(rootPackage.Name) & ";" & vbCrLf
	rootFile.Write " " & vbCrLf

	dim lstMapRealizations
	Set lstMapRealizations = CreateObject("System.Collections.SortedList")
	
	'Loop for all packages
	Dim layerPackage as EA.Package
	dim layerFile
	
	Dim first, last

	For each layerPackage in rootPackage.Packages
		Repository.WriteOutput "Script", Now & " Layer Package: " & layerPackage.Name, 0
		rootFile.Write "REFERENCE (" & Ucase(layerPackage.Name) & ");" & vbCrLf

		Set layerFile = objFSO.CreateTextFile(path & "\" & layerPackage.Name & ".exp",True)	
		layerFile.Write "(* Exported from UML " & Now & " *)" & vbCrLf
		layerFile.Write " " & vbCrLf
		layerFile.Write "SCHEMA " & Ucase(layerPackage.Name) & ";" & vbCrLf
		layerFile.Write " " & vbCrLf

		Dim theFile
		
		For each thePackage in layerPackage.Packages
			Repository.WriteOutput "Script", Now & " Package: " & thePackage.Name, 0
			layerFile.Write "REFERENCE (" & Ucase(thePackage.Name) & ");" & vbCrLf

			Set theFile = objFSO.CreateTextFile(path & "\" & thePackage.Name & ".exp",True)	
			theFile.Write "(* Exported from UML " & Now & " *)" & vbCrLf
			theFile.Write " " & vbCrLf
			theFile.Write "SCHEMA " & Ucase(thePackage.Name) & ";" & vbCrLf
			'theFile.Write " " & vbCrLf
			'Loop for finding dependencies. Store in list and write to file

			Dim lstDepEl, lstDepP
			Set lstDepEl = CreateObject("System.Collections.SortedList")
			Set lstDepP = CreateObject("System.Collections.SortedList")
			dim strDep 
			dim keyIndex
			'Loop through all elements
			Repository.WriteOutput "Script", Now & " Finding property type dependencies" ,0
			For each el in thePackage.Elements
				'Loop through all attributes
				dim relEl as EA.Element
				dim relPck as EA.Package
				For each elAttr in el.Attributes
					if elAttr.ClassifierID <> 0 then
						set relEl = Repository.GetElementByID(elAttr.ClassifierID)
						if not lstDepEl.Contains(relEl.Name) and relEl.PackageID <> thePackage.PackageID then
							lstDepEl.Add relEl.Name,relEl.ElementGUID
							set relPck = Repository.GetPackageByID(relEl.PackageID)
							if not lstDepP.Contains(relPck.Name) then
								'create dependency string
								lstDepP.Add relPck.Name, relEl.Name
							else
								'modify dependency string
								keyIndex = lstDepP.IndexofKey(relPck.Name)
								strDep = lstDepP.GetByIndex(keyIndex) & ", " & relEl.Name
								lstDepP.SetByIndex keyIndex, strDep
							end if
							Repository.WriteOutput "Specific", strDep,0
						end if
					end if
				Next
				'Loop through all associations
				For each con in el.Connectors
					If (con.type = "Association" or con.type = "Generalization") and con.SupplierId <> el.ElementId then 
						set relEl = Repository.GetElementByID(con.SupplierId)
						if not lstDepEl.Contains(relEl.Name) and relEl.PackageID <> thePackage.PackageID then
							lstDepEl.Add relEl.Name,relEl.ElementGUID
							set relPck = Repository.GetPackageByID(relEl.PackageID)
							if not lstDepP.Contains(relPck.Name) then
								'create dependency string
								lstDepP.Add relPck.Name, relEl.Name
							else
								'modify dependency string
								keyIndex = lstDepP.IndexofKey(relPck.Name)
								strDep = lstDepP.GetByIndex(keyIndex) & ", " & relEl.Name
								lstDepP.SetByIndex keyIndex, strDep
							end if
							Repository.WriteOutput "Specific", strDep,0
						end if	
					end if
				Next
			Next
			
			'Loop through package dependency list and write reference declaration
			Repository.WriteOutput "Script", Now & " Writing property type dependencies" ,0
			For keyIndex = 0 to lstDepP.Count - 1
				theFile.Write " " & vbCrLf		
				theFile.Write "REFERENCE FROM " & Ucase(lstDepP.GetKey(keyIndex)) & vbCrLf 
				thefile.Write VBTab & "(" & lstDepP.GetByIndex(keyIndex) & ");" & vbCrLf
			Next	

			dim str 

			'DataType2TYPE
			Repository.WriteOutput "Script", Now & " Writing datatype TYPES" ,0
			For each el in thePackage.Elements
				if el.type = "Class" and el.Stereotype = "DataType" then
					theFile.Write " " & vbCrLf	
					'Find type of type
					str = "SOMETHING"
					
					For each con in el.Connectors
						If con.type = "Generalization" and con.SupplierId <> el.ElementId then 
							'Find supertype of datatype, for type reference
							set relEl = Repository.GetElementByID(con.SupplierId)
							Repository.WriteOutput "Script", Now & " " & el.Name & " is a subtype of " & relEl.Name ,0
							str = relEl.Name
						end if
						If (con.type = "Realisation" or con.type = "Realization") and con.ClientID = el.ElementId then
							'Find primitive type from realization
							set relEl = Repository.GetElementByID(con.SupplierId)
							Repository.WriteOutput "Script", Now & " " & el.Name & " is a realization of " & relEl.Name ,0
							Select case relEl.ElementGUID
								case dtRealGUID
									str = "REAL" 
								case dtIntegerGUID
									str= "INTEGER" 
								case dtNumberGUID
									str = "NUMBER" 
								case dtCharacterStringGUID
									str = "STRING" 
								case dtBooleanGUID
									str = "BOOLEAN" 
								case dtLogicalGUID
									str = "LOGICAL"
							end select
						end if
					Next
					if el.Name = "IfcBinary" then str = "BINARY"
					
					'Collections - type derived from property types
					'Identify collections by the tagged value "aggregationType"
					Dim tv as EA.TaggedValue
					Dim strMp
					strMp = ""
					For each tv in el.TaggedValues
						if tv.Name = "aggregationType" then
							For each elAttr in el.Attributes
								if elAttr.ClassifierID <> 0 then
									set relEl = Repository.GetElementByID(elAttr.ClassifierID)
									'Multiplicity
									if tv.Value = "LIST" or tv.Value = "SET" then
										if elAttr.UpperBound = "*" then
											strMP = "[" & elAttr.LowerBound & ":?]"
										else
											strMP = "[" & elAttr.LowerBound & ":" & elAttr.UpperBound & "]"
										end if
									elseif tv.Value = "ARRAY" then
										strMP = "[" & int(elAttr.LowerBound)-1 & ":" & elAttr.UpperBound & "]"								
									end if
									'aggregationType from tag
									str = tv.Value & " " & strMP & " OF " & relEl.Name
									str = Replace(str,"OF IfcReal","OF REAL")
									str = Replace(str,"OF IfcInteger","OF INTEGER")
								end if
							Next
							For each con in el.Connectors
								If con.type = "Association" and con.SupplierId <> el.ElementId then 
									set relEl = Repository.GetElementByID(con.SupplierId)
									'Multiplicity
									strMP = Replace(con.SupplierEnd.Cardinality,"*","?")
									strMP = Replace(strMP,"..",":")
									strMP = "[" & strMP & "]"
									'aggregationType from tag
									str = tv.Value & " " & strMP & " OF " & relEl.Name
									'Hardcoded replacement of IfcTypes... 
									str = Replace(str,"OF IfcReal","OF REAL")
									str = Replace(str,"OF IfcInteger","OF INTEGER")
								End if
							Next
							Repository.WriteOutput "Script", Now & " " & el.Name & " is an aggregation type " & str,0							
						end if
					Next
					
					theFile.Write "TYPE " & el.Name & " = " & str & ";" & vbCrLf	

					'Constraints
					first = true
					For each elConstraint in el.Constraints
						'WHERE - No DERIVE or UNIQUE for TYPEs?
						If elConstraint.Type = "EXPRESS_WHERE" then
							if first then 
								theFile.Write " WHERE" & vbCrLf
								first = false
							end if
							theFile.Write VBTab & replace(elConstraint.Notes,"&lt","<") & vbCrLf	
						end if						
					Next
					
					theFile.Write "END_TYPE; " & vbCrLf		
				end if
			Next
			
			'Union
			Repository.WriteOutput "Script", Now & " Writing union (SELECT) TYPES" ,0
			For each el in thePackage.Elements
				if el.type = "Class" and el.Stereotype = "Union" then
					theFile.Write " " & vbCrLf		
					theFile.Write "TYPE " & el.Name & " = SELECT" & vbCrLf	
					str = VBtab & "("
					For each elAttr in el.Attributes
						str = str & elAttr.Type & ", "
					Next
					str = Left(str, len(str)-2) & ");" & vbCrLf
					theFile.Write str
					theFile.Write "END_TYPE; " & vbCrLf		
				end if
			Next
		
			'Enumeration2TYPE
			Repository.WriteOutput "Script", Now & " Writing enumeration TYPES" ,0
			For each el in thePackage.Elements
				if el.type = "Enumeration" then
					theFile.Write " " & vbCrLf		
					theFile.Write "TYPE " & el.Name & " = ENUMERATION OF" & vbCrLf	
					str = VBtab & "("
					For each elAttr in el.Attributes
						'elAttr.Name = TrimTabs(elAttr.Name)
						'elAttr.Update
						str = str & elAttr.Name & ", "
					Next
					str = Left(str, len(str)-2) & ");" & vbCrLf
					theFile.Write str
					theFile.Write "END_TYPE; " & vbCrLf		
				end if
			Next
			
			'FeatureClass2ENTITY
			Repository.WriteOutput "Script", Now & " Writing entities (ENTITY)" ,0
			For each el in thePackage.Elements
				if el.type = "Class" and el.Stereotype = "FeatureType" then
					theFile.Write " " & vbCrLf	
					theFile.Write "ENTITY " & el.Name & vbCrLf	
					If el.Abstract = "1" then theFile.Write " ABSTRACT"
					'Find specializations (SUPERTYPE OF...)
					first = true
					For each con in el.Connectors			
						If con.type = "Generalization" and con.SupplierId = el.ElementId then 
							if first then
								theFile.Write " SUPERTYPE OF (ONEOF" & vbCrLf & vbTab & "("		
								first = false
							else
								theFile.Write ", "	
							end if	
							set relEl = Repository.GetElementByID(con.ClientID)
							theFile.Write relEl.Name
						end if
					Next
					If first = false then theFile.Write "));" & vbCrLf
					first = true
					
					'Find generalizations (SUBTYPE OF...)
					first = true
					For each con in el.Connectors			
						If con.type = "Generalization" and con.SupplierId <> el.ElementId then 
							if first then
								theFile.Write " SUBTYPE OF ("		
								first = false
							else
								theFile.Write ", "	
							end if	
							set relEl = Repository.GetElementByID(con.SupplierID)
							theFile.Write relEl.Name
						end if
					Next
					If first = false then theFile.Write ");" & vbCrLf
					first = true
					
					'Properties - Properties2Attribute
					For each elAttr in el.Attributes
						If not elAttr.IsDerived then
							theFile.Write VBTab & Ucase(Left(elAttr.Name,1)) & Mid(elAttr.Name,2) & " : " 
							if elAttr.LowerBound = 0 then theFile.Write "OPTIONAL "
							If elAttr.UpperBound <> "0" and elAttr.UpperBound <> "1" then 
								'Aggregate
								If elAttr.IsOrdered then
									'LIST or ARRAY
									str = "LIST [" & elAttr.LowerBound & ":" & elAttr.UpperBound
									For each attrTag in elAttr.TaggedValues
										If attrTag.Name = "aggregationType" and attrTag.Value = "ARRAY" then 
											str = "ARRAY [" & int(elAttr.LowerBound)-1 & ":" & elAttr.UpperBound 							
										end if	
									Next
								Else
									'SET
									str = "SET [" & elAttr.LowerBound & ":" & elAttr.UpperBound
								End if
								str = Replace(str,"*","?") & "] OF "
								theFile.Write str 
							end if
							theFile.Write elAttr.Type & ";" & vbCrLf
						end if
					Next
					For each con in el.Connectors
						If con.type = "Association" and con.SupplierId <> el.ElementId then 
							set relEl = Repository.GetElementByID(con.SupplierID)
							theFile.Write VBTab & Ucase(Left(con.SupplierEnd.Role,1)) & Mid(con.SupplierEnd.Role,2) & " : " 
							if Left(con.SupplierEnd.Cardinality,1)= "0" then theFile.Write "OPTIONAL "
							If Right(con.SupplierEnd.Cardinality,1) <> "0" and Right(con.SupplierEnd.Cardinality,1) <> "1" then 
								'Aggregate
								If con.SupplierEnd.Ordering = 1 then
									'LIST or ARRAY
									str = "LIST [" & replace(con.SupplierEnd.Cardinality,"..",":")
									For each conTag in con.TaggedValues
										If conTag.Name = "aggregationType" and conTag.Value = "ARRAY" then 
											str = "ARRAY [" & Cint(Left(con.SupplierEnd.Cardinality,1))-1 & ":" & Right(con.SupplierEnd.Cardinality,1)
										end if
									Next
								Else
									'SET
									str = "SET [" & replace(con.SupplierEnd.Cardinality,"..",":")
								End if
								str = replace(str,"*","?") & "] OF "
								theFile.Write str							
							end if	
							theFile.Write relEl.Name & ";" & vbCrLf						
						end if
					Next
					
					'Constraints
					
					theFile.Write "END_ENTITY; " & vbCrLf		
				end if
			Next	

			theFile.Write " " & vbCrLf
			theFile.Write "END_SCHEMA;" & vbCrLf
			theFile.Close
		Next	
		
		layerFile.Write " " & vbCrLf
		layerFile.Write "END_SCHEMA;" & vbCrLf
		layerFile.Close
	Next

	rootFile.Write " " & vbCrLf
	rootFile.Write "END_SCHEMA;" & vbCrLf
	rootFile.Close
	
	Repository.WriteOutput "Script", Now & " Done", 0

end sub

pck2Sch