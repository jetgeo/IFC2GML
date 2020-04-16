option explicit

!INC Local Scripts.EAConstants-VBScript
!INC IFC._Parameters
!INC IFC._Common

'
' Script Name: Schemas to Packages 
' Author: Knut Jetlund
' Purpose: Import Package structure from IFC EXPRESS Schema files
' Date: 20190830
'

sub schemas2Packages

	intitiateFilesAndPackages()	
	
	'Make sure all schemas exist as packages
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			if not lstPck.contains(strPackageName) then
				Session.Output(Now & " Create package from schema: " & strPackageName)
				set thePackage = rootPackage.Packages.AddNew(strPackageName,"Package")
				thePackage.Update()
				set el = thePackage.Element
				el.StereotypeEx = ""
				el.Update
				Session.Output(Now & " Adding package to list: " & thePackage.Name)
				lstPck.Add thePackage.Name,thePackage.packageGUID
				lstUcasePck.Add Ucase(thePackage.Name),thePackage.packageGUID
			else
				Session.Output(Now & " Existing package from schema: " & strPackageName)		
			end if
		end if	
	Next
	
	Session.Output(Now & " -----------------------------------------------------------------")
	
	'Read all references in each EXPRESS file and add package dependencies and package diagrams. 
	For Each objFile in objFiles
		if right(objFile.Name,3) = "exp" then
			Set objTextFile = objFSO.OpenTextFile(strMainFolder & "\" & objFile.Name,1)
			strPackageName = mid(objFile.Name,1,len(objFile.Name)-4)
			Session.Output(Now & " References in schema: " & strPackageName)
			set thePackage = getPackageFromList(lstPck, strPackageName)
			dim exists

			If not thePackage is nothing then 

				set eDiagram = nothing
				For each eD in thePackage.Diagrams
					if eD.Name = thePackage.Name & " Package dependencies" then 
						set eDiagram = eD
					end if	
				Next
				if eDiagram is nothing then 
					Session.Output(Now & " Create package diagram")
					set eDiagram = thePackage.Diagrams.AddNew(thePackage.Name  & " Package dependencies","Package")
					eDiagram.Update
				end if	
				exists = false
				for each eDO in eDiagram.DiagramObjects
					if eDO.ElementID = thePackage.Element.ElementID then exists = true
				next
				if exists = false then 
					set eDiagramObject = eDiagram.DiagramObjects.AddNew("","")
					eDiagramObject.ElementID = thePackage.Element.ElementID
					eDiagramObject.update
				end if
				
				Do Until objTextFile.AtEndOfStream 
					strNextLine = objTextFile.Readline 
					If left(strNextLine, 14) = "REFERENCE FROM" then
						Session.Output(Now & " Referenced package: " & mid(strNextLine, 16))
						set relatedPackage = getPackageFromList(lstUcasePck, UCase(mid(strNextLine, 16)))
						
						exists = false
						for each pckConnector in thePackage.Connectors
							if pckConnector.ClientID = thePackage.Element.ElementID and pckConnector.SupplierID = relatedPackage.Element.ElementID then exists = true
						next
						if not exists then
							'Add dependency
							set pckConnector = thePackage.Connectors.AddNew("", "Dependency")
							pckConnector.SupplierID = relatedPackage.Element.ElementID
							pckConnector.Update
						end if
						exists = false
						for each eDO in eDiagram.DiagramObjects
							if eDO.ElementID = relatedPackage.Element.ElementID then exists = true
							set eDiagramObject = eDO
						next
						if exists = false then 
							set eDiagramObject = eDiagram.DiagramObjects.AddNew("","")
							eDiagramObject.ElementID = relatedPackage.Element.ElementID
							eDiagramObject.update
						end if
					end if	
				Loop
				eDiagram.DiagramObjects.Refresh
				
				'Hide package contents and set fixed size
				for each eDiagramObject in eDiagram.DiagramObjects
					hideAttributes(eDiagramObject)
					setSize eDiagramObject, 70, 200					
				next
				
				'Hide associations between related packages.
				Dim edCon As EA.DiagramLink
				eDiagram.DiagramLinks.Refresh()
				Dim idxD
				For idxD = 0 To eDiagram.DiagramLinks.Count - 1
					set edCon = eDiagram.DiagramLinks.GetAt(idxD)
					set pckConnector = Repository.GetConnectorByID(edCon.ConnectorID)
					if pckConnector.ClientID = thePackage.Element.ElementID or pckConnector.SupplierID= thePackage.Element.ElementID then
						edCon.IsHidden = False
					else
						edCon.IsHidden = True
					End If
					edCon.Update()
				Next 
				
				ePIF.LayoutDiagramEx eDiagram.DiagramGUID, 4, 4, 20, 20, True
				repository.CloseDiagram(eDiagram.DiagramID)
			end if	
				
			Session.Output(Now & " -----------------------------------------------------------------")
		end if
	Next
	Session.Output(Now & " Done.")

end sub

schemas2Packages