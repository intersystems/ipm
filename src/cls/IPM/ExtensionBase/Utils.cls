Include %IPM.Common
Class %IPM.ExtensionBase.Utils
{

/// Corrects internal names for routines with slashes instead of dots, as a workaround for PL 145107
ClassMethod CorrectInternalNames(pInternalNames As %String = "") As %String
{
	Set tInternalNames = $ListFromString(pInternalNames,",")
	Set tModifiedList = ""
	Set tPtr = 0
	While $ListNext(tInternalNames,tPtr,tInternalName) {
		If ($Extract(tInternalName) = "/") {
			// See if this is a valid CSP resource
			Set tAppName = $System.CSP.GetAppName(tInternalName)
			If (tAppName = "") {
				// Replace slashes with dots
				Set tInternalName = $Replace($Extract(tInternalName,2,*),"/",".")
				
				// Convert extension to upper case
				Set $Piece(tInternalName,".",*) = $ZConvert($Piece(tInternalName,".",*),"U")
			}
		} Else {
			// Convert extension to upper case
			Set $Piece(tInternalName,".",*) = $ZConvert($Piece(tInternalName,".",*),"U")
		}
		Set tModifiedList = tModifiedList_$ListBuild(tInternalName)
	}
	Quit $ListToString(tModifiedList,",")
}

ClassMethod GetHomeModuleName(pInternalName As %String) As %String [ SqlProc ]
{
	Set tModule = ..FindHomeModule(pInternalName)
	Quit $Select($IsObject(tModule):tModule.Name,1:"")
}

ClassMethod FindHomeModule(pInternalName As %String, Output pResourceName As %String = "", Output pResourceReference As %IPM.Storage.ResourceReference = "") As %IPM.Storage.Module
{
	Set pResourceName = ""
	Set pResourceReference = $$$NULLOREF
	Set tModule = $$$NULLOREF
	Set tFullName = $Piece(pInternalName,".",1,*-1)
	Set tExtension = $Piece(pInternalName,".",*)
	If (tExtension = "INC") && ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tFullName_".LOC",.tResourceID) {
		Set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
		$$$ThrowOnError(tSC)
		Set tModule = pResourceReference.Module
		Set pResourceName = tFullName_".LOC"
	} ElseIf ($Extract(pInternalName) = "/") {
		Set tNameParts = $Length(pInternalName,"/")
		For i=tNameParts:-1:2 {
			Set tResourceName = $Piece(pInternalName,"/",1,i)
			
			If (i < tNameParts) {
				// Test with added slash.
				Set tFolderName = tResourceName_"/"
				If ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tFolderName,.tResourceID) {
					Set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
					$$$ThrowOnError(tSC)
					Set tModule = pResourceReference.Module
					Set pResourceName = tFolderName
					Quit
				}
			}
			
			If ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tResourceName,.tResourceID) {
				Set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
				$$$ThrowOnError(tSC)
				Set tModule = pResourceReference.Module
				Set pResourceName = tResourceName
				Quit
			}
		}
	} Else {
		// Handle stub classes specially
		If (tExtension = "CLS") && (tFullName '= "") && ($$$defClassKeyGet(tFullName,$$$cCLASSdeployed) = 2) {
			Set pInternalName = $$$defClassKeyGet(tFullName,$$$cCLASSgeneratedby)
			Set tFullName = $Piece(pInternalName,".",1,*-1)
			Set tExtension = $Piece(pInternalName,".",*)
		}
		Set tNameParts = $Length(pInternalName,".")-1
		For tPass=1,2 {
			For i=tNameParts:-1:1 {
				Set tModuleName = $Piece(pInternalName,".",1,i)
					
				// Determine name of resource to include / look for
				// Particularly, see if a class package should be included
				// rather than an individual class
				Set tResourceName = $Case(tExtension,
					"CLS":$Case(i,
						tNameParts:pInternalName,
						:tModuleName_".PKG"),
					:pInternalName)
				
				// First pass: see if it's already in a module.
				If (tPass = 1) && ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tResourceName,.tResourceID)  {
					Set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
					$$$ThrowOnError(tSC)
					Set tModule = pResourceReference.Module
				}
				
				// Second pass: not yet in a module - find the best match based on module/package naming conventions.
				If (tPass = 2) && ##class(%IPM.Storage.Module).NameExists(tModuleName,.tModuleID) {
					Set tModule = ##class(%IPM.Storage.Module).%OpenId(tModuleID,,.tSC)
					$$$ThrowOnError(tSC)
				}
				
				If $IsObject(tModule) {
					Set pResourceName = tResourceName
					Return tModule
				}
			}
		}
	}
	
	If '$IsObject(tModule) && (tExtension = "INC") {
		// Try to find in specific resources
		Set tProcessorClass = "LegacyLocalizedMessages"
		Set tProcessorClassFullForm = $$$DefaultProcessorPackageDot_tProcessorClass
		Set tQuery = "SELECT ID, Name, _Module FROM %IPM_Storage.ResourceReference "_
			"WHERE ProcessorClass = '"_tProcessorClass_"' "_
			"OR ProcessorClass = '"_tProcessorClassFullForm_"'"
		#dim tResultSet As %SQL.StatementResult
		Set tResultSet = ##class(%SQL.Statement).%ExecDirect(, tQuery)
		If (tResultSet.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tResultSet.%SQLCODE, tResultSet.%Message)
		}
		While tResultSet.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			#dim tReference As %IPM.Storage.ResourceReference
			Set tReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResultSet.%Get("ID"), , .tSC)
			$$$ThrowOnError(tSC)
			#dim tProcessor As %IPM.ResourceProcessor.LegacyLocalizedMessages
			If '$IsObject(tReference.Processor) {
				// Unable to resolve so ignore
				Continue
			}
			Kill tChildResources
			Set tSC = tReference.Processor.OnResolveChildren(.tChildResources)
			If $$$ISERR(tSC) {
				// Unable to resolve children so ignore
				Continue
			}
			If $Data(tChildResources(pInternalName)) {
				// Found matching module so return
				Set pResourceReference = tReference
				Set pResourceName = tResultSet.%Get("Name")
				Return ##class(%IPM.Storage.Module).%OpenId(tResultSet.%Get("_Module"))
			}
		}
		$$$ThrowOnError(tSC)
	}
	Quit tModule
}

}
