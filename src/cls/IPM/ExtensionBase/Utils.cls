Include %IPM.Common

Class %IPM.ExtensionBase.Utils
{

/// Corrects internal names for routines with slashes instead of dots, as a workaround for PL 145107
ClassMethod CorrectInternalNames(pInternalNames As %String = "") As %String
{
    set tInternalNames = $listfromstring(pInternalNames,",")
    set tModifiedList = ""
    set tPtr = 0
    while $listnext(tInternalNames,tPtr,tInternalName) {
        if ($extract(tInternalName) = "/") {
            // See if this is a valid CSP resource
            set tAppName = $system.CSP.GetAppName(tInternalName)
            if (tAppName = "") {
                // Replace slashes with dots
                set tInternalName = $replace($extract(tInternalName,2,*),"/",".")

                // Convert extension to upper case
                set $piece(tInternalName,".",*) = $zconvert($piece(tInternalName,".",*),"U")
            }
        } else {
            // Convert extension to upper case
            set $piece(tInternalName,".",*) = $zconvert($piece(tInternalName,".",*),"U")
        }
        set tModifiedList = tModifiedList_$listbuild(tInternalName)
    }
    quit $listtostring(tModifiedList,",")
}

ClassMethod GetHomeModuleName(pInternalName As %String) As %String [ SqlProc ]
{
    set tModule = ..FindHomeModule(pInternalName)
    quit $select($isobject(tModule):tModule.Name,1:"")
}

ClassMethod FindHomeModule(
	pInternalName As %String,
	Output pResourceName As %String = "",
	Output pResourceReference As %IPM.Storage.ResourceReference = "") As %IPM.Storage.Module
{
    set pResourceName = ""
    set pResourceReference = $$$NULLOREF
    set tModule = $$$NULLOREF
    set tFullName = $piece(pInternalName,".",1,*-1)
    set tExtension = $piece(pInternalName,".",*)
    if (tExtension = "INC") && ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tFullName_".LOC",.tResourceID) {
        set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
        $$$ThrowOnError(tSC)
        set tModule = pResourceReference.Module
        set pResourceName = tFullName_".LOC"
    } elseif ($extract(pInternalName) = "/") {
        set tNameParts = $length(pInternalName,"/")
        for i=tNameParts:-1:2 {
            set tResourceName = $piece(pInternalName,"/",1,i)

            if (i < tNameParts) {
                // Test with added slash.
                set tFolderName = tResourceName_"/"
                if ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tFolderName,.tResourceID) {
                    set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
                    $$$ThrowOnError(tSC)
                    set tModule = pResourceReference.Module
                    set pResourceName = tFolderName
                    quit
                }
            }

            if ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tResourceName,.tResourceID) {
                set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
                $$$ThrowOnError(tSC)
                set tModule = pResourceReference.Module
                set pResourceName = tResourceName
                quit
            }
        }
    } else {
        // Handle stub classes specially
        if (tExtension = "CLS") && (tFullName '= "") && ($$$defClassKeyGet(tFullName,$$$cCLASSdeployed) = 2) {
            set pInternalName = $$$defClassKeyGet(tFullName,$$$cCLASSgeneratedby)
            set tFullName = $piece(pInternalName,".",1,*-1)
            set tExtension = $piece(pInternalName,".",*)
        }
        set tNameParts = $length(pInternalName,".")-1
        for tPass=1,2 {
            for i=tNameParts:-1:1 {
                set tModuleName = $piece(pInternalName,".",1,i)

                // Determine name of resource to include / look for
                // Particularly, see if a class package should be included
                // rather than an individual class
                set tResourceName = $case(tExtension,
                    "CLS":$case(i,
                        tNameParts:pInternalName,
                        :tModuleName_".PKG"),
                    :pInternalName)

                // First pass: see if it's already in a module.
                if (tPass = 1) && ##class(%IPM.Storage.ResourceReference).NonNullResourceNameExists(tResourceName,.tResourceID)  {
                    set pResourceReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResourceID,,.tSC)
                    $$$ThrowOnError(tSC)
                    set tModule = pResourceReference.Module
                }

                // Second pass: not yet in a module - find the best match based on module/package naming conventions.
                if (tPass = 2) && ##class(%IPM.Storage.Module).NameExists(tModuleName,.tModuleID) {
                    set tModule = ##class(%IPM.Storage.Module).%OpenId(tModuleID,,.tSC)
                    $$$ThrowOnError(tSC)
                }

                if $isobject(tModule) {
                    set pResourceName = tResourceName
                    return tModule
                }
            }
        }
    }

    if '$isobject(tModule) && (tExtension = "INC") {
        // Try to find in specific resources
        set tProcessorClass = "LegacyLocalizedMessages"
        set tProcessorClassFullForm = $$$DefaultProcessorPackageDot_tProcessorClass
        set tQuery = "SELECT ID, Name, ModuleItem FROM %IPM_Storage.ResourceReference "_
            "WHERE ProcessorClass = '"_tProcessorClass_"' "_
            "OR ProcessorClass = '"_tProcessorClassFullForm_"'"
        #dim tResultSet As %SQL.StatementResult
        set tResultSet = ##class(%SQL.Statement).%ExecDirect(, tQuery)
        if (tResultSet.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tResultSet.%SQLCODE, tResultSet.%Message)
        }
        while tResultSet.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            #dim tReference As %IPM.Storage.ResourceReference
            set tReference = ##class(%IPM.Storage.ResourceReference).%OpenId(tResultSet.%Get("ID"), , .tSC)
            $$$ThrowOnError(tSC)
            #dim tProcessor As %IPM.ResourceProcessor.LegacyLocalizedMessages
            if '$isobject(tReference.Processor) {
                // Unable to resolve so ignore
                continue
            }
            kill tChildResources
            set tSC = tReference.Processor.OnResolveChildren(.tChildResources)
            if $$$ISERR(tSC) {
                // Unable to resolve children so ignore
                continue
            }
            if $data(tChildResources(pInternalName)) {
                // Found matching module so return
                set pResourceReference = tReference
                set pResourceName = tResultSet.%Get("Name")
                return ##class(%IPM.Storage.Module).%OpenId(tResultSet.%Get("ModuleItem"))
            }
        }
        $$$ThrowOnError(tSC)
    }
    quit tModule
}

}
