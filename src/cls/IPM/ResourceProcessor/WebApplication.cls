Include (%sySecurity, %occErrors, %occReference)

Class %IPM.ResourceProcessor.WebApplication Extends (%IPM.ResourceProcessor.Abstract, %XML.Adaptor) [ PropertyClass = %IPM.ResourceProcessor.PropertyParameters ]
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Facilitates Web Application create/update/delete.";

/// Name of the web application.
Property Name As %String [ Calculated ];

Method NameGet() As %String
{
    set name = $get(..SecurityProperties("Name"), $get(..SecurityProperties("Url"), ""))
    if name = "" {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Name is required for web applications"))
    }
    return name
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

    // If NameSpace isn't specified, default to current namespace
    if ..ResourceReference.Attributes.GetAt("NameSpace") = "" {
        $$$ThrowOnError(..ResourceReference.Attributes.SetAt($namespace, "NameSpace"))
    }
    set key = ""
    while 1 {
        set value = ..ResourceReference.Attributes.GetNext(.key)
        if (key = "") {
            quit
        }
        set eval = ..%Evaluate(value)
        set ..SecurityProperties(key) = eval
    }
}

/// Called as phase <var>pPhase</var> is executed for the resource. If <var>pResourceHandled</var> is set to true,
/// then the default behavior for that resource will be bypassed in the current phase.
Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    set sc = $$$OK
    try {
        if (pPhase = "Validate") {
            if (..Name = "") {
                return $$$ERROR($$$GeneralError,"Name is required for web applications")
            }
            set keyList = ""
            set key = ""
            while 1 {
                set value = ..ResourceReference.Attributes.GetNext(.key)
                if (key = "") {
                    quit
                }
                set keyList = keyList _ $listbuild(key)
            }
            set badKeyList = ..DoPropertiesExist(keyList)
            if ($listlength(badKeyList) > 0) {
                set error = "The following invalid attributes were found for resource "_..ResourceReference.Name_": "_$listtostring(badKeyList)
                $$$ThrowStatus($$$ERROR($$$GeneralError,error))
            }
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    /*
     * NOTE: Web app creation is done in OnBeforePhase so it happens before other
     * resource processors such as FileCopy run.
     */
    set sc = $$$OK
    try {
        $$$ThrowOnError(##super(pPhase,.pParams))

        set tVerbose = $get(pParams("Verbose"))

        if ((pPhase = "Configure") || (pPhase = "Activate")) {
            // Create web application
            do ..CreateOrUpdateWebApp(tVerbose)
        } elseif ((pPhase = "Unconfigure") || (pPhase = "Clean")) {
            // Remove web application
            do ..DeleteWebApp(tVerbose)
        }
    } catch e {
        set sc = e.AsStatus()
    }
    quit sc
}

Method CreateOrUpdateWebApp(pVerbose As %Boolean = 0) [ Internal ]
{
    new $namespace
    set $namespace = "%SYS"

    merge properties = ..SecurityProperties

    if ##class(Security.Applications).Exists(..Name) {
        write:pVerbose !,"Updating Web Application ",..Name
        set sc = ##class(Security.Applications).Get(..Name,.oldProperties)
        $$$ThrowOnError(sc)

        kill changes
        set key = ""
        for {
            set key = $order(properties(key),1,value)
            quit:(key="")
            set oldValue = $get(oldProperties(key))
            if (value '= oldValue) {
                if (value = "") {
                    set value = "[missing]"
                }
                if (oldValue = "") {
                    set oldValue = "[missing]"
                }
                set changes($increment(changes)) = key_": "_oldValue_" -> "_value
            }
        }

        if $data(changes) {
            if (pVerbose) {
                for i=1:1:$get(changes) {
                    write !,changes(i)
                }
            }
            set sc = ##class(Security.Applications).Modify(..Name,.properties)
            $$$ThrowOnError(sc)
            write:pVerbose !,"Done."
        } else {
            write:pVerbose !,"No changes detected or made."
        }
    } else {
        write:pVerbose !,"Creating Web Application ",..Name
        set sc = ##class(Security.Applications).Create(..Name,.properties)
        if (pVerbose) {
            set key = ""
            for {
                set key = $order(properties(key),1,tValue)
                quit:key=""
                write !,key,": ",tValue
            }
        }
        $$$ThrowOnError(sc)
        write:pVerbose !,"Done."
    }
}

/// This removes an existing CSP application
Method DeleteWebApp(pVerbose As %Boolean = 0) [ Internal ]
{
    new $namespace
    set $namespace = "%SYS"
    if ##class(Security.Applications).Exists(..Name) {
        $$$ThrowOnError(##class(Security.Applications).Delete(..Name))
    }
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
    if (..Name '= "") {
        set pUniqueName = ..Name
    }
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
    set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
    if (..Name '= "") {
        set pInfo.SourceControlAware = 1
        set pInfo.ResourceType = "/CSP/"
        set pInfo.Prefix = ..Name
        set pInfo.RelativePath = ..ResourceReference.Name
        set pInfo.IsDirectory = 1
    }
    quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
    quit ..ResourceReference.Name_$piece(pItemName,..Name,2)
}

/// Check if the provided properties exist in Security.Applications.
/// Returns a list of properties that do not exist.
ClassMethod DoPropertiesExist(pPropList As %Library.List) As %Library.List [ Internal, Private ]
{
    new $namespace
    set $namespace = "%SYS"

    set badList = ""
    set ptr = 0
    while $listnext(pPropList,ptr,prop) {
        if '$$$comMemberDefined("Security.Applications",$$$cCLASSproperty,prop) {
            set badList = badList _ $listbuild(prop)
        }
    }
    return badList
}

}
