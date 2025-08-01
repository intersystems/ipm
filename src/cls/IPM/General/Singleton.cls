/// General class to extend to add a "singleton" interface to any registered or persistent class.
/// For persistent classes, requires that the class has a unique index defined on a read-only property with an InitialExpression.
Class %IPM.General.Singleton Extends %RegisteredObject [ Abstract ]
{

/// If set to 1, calls to %Get must return an instance of this class created in the current namespace; a new instance will be created if none exists.
Parameter NAMESPACESCOPE As BOOLEAN = 1;

/// PPG in which to track references to the instance of this class
Parameter PPG As STRING = "^||%IPM.Singleton";

/// Internal property to track the namespace in which this instance was created.
Property %namespace As %String [ InitialExpression = {$namespace}, Private, Transient ];

/// This method finds the existing instance of an object of a current class (created in the namespace if ..#NAMESPACESCOPE is 1) if it exists in the current process.
/// Exceptions are caught by calling code.
ClassMethod GetInMemoryInstance() As %IPM.General.Singleton [ CodeMode = objectgenerator, Private ]
{
    set tClass = %class.Name
    set tPPG = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"PPG",$$$cPARAMdefault)
    set tIncludeNS = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"NAMESPACESCOPE",$$$cPARAMdefault)
    set tPPGRef = tPPG_"("_$$$QUOTE(tClass)_$select(tIncludeNS:",$Namespace",1:"")_")"
    do %code.WriteLine(" Set tReturnValue = $$$NULLOREF")
    do %code.WriteLine(" If $Data("_tPPGRef_",tObjInt) {")
    do %code.WriteLine("  Set tInstance = $$$objIntToOref(tObjInt)")
    do %code.WriteLine("  If $IsObject(tInstance) && ($classname(tInstance) = "_$$$QUOTE(tClass)_") {")
    do %code.WriteLine("   Set tReturnValue = tInstance")
    do %code.WriteLine("  }")
    do %code.WriteLine(" }")
    do %code.WriteLine(" Quit tReturnValue")
    quit $$$OK
}

/// Return the single per-process/namespace instance of this class, or create a new one.
/// For persistent classes, may open the existing single record by its unique index.
ClassMethod %Get(Output pSC As %Status) As %IPM.General.Singleton [ CodeMode = objectgenerator, Final ]
{
    set tSC = $$$OK
    try {
        set tThisClass = %class.Name
        set tGenPersistent = 0

        // No-op for abstract classes.
        if $$$comClassKeyGet(tThisClass,$$$cCLASSabstract) {
            quit
        }

        // Validation for persistent classes.
        if ($$$comClassKeyGet(tThisClass,$$$cCLASSclasstype) = $$$cCLASSCLASSTYPEPERSISTENT) {
            set tGenPersistent = 1

            // Find a candidate index.
            set tInitialExpression = ""
            set tIndex = ""
            for {
                set tIndex = $$$comMemberNext(tThisClass,$$$cCLASSindex,tIndex)
                if (tIndex = "") {
                    quit
                }

                // Is the index unique?
                if '$$$comMemberKeyGet(tThisClass,$$$cCLASSindex,tIndex,$$$cINDEXunique) {
                    continue
                }

                // Is the index on one property?
                if ($$$comMemberKeyGet(tThisClass,$$$cCLASSindex,tIndex,$$$cINDEXproperty) '= 1) {
                    continue
                }

                // Get that one property.
                set tProperty = $$$comSubMemberKeyGet(tThisClass,$$$cCLASSindex,tIndex,$$$cINDEXproperty,1,$$$cINDEXPROPproperty)
                if (tProperty = "") {
                    continue
                }

                // Is that property read-only?
                if '$$$comMemberKeyGet(tThisClass,$$$cCLASSproperty,tProperty,$$$cPROPreadonly) {
                    continue
                }

                // Get the property's initial expression.
                set tInitialExpression = $$$comMemberKeyGet(tThisClass,$$$cCLASSproperty,tProperty,$$$cPROPinitialexpression)
                if (tInitialExpression = "") {
                    continue
                }

                // If we got this far, we have a match, and tIndex won't be empty.
                quit
            }

            if (tIndex = "") {
                // If we found no results...
                set tMsg = "Class '%1' that Extends %IPM.General.Singleton must define a unique index on a read-only property with an InitialExpression defined."
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText(tMsg,tThisClass))
                quit
            }
        }

        do %code.WriteLine(" Set tInstance = $$$NULLOREF")
        do %code.WriteLine(" Set pSC = $$$OK")
        do %code.WriteLine(" Try {")
        do %code.WriteLine("  Set tInstance = ..GetInMemoryInstance()")
        if tGenPersistent {
            // Support opening an existing object by its unique index on a read-only property with an initial expression
            do %code.WriteLine("  If (tInstance = $$$NULLOREF) && .."_tIndex_"Exists("_tInitialExpression_") {")
            do %code.WriteLine("   Set tInstance = .."_tIndex_"Open("_tInitialExpression_",,.pSC)")
            // If we found an existing instance, ensure that we have changes that another process may have made
            do %code.WriteLine("  } ElseIf $IsObject(tInstance) && (tInstance.%Id() '= """") {")
            do %code.WriteLine("   Set pSC = tInstance.%Reload()")
            do %code.WriteLine("  } ElseIf (tInstance = $$$NULLOREF) {")
        } else {
            do %code.WriteLine("  If (tInstance = $$$NULLOREF) {")
        }
        do %code.WriteLine("   Set tInstance = ..%New()")
        do %code.WriteLine("  }")

        do %code.WriteLine(" } Catch e { ")
        do %code.WriteLine("  Set tInstance = $$$NULLOREF")
        do %code.WriteLine("  Set pSC = e.AsStatus()")
        do %code.WriteLine(" }")
        do %code.WriteLine(" Quit tInstance")
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Tracks the OREF of this instance in a PPG for later reference.
/// Subclasses of %IPM.General.Singleton that override this method *MUST* call ##super().
Method %OnNew() As %Status [ Private, ServerOnly = 1 ]
{
    quit ..%RecordOref()
}

/// Removes the OREF of this instance from PPG.
/// Subclasses of %IPM.General.Singleton that override this method *MUST* call ##super().
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    quit ..%RemoveOref()
}

Method %RecordOref() As %Status [ CodeMode = objectgenerator, Final, Internal, Private ]
{
    set tClass = %class.Name
    set tPPG = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"PPG",$$$cPARAMdefault)
    set tIncludeNS = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"NAMESPACESCOPE",$$$cPARAMdefault)
    set tPPGRef = tPPG_"("_$$$QUOTE(tClass)_$select(tIncludeNS:",..%namespace",1:"")_")"
    do %code.WriteLine(" If $Data("_tPPGRef_") {")
    do %code.WriteLine("  Quit $$$ERROR($$$GeneralError,""Instance of "_tClass_" already created for this process."")")
    do %code.WriteLine(" }")
    do %code.WriteLine(" Set "_tPPGRef_" = +$This")
    do %code.WriteLine(" Quit $$$OK")
    quit $$$OK
}

Method %RemoveOref() As %Status [ CodeMode = objectgenerator, Final, Internal, Private ]
{
    set tClass = %class.Name
    set tPPG = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"PPG",$$$cPARAMdefault)
    set tIncludeNS = $$$comMemberKeyGet(tClass,$$$cCLASSparameter,"NAMESPACESCOPE",$$$cPARAMdefault)
    set tPPGRef = tPPG_"("_$$$QUOTE(tClass)_$select(tIncludeNS:",..%namespace",1:"")_")"
    do %code.WriteLine(" Kill "_tPPGRef)
    do %code.WriteLine(" Quit $$$OK")
    quit $$$OK
}

}
