Include %ZPM.PackageManager.Common

/// Superclass for all classes used to process lifecycle events for resources
Class %ZPM.PackageManager.Developer.Processor.Abstract Extends %RegisteredObject [ Abstract, PropertyClass = %ZPM.PackageManager.Developer.Processor.PropertyParameters ]
{

Parameter NAME = {$Piece(%classname, ".", *)};

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING;

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING;

Property ResourceReference As %ZPM.PackageManager.Developer.ResourceReference(XMLPROJECTION = "NONE") [ Private ];

Method %OnNew(pResourceReference As %ZPM.PackageManager.Developer.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..ResourceReference = pResourceReference
	Do ..CopyAttributes()
	Do ..ApplyDefaults()
	Quit $$$OK
}

Method CopyAttributes() [ CodeMode = objectgenerator, Private ]
{
	Set tSC = $$$OK
	Try {
		Set tAttributes = $ListFromString(%parameter("ATTRIBUTES"))
		Set tPtr = 0
		While $ListNext(tAttributes,tPtr,tAttribute) {
			If $$$comMemberDefined(%compiledclass.Name,$$$cCLASSproperty,tAttribute) {
				If '$ZName(tAttribute,6) {
					Set tMsg = $$$FormatText("Invalid property in ATTRIBUTES list: '%1'",tAttribute)
					$$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
				}
				Do %code.WriteLine(" Set tIsDefined = ..ResourceReference.Attributes.IsDefined("""_tAttribute_""")")
				Do %code.WriteLine(" If tIsDefined {")
				Do %code.Write("  Set .."_tAttribute_" = ")
				Set tDataType = $$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPruntimetype)
				Set tAttrValue = "..%Evaluate(..ResourceReference.Attributes.GetAt("""_tAttribute_"""))"
				Do %code.WriteLine("$Select($$$comMemberDefined($classname(),$$$cCLASSmethod,"""_tAttribute_"XSDToLogical""):$classmethod($classname(),"""_tAttribute_"XSDToLogical"","_tAttrValue_"),1:"_tAttrValue_")")
				Do %code.WriteLine(" }")
			}
		}
		
		// Always generate something, to avoid <METHOD DOES NOT EXIST>
		Do %code.WriteLine(" Quit")
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method ApplyDefaults()
{
	Set tDefaults = ..ResourceReference.Module.Defaults
	For tDefaultIndex = 1:1:tDefaults.Count() {
		Set tDefault = tDefaults.GetAt(tDefaultIndex)
		If tDefault.%IsA("%ZPM.PackageManager.Developer.ModuleSetting.ProcessorDefault") {
			#dim tDefault As %ZPM.PackageManager.Developer.ModuleSetting.ProcessorDefault
			Set tThisClass = $classname()
			Set tFullClass = $$$DefaultProcessorPackageDot_tDefault.Class
			If (tThisClass = tDefault.Class) || (tThisClass = tFullClass) {
				Set tSatisfiesConditions = 1
				For tIndex = 1:1:tDefault.Conditions.Count() {
					Set tSatisfiesConditions = tSatisfiesConditions && ..SatisfiesCondition(tDefault.Conditions.GetAt(tIndex))
					If 'tSatisfiesConditions {
						Quit
					}
				}
				If tSatisfiesConditions {
					Do ..CopyDefaultAttributes(tDefault)
				}
			}
		}
	}
}

/// Generated similarly to <method>CopyAttributes</method>
Method CopyDefaultAttributes(pSource As %ZPM.PackageManager.Developer.ModuleSetting.ProcessorDefault) [ CodeMode = objectgenerator, Private ]
{
	Set tSC = $$$OK
	Try {
		Set tAttributes = $ListFromString(%parameter("ATTRIBUTES"))
		Set tPtr = 0
		While $ListNext(tAttributes,tPtr,tAttribute) {
			If $$$comMemberDefined(%compiledclass.Name,$$$cCLASSproperty,tAttribute) {
				If '$ZName(tAttribute,6) {
					Set tMsg = $$$FormatText("Invalid property in ATTRIBUTES list: '%1'",tAttribute)
					$$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
				}
				Do %code.WriteLine(" Set tIsDefined = pSource.Attributes.IsDefined("""_tAttribute_""") && '..ResourceReference.Attributes.IsDefined("""_tAttribute_""")")
				Do %code.WriteLine(" If tIsDefined {")
				Do %code.Write("  Set .."_tAttribute_" = ")
				Set tDataType = $$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPruntimetype)
				Set tAttrValue = "..%Evaluate(pSource.Attributes.GetAt("""_tAttribute_"""))"
				Do %code.WriteLine("$Select($$$comMemberDefined($classname(),$$$cCLASSmethod,"""_tAttribute_"XSDToLogical""):$classmethod($classname(),"""_tAttribute_"XSDToLogical"","_tAttrValue_"),1:"_tAttrValue_")")
				Do %code.WriteLine(" }")
			}
		}
		
		// Always generate something, to avoid <METHOD DOES NOT EXIST>
		Do %code.WriteLine(" Quit")
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method SatisfiesCondition(pCondition As %ZPM.PackageManager.Developer.ModuleSetting.ProcessorDefault.Condition) As %Boolean
{
	Set tValue = $Property($This, pCondition.Attribute)
	Quit $Case(pCondition.Operator,
		"eq":(tValue = pCondition.Value),
		"neq":(tValue '= pCondition.Value),
		"gt":(tValue > pCondition.Value),
		"lt":(tValue < pCondition.Value),
		"gte":(tValue >= pCondition.Value),
		"lte":(tValue <= pCondition.Value),
		:(tValue = pCondition.Value))
}

ClassMethod GetAttributeMetadata(Output pMetaArray) As %Status [ CodeMode = objectgenerator ]
{
	Set tAttributes = $ListFromString(%parameter("ATTRIBUTES"))
	Set tPtr = 0
	While $ListNext(tAttributes,tPtr,tAttribute) {
		If $$$comMemberDefined(%compiledclass.Name,$$$cCLASSproperty,tAttribute) {
			Set tType = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"XSDTYPE"))
			// Different version of $$$QUOTE to convert newlines into $c(10) (for example) - this is what zwrite calls.
			Set tDesc = $$Quote^%qcr($$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPdescription))
			Set tDefault = $$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPinitialexpression)
			Set tAttributeRequired = $$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"ATTRIBUTEREQUIRED")
			Set tRequired = $Case(tAttributeRequired,
				"":$$$comMemberKeyGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPrequired),
				:tAttributeRequired)
			Set tValueList = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"VALUELIST"))
			Set tDisplayList = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"DISPLAYLIST"))
			Set tMINLEN = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MINLEN"))
			Set tMAXLEN = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MAXLEN"))
			Set tMINVAL = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MINVAL"))
			Set tMAXVAL = $$$QUOTE($$$comMemberArrayGet(%compiledclass.Name,$$$cCLASSproperty,tAttribute,$$$cPROPparameter,"MAXVAL"))
			Do %code.WriteLine(" Set pMetaArray($i(pMetaArray)) = $ListBuild("_$$$QUOTE(tAttribute)_","_tType_","_tDesc_","_tDefault_","_tRequired_","_tValueList_","_tDisplayList_","_tMINLEN_","_tMAXLEN_","_tMINVAL_","_tMAXVAL_")")
		}
	}
	Do %code.WriteLine(" Quit $$$OK")
}

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
	// Default implementation: call %ValidateObject to validate attributes
	Set tSC = $$$OK
	Try {
		If (pPhase = "Validate") {
			Set tSC = ..%ValidateObject(1)
			If $$$ISERR(tSC) {
				Set tSC = $System.Status.EmbedStatus($$$ERROR($$$GeneralError,$$$FormatText("Error validating resource '%1'",..ResourceReference.Name)),tSC)
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called as phase <var>pPhase</var> is executed for the resource. If <var>pResourceHandled</var> is set to true,
/// then the default behavior for that resource will be bypassed in the current phase.
/// Currently, this is only used in the Verify phase, because of different handling of intermediate error statuses.
/// TODO: Implement for standard database resources (.INC, .CLS, etc.)
Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	Quit $$$OK
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Quit $$$OK
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	Quit $$$OK
}

Method OnBeforeArtifact(pExportDirectory As %String, pWorkingDirectory As %String, ByRef pParams) As %Status
{
	Quit $$$OK
}

Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	Quit $$$OK
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
}

/// Evaluates an expression in an attribute
/// Current valid expressions:
/// {$namespace} - the current namespace
/// {$mgrdir} - the instance's mgr directory
/// {$cspdir} - the instance's root CSP directory
/// {$root} - the resource's module's root directory
/// These special expressions are case-insensitive.
Method %Evaluate(pAttrValue) As %String [ Internal ]
{
	Set tAttrValue = ..%RegExReplace(pAttrValue,"(?i)\{\$namespace\}",$Namespace)
	Set tAttrValue = ..%RegExReplace(pAttrValue,"(?i)\$\{namespace\}",$Namespace)
	Set tMgrDir = ##class(%File).ManagerDirectory()
	Set tAttrValue = ..%RegExReplace(tAttrValue,"(?i)\{\$mgrdir\}",tMgrDir)
	Set tAttrValue = ..%RegExReplace(tAttrValue,"(?i)\$\{mgrdir\}",tMgrDir)
	Set tCSPDir = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(tMgrDir)_"/csp")
	Set tAttrValue = ..%RegExReplace(tAttrValue,"(?i)\{\$cspdir\}",tCSPDir)
	Set tAttrValue = ..%RegExReplace(tAttrValue,"(?i)\$\{cspdir\}",tCSPDir)
	Set tRoot = $Case(..ResourceReference.Module.Root,"":"",:##class(%File).NormalizeDirectory(..ResourceReference.Module.Root))
	Set tAttrValue = ..%RegExReplace(tAttrValue,"(?i)\{\$root\}",tRoot)
	Set tAttrValue = ..%RegExReplace(tAttrValue,"(?i)\$\{root\}",tRoot)
	Quit tAttrValue
}

ClassMethod %RegExReplace(pString, pRegEx, pValue) As %String [ Private ]
{
	Quit ##class(%Regex.Matcher).%New(pRegEx,pString).ReplaceAll($Replace(pValue,"\","\\"))
}

ClassMethod GetDescription(pClassName As %String) As %String [ SqlProc ]
{
	Quit $Parameter(pClassName,"DESCRIPTION")
}

}
