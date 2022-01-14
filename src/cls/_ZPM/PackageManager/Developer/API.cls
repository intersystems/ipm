Include (%occInclude, %occErrors, %ZPM.PackageManager.Common)

Class %ZPM.PackageManager.Developer.API
{

/// Converts <var>pObject</var> to a Module object and returns it by reference.
/// (The caller may then export it to XML, for example.)
ClassMethod CreateModule(pObject As %ZEN.proxyObject, Output pModule As %ZPM.PackageManager.Developer.Module) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set pModule = ##class(%ZPM.PackageManager.Developer.Module).%New()
		Set tSC = ..ProxyToModule(pObject,pModule)
		$$$ThrowOnError(tSC)
		$$$ThrowOnError(pModule.%ValidateObject())
		TSTART
		Do ..AddUDLDefaults(pModule)
		Do ..CreateInstallerClass(pModule)
		Do ..CreateLifecycleClass(pModule)
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

/// Converts <var>pObject</var> to a Module object and saves it.
ClassMethod UpdateModule(pModuleName As %String, pObject As %ZEN.proxyObject, Output pSourceControlOutput) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pModuleName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		TSTART
		Do ..CreateInstallerClass(pObject)
		Do ..CreateLifecycleClass(pObject)
		
		Set tSC = ..ProxyToModule(pObject,tModule,1,.pSourceControlOutput)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..ExportDocumentForObject(tModule,.pSourceControlOutput)
		If $$$ISERR(tSC) {
			Quit
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

ClassMethod ExportDocumentForObject(pSourceModule As %ZPM.PackageManager.Developer.Module, Output pSourceControlOutput) As %Status
{
	Set tSC = $$$OK
	Set tCookie = ""
	Try {
		New %SourceControl
		
		Do ##class(%ZPM.PackageManager.Developer.Utils).BeginCaptureOutput(.tCookie)
		
		Do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		
		Set tDocName = pSourceModule.Name_".ZPM"
		
		Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,.tIsInSourceControl,.tIsEditable)
		$$$ThrowOnError(tSC)
		
		If tIsInSourceControl && 'tIsEditable {
			// Try to make the document editable.
			Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.Interface).%OnMakeModuleEditable(pSourceModule)
			$$$ThrowOnError(tSC)
		}
		
		// Did we actually make the document editable?
		Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,,.tIsEditable)
		$$$ThrowOnError(tSC)
		
		// If still not editable, error out.
		If 'tIsEditable {
			$$$ThrowStatus($$$ERROR($$$ItemNotCheckedOut,tDocName))
		}
		
		Set tModuleStream = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameOpen(pSourceModule.Name,,.tSC)
		If $ListFind($ListFromString($System.Status.GetErrorCodes(tSC)),$$$KeyValueNotFoundOpen) {
			// It's possible that only the module exists - we'll skip the merge with the document's content if it does.
			Set tSC = $$$OK
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		If $IsObject(tModuleStream) {
			// Extract comments from existing document stream
			Set tHandler = ##class(%ZPM.PackageManager.Developer.XML.CommentHandler).%New()
			Set tReader = ##class(%XML.SAX.Parser).%New()
			Set tSC = ##Class(%XML.SAX.Parser).ParseStream(tModuleStream.Contents,tHandler)
			$$$ThrowOnError(tSC)
		}
		
		// Use document API
		#dim tExportStream As %Stream.Object
		Set tSC = pSourceModule.XMLExportToStream(.tExportStream,,"literal,indent")
		If $$$ISERR(tSC) {
			Quit
		}
		
		If $IsObject(tModuleStream) {
			// Reapply comments to exported XML stream
			Set tSC = tHandler.Reapply(.tExportStream)
			$$$ThrowOnError(tSC)
		}
		
		// Save the document.
		Set tRtn = ##class(%Library.RoutineMgr).%OpenId(tDocName)
		If (tRtn = $$$NULLOREF) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module %1 does not exist.",pModuleName))
			Quit
		}
		
		// NOTE: tRtn.Code is a %ZPM.PackageManager.Developer.Document.Module
		Do tRtn.Code.Code.Clear()
		Set tHeader = tExportStream.ReadLine()
		If ($Extract(tHeader,1,2) '= "<?") {
			Do tRtn.Code.Code.WriteLine("<?xml version=""1.0""?>")
		}
		Do tExportStream.Rewind()
		Set tSC = tRtn.Code.Code.CopyFrom(tExportStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = tRtn.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	// Ensure I/O redirection ends.
	Do ##class(%ZPM.PackageManager.Developer.Utils).EndCaptureOutput(tCookie,.pSourceControlOutput)
	Quit tSC
}

/// Add defaults to a module such that all classes are exported in UDL format
ClassMethod AddUDLDefaults(pSource As %ZPM.PackageManager.Developer.Module)
{
	// Value is 1 if filename extension is needed as an attribute. 0 otherwise
	#dim processorNameArray As %String
	Set processorNameArray("Default.Include") = 0
	Set processorNameArray("Default.Class") = 1
	Set processorNameArray("Default.Package") = 1
	Set processorNameArray("UnitTest") = 0
	
	Set processorName = ""
	While 1 {
		Set processorName = $Order(processorNameArray(processorName), 1, hasFilenameExtension)
		If (processorName = "") {
			Quit
		}
		Set defaultObj = ##class(%ZPM.PackageManager.Developer.ModuleSetting.ProcessorDefault).%New()
		Set defaultObj.Class = processorName
		Set sc = defaultObj.Attributes.SetAt("UDL", "Format")
		$$$ThrowOnError(sc)
		If hasFilenameExtension {
			Set sc = defaultObj.Attributes.SetAt("cls", "FilenameExtension")
			$$$ThrowOnError(sc)
		}
		Set sc = pSource.Defaults.Insert(defaultObj)
		$$$ThrowOnError(sc)
	}
}

ClassMethod CreateInstallerClass(pSource As %ZPM.PackageManager.Developer.Module) [ Private ]
{
	If (pSource.InstallerClass '= "") && '$$$defClassDefined(pSource.InstallerClass) && '$$$comClassDefined(pSource.InstallerClass) {
		// Create stub class
		Set tDef = ##class(%Dictionary.ClassDefinition).%New()
		Set tDef.Name = pSource.InstallerClass
		Set tDef.Super = "%ZPM.AbstractInstaller"
		Set tDef.ProcedureBlock = 1
		Do tDef.ProcedureBlockReset()
		$$$ThrowOnError(tDef.%Save())
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.ClassUtils).OverrideAbstractMembers(pSource.InstallerClass))
		
		// TODO: Add class to module (if not already covered by a package that's part of the module)
	}
}

ClassMethod CreateLifecycleClass(pSource As %ZPM.PackageManager.Developer.Module) [ Private ]
{
	If (pSource.LifecycleClass '= "") && '$$$defClassDefined(pSource.LifecycleClass) && '$$$comClassDefined(pSource.LifecycleClass) && '$$$comClassDefined($$$DefaultLifecyclePackageDot_pSource.LifecycleClass) {
		Set tDef = ##class(%Dictionary.ClassDefinition).%New()
		Set tDef.Name = pSource.LifecycleClass
		$$$ThrowOnError(##class(%ZPM.Lifecycle.Base).GetBaseClassForPackaging(pSource.Packaging,.tBaseClass))
		Set tDef.Super = tBaseClass
		Set tDef.ProcedureBlock = 1
		Do tDef.ProcedureBlockReset()
		$$$ThrowOnError(tDef.%Save())
		$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.ClassUtils).OverrideAbstractMembers(pSource.LifecycleClass))
		
		// TODO: Add class to module as a "preload" resource
	}
}

ClassMethod ProxyToModule(pObject As %ZEN.proxyObject, pModule As %ZPM.PackageManager.Developer.Module, pSave As %Boolean = 0, Output pSourceControlOutput) As %Status [ Private ]
{
	Set tSC = $$$OK
	Set tCookie = ""
	Try {
		Do ##class(%ZPM.PackageManager.Developer.Utils).BeginCaptureOutput(.tCookie)
		
		Set pModule.Name = pObject.ModuleName
		For tModuleProp = "GlobalScope","VersionString","ExternalName","Description","LifecycleClass","InstallerClass","Packaging","Keywords" {
			Set $Property(pModule,tModuleProp) = $Property(pObject,tModuleProp)
		}
		For tAuthorProp = "Person","Organization","CopyrightDate","License","Notes" {
			Set $Property(pModule.Author,tAuthorProp) = $Property(pObject.Author,tAuthorProp)
		}
		
		// Dependencies
		// Build maps of name -> index in pObject.Dependencies, bidirectionally for pModule.Dependencies
		Kill tSrcMap,tDestMap
		If (pObject.dependencyObj && pObject.dependencyObj.children) {
			For i=1:1:pObject.dependencyObj.children.Count() {
				Set tDep = pObject.dependencyObj.children.GetAt(i)
				If ('tDep.isDelete) && (tDep.ModuleName '= "") {
					Set tSrcMap(tDep.ModuleName,$Case(tDep.Scope,"":$c(0),:tDep.Scope)) = i
				}
			}
		}
		For i=1:1:pModule.Dependencies.Count() {
			Set tDep = pModule.Dependencies.GetAt(i)
			Set tDestMap(0,i) = $lb(tDep.Name,tDep.Scope)
			Set tDestMap(1,tDep.Name,$Case(tDep.Scope,"":$c(0),:tDep.Scope)) = i
		}
		
		// Create/update based on pObject.Dependencies
		Set tNameKey = ""
		For {
			Set tNameKey = $Order(tSrcMap(tNameKey))
			Quit:(tNameKey="")
			
			Set tScopeKey = ""
			For {
				Set tScopeKey = $Order(tSrcMap(tNameKey,tScopeKey),1,tSrcIdx)
				Quit:(tScopeKey="")
				
				Set tSrc = pObject.dependencyObj.children.GetAt(tSrcIdx)
				
				If $Data(tDestMap(1,tNameKey,tScopeKey),tDestIdx) {
					// Update
					Set tDep = pModule.Dependencies.GetAt(tDestIdx)
					
					// Remove from tDestMap
					Kill tDestMap(0,tDestIdx)
					Kill tDestMap(1,tNameKey,tScopeKey)
				} Else {
					// Create
					Set tDep = ##class(%ZPM.PackageManager.Core.ModuleReference).%New()
					Set tDep.Name = tNameKey
					Do pModule.Dependencies.Insert(tDep)
				}
				
				Set tDep.VersionString = tSrc.Version
				Set tDep.Scope = tSrc.Scope
			}
		}
		
		// Remove remaining items in tDestMap(0) in reverse order
		Set tDeleteKey = ""
		For {
			Set tDeleteKey = $Order(tDestMap(0,tDeleteKey),-1)
			Quit:(tDeleteKey="")
			
			Do pModule.Dependencies.RemoveAt(tDeleteKey)
		}
		
		// References
		// Build maps of name -> index in pObject.Resources, bidirectionally for pModule.Resources
		Kill tSrcMap,tDestMap
		If (pObject.resourceObj && pObject.resourceObj.children) {
			For i=1:1:pObject.resourceObj.children.Count() {
				Set tRes = pObject.resourceObj.children.GetAt(i)
				If ('tRes.isDelete) && (tRes.Name '= "") {
					Set tSrcMap(tRes.Name) = i
				}
			}
		}
		Set tResKey = ""
		For {
			Set tRes = pModule.Resources.GetNext(.tResKey)
			Quit:(tResKey="")
			Set tDestMap(0,tResKey) = tRes.Name
			Set tDestMap(1,tRes.Name) = tResKey
		}
		
		// Create/update based on pObject.Resources
		Set tNameKey = ""
		For {
			Set tNameKey = $Order(tSrcMap(tNameKey),1,tSrcIdx)
			Quit:(tNameKey="")
			
			Set tSrc = pObject.resourceObj.children.GetAt(tSrcIdx)
			
			If $Data(tDestMap(1,tNameKey),tDestIdx) {
				// Update
				Set tRes = pModule.Resources.GetAt(tDestIdx)
				
				// Remove from tDestMap
				Kill tDestMap(0,tDestIdx)
				Kill tDestMap(1,tNameKey)
			} Else {
				// Create
				Set tRes = ##class(%ZPM.PackageManager.Developer.ResourceReference).%New()
				Set tRes.Name = tNameKey
				Do pModule.Resources.Insert(tRes)
			}
			
			// TODO: Generated (Not yet supported in UI.)
			Set tRes.Preload = $Case(tSrc.Preload,1:1,:"")
			Set tRes.Scope = tSrc.Scope
			Set tRes.ProcessorClass = tSrc.ProcessorClass
			
			// Clone of the resource for comparison to default values.
			Set tResClone = ##class(%ZPM.PackageManager.Developer.ResourceReference).%New()
			Set tResClone.Name = tRes.Name
			Set tResClone.Scope = tRes.Scope
			Set tResClone.Preload = tRes.Preload
			Set tResClone.ProcessorClass = tRes.ProcessorClass
			Set tResClone.Module = tRes.Module
			
			Kill tAttrMap
			If $IsObject(tResClone.Processor) && $IsObject(tSrc.ProcessorClassAttributes) && tSrc.ProcessorClassAttributes.%IsA("%Collection.AbstractList") {
				For i=1:1:tSrc.ProcessorClassAttributes.Count() {
					Set tSrcAttr = tSrc.ProcessorClassAttributes.GetAt(i)
					Set tMethod = tSrcAttr.Name_"XSDToLogical"
					Set tValue = $Select(
						$System.CLS.IsMthd(tResClone.Processor,tMethod):$Method(tResClone.Processor,tMethod,tSrcAttr.Value),
						1:tSrcAttr.Value)
					If (tValue = $Property(tResClone.Processor,tSrcAttr.Name)) {
						// If the logical value matches the default value for the resource processor, omit it from the module XML.
						Do tRes.Attributes.RemoveAt(tSrcAttr.Name)
					} Else {
						Do tRes.Attributes.SetAt(tSrcAttr.Value,tSrcAttr.Name)
					}
				}
			}
			
			// Note: this can't go in %OnBeforeSave because the lifecycle class could be overridden in some cases
			If $IsObject(tRes.Processor) && ($classname(tRes.Processor) = tRes.Module.Lifecycle.GetDefaultResourceProcessor(tRes.Name)) {
				// Don't bother listing the processor class if it matches the lifecycle default.
				Set tRes.ProcessorClass = ""
			}
			
			// Just to be safe...
			Set tResClone.Module = $$$NULLOREF
			
			If (pSave) {
				// Shallow save just this resource. (Seems to not happen otherwise sometimes... ?)
				Set tSC = tRes.%Save(0)
			}
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Remove remaining items in tDestMap(0) in reverse order
		Set tDeleteKey = ""
		For {
			Set tDeleteKey = $Order(tDestMap(0,tDeleteKey),-1)
			Quit:(tDeleteKey="")
			
			Do pModule.Resources.RemoveAt(tDeleteKey)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	// Ensure I/O redirection ends.
	Do ##class(%ZPM.PackageManager.Developer.Utils).EndCaptureOutput(tCookie,.pSourceControlOutput)
	Quit tSC
}

ClassMethod GetModuleProperties(pModuleName As %String, Output pObject As %ZEN.proxyObject) As %Status
{
	Try {
		Set tSC = $$$OK
		Set pObject = ##class(%ZEN.proxyObject).%New()
		Set pObject.error = ""
		Set tModuleName = $Piece(pModuleName,".ZPM",1)
		If tModuleName = "" {
			Set tModuleObj = ##class(%ZPM.PackageManager.Developer.Module).%New()
		} Else {
			Set tModuleObj = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tModuleName,,.tSC)
			$$$ThrowOnError(tSC)
		}
		Set pObject.Name = tModuleObj.Name
		Set pObject.GlobalScope = tModuleObj.GlobalScope
		Set pObject.VersionString = tModuleObj.VersionString
		Set pObject.ExternalName = tModuleObj.ExternalName
		Set pObject.Description = tModuleObj.Description
		Set pObject.Keywords = tModuleObj.Keywords
		Set pObject.Packaging = tModuleObj.Packaging
		Set pObject.GlobalScope = tModuleObj.GlobalScope
		Set tSystemLifecycleClass = $Piece(tModuleObj.LifecycleClass,$$$DefaultLifecyclePackageDot,2,*)
		Set pObject.LifecycleClass = $Case(tSystemLifecycleClass,"":tModuleObj.LifecycleClass,:tSystemLifecycleClass)
		Set pObject.InstallerClass = tModuleObj.InstallerClass
		Set tAuthor = ##class(%ZEN.proxyObject).%New()
		Set tAuthor.Person = tModuleObj.Author.Person
		Set tAuthor.Organization = tModuleObj.Author.Organization
		Set tAuthor.CopyrightDate = tModuleObj.Author.CopyrightDate
		Set tAuthor.License = tModuleObj.Author.License
		Set tAuthor.Notes = tModuleObj.Author.Notes
		Set pObject.Author = tAuthor		
	} Catch ex {
		Set tSC = ex.AsStatus()
		Set pObject.error = tSC
	}
	Quit tSC
}

ClassMethod GetPackagingListSQL(Output pSQL As %String) As %Status
{
	Set pSQL = "select Packaging,BaseClass from %ZPM_Lifecycle.Base_Packaging()"
	Quit $$$OK
}

ClassMethod GetLifecycleClassListSQL(Output pSQL As %String) As %Status
{
	Set pSQL = "select SUBSTRING(cd.Name,"_(1+$Length($$$DefaultLifecyclePackageDot))_") Name from "_
		"%Dictionary.ClassDefinition_SubclassOf('%ZPM.PackageManager.Developer.Lifecycle.Abstract') subs "_
		"join %Dictionary.CompiledClass cd on subs.Name = cd.Name "_
		"where cd.Abstract = 0 and cd.Name %STARTSWITH '"_$$$DefaultLifecyclePackageDot_"' "_
		"union "_
		"select cd.Name from "_
		"%Dictionary.ClassDefinition_SubclassOf('%ZPM.PackageManager.Developer.Lifecycle.Abstract') subs "_
		"join %Dictionary.CompiledClass cd on subs.Name = cd.Name "_
		"where cd.Abstract = 0 and not cd.Name %STARTSWITH '"_$$$DefaultLifecyclePackageDot_"'"
	Quit $$$OK
}

ClassMethod GetInstallerClassListSQL(Output pSQL As %String) As %Status
{
	Set pSQL = "select cd.Name from "_
		"%Dictionary.ClassDefinition_SubclassOf('%ZPM.AbstractInstaller') subs "_
		"join %Dictionary.CompiledClass cd on subs.Name = cd.Name "_
		"where cd.Abstract = 0"
	Quit $$$OK
}

ClassMethod GetProcessorClassListSQL(Output pSQL As %String) As %Status
{
	Set pSQL = "select SUBSTRING(cd.Name,"_(1+$Length($$$DefaultProcessorPackageDot))_") Name, "_
			"%ZPM_PackageManager_Developer_Processor.Abstract_GetDescription(cd.Name) Description from "_
		"%Dictionary.ClassDefinition_SubclassOf('%ZPM.PackageManager.Developer.Processor.Abstract') subs "_
		"join %Dictionary.CompiledClass cd on subs.Name = cd.Name "_
		"where cd.Abstract = 0 and cd.Name %STARTSWITH '"_$$$DefaultProcessorPackageDot_"' "_
		"union "_
		"select cd.Name,%ZPM_PackageManager_Developer_Processor.Abstract_GetDescription(cd.Name) Description from "_
		"%Dictionary.ClassDefinition_SubclassOf('%ZPM.PackageManager.Developer.Processor.Abstract') subs "_
		"join %Dictionary.CompiledClass cd on subs.Name = cd.Name "_
		"where cd.Abstract = 0 and not cd.Name %STARTSWITH '"_$$$DefaultProcessorPackageDot_"'"
	Quit $$$OK
}

Query ListProcessorAttributes(pProcessorClass As %String) As %Query(ROWSPEC = "Name:%String,Type:%String,Description:%String,Default:%String,Required:%Boolean,VALUELIST:%String,DISPLAYLIST:%String,MINLEN:%String,MAXLEN:%String,MINVAL:%Integer,MAXVAL:%Integer") [ SqlProc ]
{
}

ClassMethod ListProcessorAttributesExecute(ByRef qHandle As %Binary, pProcessorClass As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Set qHandle("pointer") = ""
		Set tSuper = "%ZPM.PackageManager.Developer.Processor.Abstract"
		If '$$$comClassDefined(pProcessorClass) && $$$comClassDefined($$$DefaultProcessorPackageDot_pProcessorClass) {
			Set pProcessorClass = $$$DefaultProcessorPackageDot_pProcessorClass
		}
		If '$ClassMethod(pProcessorClass,"%Extends",tSuper) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Class '%1' does not extend '%2'",pProcessorClass,tSuper))
			Quit
		}
		Set tSC = $ClassMethod(pProcessorClass,"GetAttributeMetadata",.tMetadata)
		If $$$ISERR(tSC) {
			Quit
		}
		Merge qHandle("data") = tMetadata
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ListProcessorAttributesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ListAttributesExecute ]
{
	Set qHandle("pointer") = $Order(qHandle("data",qHandle("pointer")),1,Row)
	If (qHandle("pointer") = "") {
		Set AtEnd = 1
	}
	Quit $$$OK
}

ClassMethod ListProcessorAttributesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ListAttributesExecute ]
{
	Quit $$$OK
}

/// If <var>pSnapshots</var> is empty, lists all modules.
/// If 1, only snapshots; if 0, only non-snapshots.
ClassMethod GetInstalledModuleListSQL(Output pSQL As %String, pSnapshots As %Boolean = "") As %Status
{
	Set pSQL = "select Name from %ZPM_PackageManager_Developer.""Module"""
	If (pSnapshots = 0) {
		Set pSQL = pSQL_" where Version_Build <> 'snapshot'"
	} ElseIf (pSnapshots = 1) {
		Set pSQL = pSQL_" where Version_Build = 'snapshot'"
	}
	Set pSQL = pSQL_" order by Name"
	Quit $$$OK
}

ClassMethod GetModuleListSQL(Output pSQL As %String) As %Status
{
	Try {
		Set tSC = $$$OK
		Set pSQL = "select * from %ZPM_PackageManager_Developer.API_GetAvailableModuleNames()"

	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod GetDependencySQL(pModuleName As %String, Output pSQL As %String, Output pArgs) As %Status
{
	Kill pArgs
	Set pSQL = ""
	Set tSC = $$$OK
	Try {
		Set tModuleName = $Piece(pModuleName,".ZPM",1)
		If tModuleName '= "" {
			Set pSQL = "select Dependencies_Name as ModuleName, Dependencies_VersionString as Version, Dependencies_Scope as Scope "_
				"from %ZPM_PackageManager_Developer.Module_Dependencies "_
				"where ""Module""->Name=?"
			Set pArgs($i(pArgs)) = tModuleName
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod GetResourceSQL(pModuleName As %String, Output pSQL As %String, Output pArgs) As %Status
{
	Kill pArgs
	Set pSQL = ""
	Set tSC = $$$OK
	Try {
		Set tModuleName = $Piece(pModuleName,".ZPM",1)
		If tModuleName '= "" {
			Set tProcessorExpression = "NVL(ProcessorClass,%ZPM_PackageManager_Developer_Lifecycle.GET_DEFAULT_RESOURCE_PROCESSOR(""Module""->LifecycleClass,Name))"
			Set pSQL = "select Name,Preload,Scope,Deploy, "_
				"case when "_tProcessorExpression_" %STARTSWITH '"_$$$DefaultProcessorPackageDot_"' "_
				"then SUBSTRING("_tProcessorExpression_","_(1+$Length($$$DefaultProcessorPackageDot))_") "_
				"else "_tProcessorExpression_" end ProcessorClass "_
				"from %ZPM_PackageManager_Developer.ResourceReference "_
				"where ""Module""->Name=?"
			Set pArgs($i(pArgs)) = tModuleName
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod GetResourceAttributeSQL(pModuleName As %String, Output pSQL As %String, Output pArgs) As %Status
{
	Kill pArgs
	Set pSQL = ""
	Set tSC = $$$OK
	Try {
		Set tModuleName = $Piece(pModuleName,".ZPM",1)
		If tModuleName '= "" {
			Set pSQL = "select ResourceReference->Name ResourceReference,element_key Name,Attributes Value "_
				"from %ZPM_PackageManager_Developer.ResourceReference_Attributes "_
				"where ResourceReference->""Module""->Name=?"
			Set pArgs($i(pArgs)) = tModuleName
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod GetServerListSQL(Output pSQL As %String) As %Status
{
	Set pSQL = ""
	Set tSC = $$$OK
	Try {
		Set pSQL = "select Name from %ZPM_PackageManager_Client.ServerDefinition"
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod GetServerDefinitionList(Output pObject As %ZEN.proxyObject) As %Status
{
	Set pObject = ##class(%ZEN.proxyObject).%New()
	Set pObject.children = ##class(%ListOfObjects).%New()
	Set tSC = $$$OK
	Try {
		Set tRS = ##class(%ResultSet).%New()
		Set tRS.ClassName = "%Dictionary.ClassDefinition"
		Set tRS.QueryName = "SubclassOf"
		Set tSC = tRS.Execute("%ZPM.PackageManager.Client.ServerDefinition")
     	If $$$ISERR(tSC) {
	     	Quit	
     	}
     	While tRS.Next() {
	     	Set tClassObj = ##class(%ZEN.proxyObject).%New()
	     	Set tClassObj.ClassName = tRS.Data("Name")
    		Set tClassObj.DisplayName = $parameter(tRS.Data("Name"),"DISPLAYNAME")
    		Do pObject.children.Insert(tClassObj)
     	}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod GetRepositorySQL(Output pSQL As %String) As %Status
{
	Set pSQL = ""
	Set tSC = $$$OK
	Try {
		Set pSQL = "select * from %ZPM_PackageManager_Client.ServerDefinition order by ID"
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

Query GetAvailableModuleNames() As %Query(ROWSPEC = "Name:%String") [ SqlProc ]
{
}

ClassMethod GetAvailableModuleNamesExecute(ByRef qHandle As %Binary) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
		Set tSC = ##class(%ZPM.PackageManager.Client.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults)
		If $$$ISERR(tSC) {
			Quit
		}
		
		For i=1:1:tResults.Count() {
			#dim tRef As %ZPM.PackageManager.Core.QualifiedModuleReference = tResults.GetAt(i)
			Set qHandle(tRef.Name) = ""
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod GetAvailableModuleNamesFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = GetAvailableModuleNamesExecute ]
{
	Set qHandle = $Order(qHandle($Get(qHandle)))
	If (qHandle = "") {
		Set AtEnd = 1
	} Else {
		Set Row = $ListBuild(qHandle)
	}
	Quit $$$OK
}

ClassMethod GetAvailableModuleNamesClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = GetAvailableModuleNamesExecute ]
{
	Quit $$$OK
}

Query GetAvailableModuleVersions(pName As %String) As %Query(ROWSPEC = "Version:%String,ServerKey:%String") [ SqlProc ]
{
}

ClassMethod GetAvailableModuleVersionsExecute(ByRef qHandle As %Binary, pName As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		If ($Get(pName) '= "") {
		
			Set tSearchCriteria = ##class(%ZPM.PackageManager.Core.SearchCriteria).%New()
			Set tSearchCriteria.Name = pName
			Set tSC = ##class(%ZPM.PackageManager.Client.Utils).SearchRepositoriesForModule(tSearchCriteria,.tResults)
			If $$$ISERR(tSC) {
				Quit
			}
			
			For i=1:1:tResults.Count() {
				#dim tRef As %ZPM.PackageManager.Core.QualifiedModuleReference = tResults.GetAt(i)
				Set qHandle(i) = $ListBuild(tRef.VersionString,tRef.ServerName)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod GetAvailableModuleVersionsFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = GetAvailableModuleVersionsExecute ]
{
	Set qHandle = $Order(qHandle($Get(qHandle)),1,tRow)
	If (qHandle = "") {
		Set AtEnd = 1
	} Else {
		Set Row = tRow
	}
	Quit $$$OK
}

ClassMethod GetAvailableModuleVersionsClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = GetAvailableModuleVersionsExecute ]
{
	Quit $$$OK
}

}
