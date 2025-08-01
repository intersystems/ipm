Include %IPM.Common

/// Superclass for all classes used to process lifecycle events for resources
Class %IPM.ResourceProcessor.Abstract Extends %RegisteredObject [ Abstract, PropertyClass = %IPM.ResourceProcessor.PropertyParameters ]
{

Parameter NAME = {$piece(%classname, ".", *)};

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING;

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING;

Property ResourceReference As %IPM.Storage.ResourceReference(XMLPROJECTION = "NONE") [ Private ];

Property Params [ MultiDimensional ];

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
    set ..ResourceReference = pResourceReference
    do ..CopyAttributes()
    do ..ApplyDefaults()
    quit $$$OK
}

Method SetParams(ByRef pParams) As %Status
{
    if ($data(pParams)) {
        merge ..Params = pParams
        do ..CopyAttributes()
        do ..ApplyDefaults()
    }
    return $$$OK
}

Method CopyAttributes() [ CodeMode = objectgenerator, Private ]
{
    set tSC = $$$OK
    try {
        set tAttributes = $listfromstring(%parameter("ATTRIBUTES"))
        set tPtr = 0
        while $listnext(tAttributes,tPtr,tAttribute) {
            if $$$comMemberDefined(%compiledclass.Name,$$$cCLASSproperty,tAttribute) {
                if '$zname(tAttribute,6) {
                    set tMsg = $$$FormatText("Invalid property in ATTRIBUTES list: '%1'",tAttribute)
                    $$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
                }
                set tProps = $listfromstring($$$defMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPaliases))
                set tProps = tProps _ $listbuild(tAttribute)
                set tPtr1 = 0
                while $listnext(tProps, tPtr1, tAttribute) {
                    do %code.WriteLine(" Set tIsDefined = ..ResourceReference.Attributes.IsDefined("""_tAttribute_""")")
                    do %code.WriteLine(" If tIsDefined {")
                    do %code.Write("  Set .."_tAttribute_" = ")
                    set tDataType = $$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPruntimetype)
                    set tAttrValue = "..%Evaluate(..ResourceReference.Attributes.GetAt("""_tAttribute_"""))"
                    do %code.WriteLine("$Select($$$comMemberDefined($classname(),$$$cCLASSmethod,"""_tAttribute_"XSDToLogical""):$classmethod($classname(),"""_tAttribute_"XSDToLogical"","_tAttrValue_"),1:"_tAttrValue_")")
                    do %code.WriteLine(" }")
                }
            }
        }

        // Always generate something, to avoid <METHOD DOES NOT EXIST>
        do %code.WriteLine(" Quit")
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method ApplyDefaults()
{
    set tDefaults = ..ResourceReference.Module.Defaults
    for tDefaultIndex = 1:1:tDefaults.Count() {
        set tDefault = tDefaults.GetAt(tDefaultIndex)
        if tDefault.%IsA("%IPM.Storage.ModuleSetting.ProcessorDefault") {
            #dim tDefault As %IPM.Storage.ModuleSetting.ProcessorDefault
            set tThisClass = $classname()
            set tFullClass = $$$DefaultProcessorPackageDot_tDefault.Class
            if (tThisClass = tDefault.Class) || (tThisClass = tFullClass) {
                set tSatisfiesConditions = 1
                for tIndex = 1:1:tDefault.Conditions.Count() {
                    set tSatisfiesConditions = tSatisfiesConditions && ..SatisfiesCondition(tDefault.Conditions.GetAt(tIndex))
                    if 'tSatisfiesConditions {
                        quit
                    }
                }
                if tSatisfiesConditions {
                    do ..CopyDefaultAttributes(tDefault)
                }
            }
        }
    }
}

/// Generated similarly to <method>CopyAttributes</method>
Method CopyDefaultAttributes(pSource As %IPM.Storage.ModuleSetting.ProcessorDefault) [ CodeMode = objectgenerator, Private ]
{
    set tSC = $$$OK
    try {
        set tAttributes = $listfromstring(%parameter("ATTRIBUTES"))
        set tPtr = 0
        while $listnext(tAttributes,tPtr,tAttribute) {
            if $$$comMemberDefined(%compiledclass.Name,$$$cCLASSproperty,tAttribute) {
                if '$zname(tAttribute,6) {
                    set tMsg = $$$FormatText("Invalid property in ATTRIBUTES list: '%1'",tAttribute)
                    $$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
                }
                do %code.WriteLine(" Set tIsDefined = pSource.Attributes.IsDefined("""_tAttribute_""") && '..ResourceReference.Attributes.IsDefined("""_tAttribute_""")")
                do %code.WriteLine(" If tIsDefined {")
                do %code.Write("  Set .."_tAttribute_" = ")
                set tDataType = $$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPruntimetype)
                set tAttrValue = "..%Evaluate(pSource.Attributes.GetAt("""_tAttribute_"""))"
                do %code.WriteLine("$Select($$$comMemberDefined($classname(),$$$cCLASSmethod,"""_tAttribute_"XSDToLogical""):$classmethod($classname(),"""_tAttribute_"XSDToLogical"","_tAttrValue_"),1:"_tAttrValue_")")
                do %code.WriteLine(" }")
            }
        }

        // Always generate something, to avoid <METHOD DOES NOT EXIST>
        do %code.WriteLine(" Quit")
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method SatisfiesCondition(pCondition As %IPM.Storage.ModuleSetting.ProcessorDefault.Condition) As %Boolean
{
    set tValue = $property($this, pCondition.Attribute)
    quit $case(pCondition.Operator,
        "eq":(tValue = pCondition.Value),
        "neq":(tValue '= pCondition.Value),
        "gt":(tValue > pCondition.Value),
        "lt":(tValue < pCondition.Value),
        "gte":(tValue >= pCondition.Value),
        "lte":(tValue <= pCondition.Value),
        "contains":(tValue [ pCondition.Value),
        :(tValue = pCondition.Value))
}

ClassMethod GetAttributeMetadata(Output pMetaArray) As %Status [ CodeMode = objectgenerator ]
{
    set tAttributes = $listfromstring(%parameter("ATTRIBUTES"))
    set tPtr = 0
    while $listnext(tAttributes,tPtr,tAttribute) {
        if $$$comMemberDefined(%compiledclass.Name,$$$cCLASSproperty,tAttribute) {
            set tType = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"XSDTYPE"))
            // Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
            set tDesc = $$Quote^%qcr($$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPdescription))
            set tDefault = $$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPinitialexpression)
            set tAttributeRequired = $$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"ATTRIBUTEREQUIRED")
            set tRequired = $case(tAttributeRequired,
                "":$$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPrequired),
                :tAttributeRequired)
            set tValueList = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"VALUELIST"))
            set tDisplayList = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"DISPLAYLIST"))
            set tMINLEN = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MINLEN"))
            set tMAXLEN = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MAXLEN"))
            set tMINVAL = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MINVAL"))
            set tMAXVAL = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MAXVAL"))
            do %code.WriteLine(" Set pMetaArray($i(pMetaArray)) = $ListBuild("_$$$QUOTE(tAttribute)_","_tType_","_tDesc_","_tDefault_","_tRequired_","_tValueList_","_tDisplayList_","_tMINLEN_","_tMAXLEN_","_tMINVAL_","_tMAXVAL_")")
        }
    }
    do %code.WriteLine(" Quit $$$OK")
}

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    // Default implementation: call %ValidateObject to validate attributes
    set tSC = $$$OK
    try {
        if (pPhase = "Validate") {
            set tSC = ..%ValidateObject(1)
            if $$$ISERR(tSC) {
                set tSC = $system.Status.EmbedStatus($$$ERROR($$$GeneralError,$$$FormatText("Error validating resource '%1'",..ResourceReference.Name)),tSC)
                quit
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Called as phase <var>pPhase</var> is executed for the resource. If <var>pResourceHandled</var> is set to true,
/// then the default behavior for that resource will be bypassed in the current phase.
/// Currently, this is only used in the Verify phase, because of different handling of intermediate error statuses.
/// TODO: Implement for standard database resources (.INC, .CLS, etc.)
Method OnPhase(
	pPhase As %String,
	ByRef pParams,
	Output pResourceHandled As %Boolean = 0) As %Status
{
    quit $$$OK
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
    quit ""
}

Method OnExportItem(
	pFullExportPath As %String,
	pItemName As %String,
	ByRef pItemParams,
	ByRef pParams,
	Output pItemHandled As %Boolean = 0) As %Status
{
    quit $$$OK
}

Method OnBeforeArtifact(
	pExportDirectory As %String,
	pWorkingDirectory As %String,
	ByRef pParams) As %Status
{
    quit $$$OK
}

Method OnResolveChildren(
	ByRef pResourceArray,
	pCheckModuleOwnership As %Boolean) As %Status
{
    quit $$$OK
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
    set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
    quit $$$OK
}

/// Evaluates an expression in a provided string. <br />
/// These special expressions are case-insensitive. <br />
/// Current valid expressions:
/// <ul>
/// 	<li>{$root} - the resource's module's root directory </li>
/// 	<li>{name} - the name of the resource </li>
/// </ul>
/// In addition to these, look at expressions supported by %EvaluateSystemExpression
/// in class <class>%IPM.Utils.Module</class>.
Method %Evaluate(pAttrValue As %String) As %String [ Internal ]
{
    set tAttrValue = pAttrValue
    if $data(..Params) {
        merge tParams = ..Params
        do ##class(%IPM.Storage.ModuleSetting.Default).GetCustomParameters(.customParams,..ResourceReference.Module, .tParams)
        set tAttrValue = ##class(%IPM.Storage.ModuleSetting.Default).EvaluateAttribute(tAttrValue,.customParams)
    }
    if (tAttrValue '[ "{") {
        return tAttrValue
    }
    set tAttrValue = ##class(%IPM.Utils.Module).%EvaluateMacro(tAttrValue)
    set attrValue = ##class(%IPM.Utils.Module).%EvaluateSystemExpression(tAttrValue)
    set root = ..ResourceReference.Module.Root
    if (root '= "") {
        set root = ##class(%Library.File).NormalizeDirectory(root)
        set attrValue = ##class(%IPM.Utils.Module).%RegExReplace(attrValue, "root", root)
    }
    // {name} expression does not contain dollar sign; handle separately
    set name = ..ResourceReference.Name
    set attrValue = ##class(%Regex.Matcher).%New("(?i)\{name\}", attrValue).ReplaceAll($replace(name,"\","\\"))

    set regex = ##class(%Regex.Matcher).%New("#\{([^}]+)\}", attrValue)
    while regex.Locate() {
        set expr = regex.Group(1)
        set value = ..ResourceReference.Module.%EvaluateExpression(expr)
        set $extract(attrValue, regex.Start, regex.End - 1) = value
        set regex.Text = attrValue
    }

    return attrValue
}

ClassMethod GetDescription(pClassName As %String) As %String [ SqlProc ]
{
    quit $parameter(pClassName,"DESCRIPTION")
}

/// Subclasses may override to customize the studio project. (e.g., things that use web applications will do this.)
Method OnGetStudioProject(
	pProject As %Studio.Project,
	Output pHandled As %Boolean = 0)
{
}

}
