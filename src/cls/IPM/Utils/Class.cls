Class %IPM.Utils.Class
{

/// Overrides all abstract methods, properties, of <var>pClassName</var>'s parents (removing the [ Abstract ] flag) and saves the class definition.
/// If <var>pDefaultToSuper</var> is 1, defaults method implementations to call ##super() (either do or quit depending on the return type).
/// If the parent class method is unimplemented, this won't be done.
ClassMethod OverrideAbstractMembers(
	pClassName As %String,
	pDefaultToSuper As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    try {
        // Ensure class is compiled first.
        $$$ThrowOnError($system.OBJ.Compile(pClassName,"-d"))

        set tClassDef = ##class(%Dictionary.ClassDefinition).%OpenId(pClassName,,.tSC)
        $$$ThrowOnError(tSC)

        // $Order over member definitions in compiled class that might be marked as [Abstract]
        // That is: parameters and methods. (I'd thought class queries too, but apparently not.)
        for tMemberType = $$$cCLASSparameter,$$$cCLASSmethod {
            set tAbstract = $case(tMemberType,$$$cCLASSparameter:$$$cPARAMabstract,$$$cCLASSmethod:$$$cMETHabstract)
            set tMember = ""
            for {
                set tMember = $$$comMemberNext(pClassName,tMemberType,tMember)
                quit:tMember=""

                // Skip non-abstract methods.
                continue:'$$$comMemberKeyGet(pClassName,tMemberType,tMember,tAbstract)

                // Get the origin for abstract methods.
                set tOrigin = $$$comMemberKeyGet(pClassName,tMemberType,tMember,$$$cXXXXorigin)
                continue:(tOrigin="%Library.SystemBase")
                continue:(tOrigin="%Library.RegisteredObject")

                // Copy member from origin to pClassName (using Objects)
                if (tMemberType = $$$cCLASSmethod) {
                    #dim tSourceMethod,tDestMethod As %Dictionary.MethodDefinition
                    set tSourceMethod = ##class(%Dictionary.MethodDefinition).%OpenId(tOrigin_"||"_tMember,0)
                    set tDestMethod = tSourceMethod.%ConstructClone()
                    set tDestMethod.Abstract = 0
                    if (pDefaultToSuper) && (tDestMethod.Implementation.Size > 0) {
                        // Make implementation a call to do or quit ##super()
                        do tDestMethod.Implementation.Clear()
                        set tCommand = $case(tSourceMethod.ReturnType,"":"Do",:"Quit")
                        do tDestMethod.Implementation.Write($char(9)_" "_tCommand_" ##super(")
                        set tFormalSpecParsed = $$$comMemberKeyGet(tOrigin,$$$cCLASSmethod,tMember,$$$cMETHformalspecparsed)
                        set tPointer = 0
                        set tParamCount = 0
                        while $listnext(tFormalSpecParsed,tPointer,tMethParam) {
                            set tStart = $case($increment(tParamCount),1:".",:",.")
                            do tDestMethod.Implementation.Write(tStart_$list(tMethParam))
                        }
                        do tDestMethod.Implementation.WriteLine(")")
                    }
                    $$$ThrowOnError(tClassDef.Methods.Insert(tDestMethod))
                } elseif (tMemberType = $$$cCLASSparameter) {
                    #dim tSourceParam,tDestParam As %Dictionary.ParameterDefinition
                    set tSourceParam = ##class(%Dictionary.ParameterDefinition).%OpenId(tOrigin_"||"_tMember,0)
                    set tDestParam = tSourceParam.%ConstructClone()
                    set tDestParam.Abstract = 0
                    $$$ThrowOnError(tClassDef.Parameters.Insert(tDestParam))
                }
            }
        }

        // Save updated class definition
        $$$ThrowOnError(tClassDef.%Save())
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
