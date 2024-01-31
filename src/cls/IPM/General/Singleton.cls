/// General class to extend to add a "singleton" interface to any registered or persistent class.
/// For persistent classes, requires that the class has a unique index defined on a read-only property with an InitialExpression.
Class %IPM.General.Singleton Extends %RegisteredObject [ Abstract ]
{

/// If set to 1, calls to %Get must return an instance of this class created in the current namespace; a new instance will be created if none exists.
Parameter NAMESPACESCOPE As BOOLEAN = 1;

/// PPG in which to track references to the instance of this class
Parameter PPG As STRING = "^||%IPM.Singleton";

/// Internal property to track the namespace in which this instance was created.
Property %namespace As %String [ InitialExpression = {$Namespace}, Private, Transient ];

/// This method finds the existing instance of an object of a current class (created in the namespace if ..#NAMESPACESCOPE is 1) if it exists in the current process.
/// Exceptions are caught by calling code.
ClassMethod GetInMemoryInstance() As %IPM.General.Singleton [ CodeMode = objectgenerator, Private ]
{
	Set tClass = %class.Name
	Set tPPG = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"PPG",$$$cPARAMdefault)
	Set tIncludeNS = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"NAMESPACESCOPE",$$$cPARAMdefault)
	Set tPPGRef = tPPG_"("_$$$QUOTE(tClass)_$Select(tIncludeNS:",$Namespace",1:"")_")"
	Do %code.WriteLine(" Set tReturnValue = $$$NULLOREF")
	Do %code.WriteLine(" If $Data("_tPPGRef_",tObjInt) {")
	Do %code.WriteLine("  Set tInstance = $$$objIntToOref(tObjInt)")
	Do %code.WriteLine("  If $IsObject(tInstance) && ($classname(tInstance) = "_$$$QUOTE(tClass)_") {")
	Do %code.WriteLine("   Set tReturnValue = tInstance")
	Do %code.WriteLine("  }")
	Do %code.WriteLine(" }")
	Do %code.WriteLine(" Quit tReturnValue")
	Quit $$$OK
}

/// Return the single per-process/namespace instance of this class, or create a new one.
/// For persistent classes, may open the existing single record by its unique index.
ClassMethod %Get(Output pSC As %Status) As %IPM.General.Singleton [ CodeMode = objectgenerator, Final ]
{
	Set tSC = $$$OK
	Try {
		Set tThisClass = %class.Name
		Set tGenPersistent = 0
		
		// No-op for abstract classes.
		If $$$comClassKeyGet(tThisClass,$$$cCLASSabstract) {
			Quit
		}
		
		// Validation for persistent classes.
		If ($$$comClassKeyGet(tThisClass,$$$cCLASSclasstype) = $$$cCLASSCLASSTYPEPERSISTENT) {
			Set tGenPersistent = 1
			
			// Find a candidate index.
			Set tInitialExpression = ""
			Set tIndex = ""
			For {
				Set tIndex = $$$comMemberNext(tThisClass,$$$cCLASSindex,tIndex)
				If (tIndex = "") {
					Quit
				}
				
				// Is the index unique?
				If '$$$comMemberKeyGet(tThisClass,$$$cCLASSindex,tIndex,$$$cINDEXunique) {
					Continue
				}
				
				// Is the index on one property?
				If ($$$comMemberKeyGet(tThisClass,$$$cCLASSindex,tIndex,$$$cINDEXproperty) '= 1) {
					Continue
				}
				
				// Get that one property.
				Set tProperty = $$$comSubMemberKeyGet(tThisClass,$$$cCLASSindex,tIndex,$$$cINDEXproperty,1,$$$cINDEXPROPproperty)
				If (tProperty = "") {
					Continue
				}
				
				// Is that property read-only?
				If '$$$comMemberKeyGet(tThisClass,$$$cCLASSproperty,tProperty,$$$cPROPreadonly) {
					Continue
				}
				
				// Get the property's initial expression.
				Set tInitialExpression = $$$comMemberKeyGet(tThisClass,$$$cCLASSproperty,tProperty,$$$cPROPinitialexpression)
				If (tInitialExpression = "") {
					Continue
				}
				
				// If we got this far, we have a match, and tIndex won't be empty.
				Quit
			}
			
			If (tIndex = "") {
				// If we found no results...
				Set tMsg = "Class '%1' that Extends %IPM.General.Singleton must define a unique index on a read-only property with an InitialExpression defined."
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText(tMsg,tThisClass))
				Quit
			}
		}
		
		Do %code.WriteLine(" Set tInstance = $$$NULLOREF")
		Do %code.WriteLine(" Set pSC = $$$OK")
		Do %code.WriteLine(" Try {")
		Do %code.WriteLine("  Set tInstance = ..GetInMemoryInstance()")
		If tGenPersistent {
			// Support opening an existing object by its unique index on a read-only property with an initial expression
			Do %code.WriteLine("  If (tInstance = $$$NULLOREF) && .."_tIndex_"Exists("_tInitialExpression_") {")
			Do %code.WriteLine("   Set tInstance = .."_tIndex_"Open("_tInitialExpression_",,.pSC)")
			// If we found an existing instance, ensure that we have changes that another process may have made
			Do %code.WriteLine("  } ElseIf $IsObject(tInstance) && (tInstance.%Id() '= """") {")
			Do %code.WriteLine("   Set pSC = tInstance.%Reload()")
			Do %code.WriteLine("  } ElseIf (tInstance = $$$NULLOREF) {")
		} Else {
			Do %code.WriteLine("  If (tInstance = $$$NULLOREF) {")
		}
		Do %code.WriteLine("   Set tInstance = ..%New()")
		Do %code.WriteLine("  }")
		
		Do %code.WriteLine(" } Catch e { ")
		Do %code.WriteLine("  Set tInstance = $$$NULLOREF")
		Do %code.WriteLine("  Set pSC = e.AsStatus()")
		Do %code.WriteLine(" }")
		Do %code.WriteLine(" Quit tInstance")
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Tracks the OREF of this instance in a PPG for later reference.
/// Subclasses of %IPM.General.Singleton that override this method *MUST* call ##super().
Method %OnNew() As %Status [ Private, ServerOnly = 1 ]
{
	Quit ..%RecordOref()
}

/// Removes the OREF of this instance from PPG.
/// Subclasses of %IPM.General.Singleton that override this method *MUST* call ##super().
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	Quit ..%RemoveOref()
}

Method %RecordOref() As %Status [ CodeMode = objectgenerator, Final, Internal, Private ]
{
	Set tClass = %class.Name
	Set tPPG = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"PPG",$$$cPARAMdefault)
	Set tIncludeNS = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"NAMESPACESCOPE",$$$cPARAMdefault)
	Set tPPGRef = tPPG_"("_$$$QUOTE(tClass)_$Select(tIncludeNS:",..%namespace",1:"")_")"
	Do %code.WriteLine(" If $Data("_tPPGRef_") {")
	Do %code.WriteLine("  Quit $$$ERROR($$$GeneralError,""Instance of "_tClass_" already created for this process."")")
	Do %code.WriteLine(" }")
	Do %code.WriteLine(" Set "_tPPGRef_" = +$This")
	Do %code.WriteLine(" Quit $$$OK")
	Quit $$$OK
}

Method %RemoveOref() As %Status [ CodeMode = objectgenerator, Final, Internal, Private ]
{
	Set tClass = %class.Name
	Set tPPG = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"PPG",$$$cPARAMdefault)
	Set tIncludeNS = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"NAMESPACESCOPE",$$$cPARAMdefault)
	Set tPPGRef = tPPG_"("_$$$QUOTE(tClass)_$Select(tIncludeNS:",..%namespace",1:"")_")"
	Do %code.WriteLine(" Kill "_tPPGRef)
	Do %code.WriteLine(" Quit $$$OK")
	Quit $$$OK
}

}
