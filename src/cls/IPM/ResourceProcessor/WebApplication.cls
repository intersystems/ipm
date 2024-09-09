Include (%sySecurity, %occErrors, %occReference)

Class %IPM.ResourceProcessor.WebApplication Extends (%IPM.ResourceProcessor.Abstract, %XML.Adaptor) [ PropertyClass = %IPM.ResourceProcessor.PropertyParameters ]
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Facilitates Web Application create/update/delete.";

/// Name of the web application.
Property Name As %String [ Calculated ];

Method NameGet() As %String
{
    Set name = $Get(..SecurityProperties("Name"), $Get(..SecurityProperties("Url"), ""))
    If name = "" {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Name is required for web applications"))
    }
    Return name
}

/// Keeps track of all application properties
Property SecurityProperties As %RawString [ MultiDimensional ];

Method CopyAttributes() [ Private ]
{
    /*
     * Overridden to avoid needing a property in this class to correspond to each
     * attribute as the attribute list is just all non-private/transient properties 
     * in Security.Applications.
     */
    Set key = ""
    While 1 {
        Set value = ..ResourceReference.Attributes.GetNext(.key)
        If (key = "") {
            Quit
        }
        Set eval = ..%Evaluate(value)
        Set ..SecurityProperties(key) = eval
    }
}

/// Called as phase <var>pPhase</var> is executed for the resource. If <var>pResourceHandled</var> is set to true,
/// then the default behavior for that resource will be bypassed in the current phase.
Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
    Set sc = $$$OK
    Try {
        If (pPhase = "Validate") {
            If (..Name = "") {
                Return $$$ERROR($$$GeneralError,"Name is required for web applications")
            }
            Set keyList = ""
            Set key = ""
            While 1 {
                Set value = ..ResourceReference.Attributes.GetNext(.key)
                If (key = "") {
                    Quit
                }
                Set keyList = keyList _ $ListBuild(key)
            }
            Set badKeyList = ..DoPropertiesExist(keyList)
            If ($ListLength(badKeyList) > 0) {
                Set error = "The following invalid attributes were found for resource "_..ResourceReference.Name_": "_$ListToString(badKeyList)
                $$$ThrowStatus($$$ERROR($$$GeneralError,error))
            }
        }
    } Catch (ex) {
        Set sc = ex.AsStatus()
    }
    Return sc
}

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
    /*
     * NOTE: Web app creation is done in OnBeforePhase so it happens before other
     * resource processors such as FileCopy run.
     */
    Set sc = $$$OK
    Try {
        $$$ThrowOnError(##super(pPhase,.pParams))
        
        Set tVerbose = $Get(pParams("Verbose"))
        #; Set tIsApplication = ..ResourceReference.Module.Lifecycle.%IsA(##class(%ZHSLIB.PackageManager.Developer.Lifecycle.Application).%ClassName(1))
        Set tIsApplication = ..ResourceReference.Module.Lifecycle.%IsA(##class(%IPM.Lifecycle.DeployedModule).%ClassName(1))
        
        // TODO: Make mirror-safe?
        // Would require moving mirror-safe APIs to the package manager - at which point, why not just have the package manager manage the whole federation?
        If ((pPhase = "Configure") || ((pPhase = "Activate") && tIsApplication)) {
            // Create web application
            Do ..CreateOrUpdateWebApp(tVerbose)
        } ElseIf ((pPhase = "Unconfigure") || ((pPhase = "Clean") && tIsApplication)) {
            // Remove web application
            Do ..DeleteWebApp(tVerbose)
        }
    } Catch e {
        Set sc = e.AsStatus()
    }
    Quit sc
}

Method CreateOrUpdateWebApp(pVerbose As %Boolean = 0) [ Internal ]
{
    // TODO: Make mirror-safe.
    New $namespace
    Set $namespace = "%SYS"

    Merge properties = ..SecurityProperties
    If $Get(properties("AutheEnabled")) = "" {
        Set properties("AutheEnabled") = (
            ($Get(properties("PasswordAuthEnabled")) * $$$AutheCache) +
            ($Get(properties("UnauthenticatedEnabled")) * $$$AutheUnauthenticated) +
            ($Get(properties("DelegatedAuthEnabled")) * $$$AutheDelegated) +
            ($Get(properties("KerberosAuthEnabled")) * $$$AutheK5API) +
            ($Get(properties("LoginTokenEnabled")) * $$$AutheLoginToken)
        )
    }

    If properties("AutheEnabled") = 0 {
        kill properties("AutheEnabled")
    }

    If ##class(Security.Applications).Exists(..Name) {
        Write:pVerbose !,"Updating Web Application ",..Name
        Set sc = ##class(Security.Applications).Get(..Name,.oldProperties)
        $$$ThrowOnError(sc)
        
        Kill changes
        Set key = ""
        For {
            Set key = $Order(properties(key),1,value)
            Quit:(key="")
            Set oldValue = $Get(oldProperties(key))
            If (value '= oldValue) {
                If (value = "") {
                    Set value = "[missing]"
                }
                If (oldValue = "") {
                    Set oldValue = "[missing]"
                }
                Set changes($i(changes)) = key_": "_oldValue_" -> "_value 
            }
        }
        
        If $Data(changes) {
            If (pVerbose) {
                For i=1:1:$Get(changes) {
                    Write !,changes(i)
                }
            }
            Set sc = ##class(Security.Applications).Modify(..Name,.properties)
            $$$ThrowOnError(sc)
            Write:pVerbose !,"Done."
        } Else {
            Write:pVerbose !,"No changes detected or made."
        }
    } Else {
        Write:pVerbose !,"Creating Web Application ",..Name
        Set sc = ##class(Security.Applications).Create(..Name,.properties)
        If (pVerbose) {
            Set key = ""
            For {
                Set key = $Order(properties(key),1,tValue)
                Quit:key=""
                Write !,key,": ",tValue
            }
        }
        $$$ThrowOnError(sc)
        Write:pVerbose !,"Done."
    }
}

/// This removes an existing CSP application
Method DeleteWebApp(pVerbose As %Boolean = 0) [ Internal ]
{
    // TODO: Make mirror-safe.
    
    // Only try to purge files if the directory exists.
    Set sc = ##class(%Library.EnsembleMgr).deletePortal(..Name,"",pVerbose)
    Set errorCodes = $System.Status.GetErrorCodes(sc)
    If ((errorCodes [ $$$ApplicationDoesNotExist) || (errorCodes [ $$$DeleteObjectNotFound)) {
        // Not actually a problem - allow Clean/Uninstall to continue if it fails while trying to remove something that doesn't exist.
        Set sc = $$$OK
    }
    $$$ThrowOnError(sc)
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
    If (..Name '= "") {
        Set pUniqueName = ..Name
    }
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
    Set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
    If (..Name '= "") {
        Set pInfo.SourceControlAware = 1
        Set pInfo.ResourceType = "/CSP/"
        Set pInfo.Prefix = ..Name
        Set pInfo.RelativePath = ..ResourceReference.Name
        Set pInfo.IsDirectory = ($Piece(..ResourceReference.Name,"/",*) '[ ".")
    }
    Quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
    Quit ..ResourceReference.Name_$Piece(pItemName,..Name,2)
}

/// Check if the provided properties exist in Security.Applications.
/// Returns a list of properties that do not exist.
ClassMethod DoPropertiesExist(pPropList As %Library.List) As %Library.List [ Internal, Private ]
{
    New $Namespace
    Set $Namespace = "%SYS"

    Set badList = ""
    Set ptr = 0
    While $ListNext(pPropList,ptr,prop) {
        If '$$$comMemberDefined("Security.Applications",$$$cCLASSproperty,prop) {
            Set badList = badList _ $ListBuild(prop)
        }
    }
    Return badList
}

}
