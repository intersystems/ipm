Class %IPM.Utils.Class
{

/// Overrides all abstract methods, properties, of <var>pClassName</var>'s parents (removing the [ Abstract ] flag) and saves the class definition.
/// If <var>pDefaultToSuper</var> is 1, defaults method implementations to call ##super() (either do or quit depending on the return type).
/// If the parent class method is unimplemented, this won't be done.
ClassMethod OverrideAbstractMembers(pClassName As %String, pDefaultToSuper As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		// Ensure class is compiled first.
		$$$ThrowOnError($System.OBJ.Compile(pClassName,"-d"))
		
		Set tClassDef = ##class(%Dictionary.ClassDefinition).%OpenId(pClassName,,.tSC)
		$$$ThrowOnError(tSC)
		
		// $Order over member definitions in compiled class that might be marked as [Abstract]
		// That is: parameters and methods. (I'd thought class queries too, but apparently not.)
		For tMemberType = $$$cCLASSparameter,$$$cCLASSmethod {
			Set tAbstract = $Case(tMemberType,$$$cCLASSparameter:$$$cPARAMabstract,$$$cCLASSmethod:$$$cMETHabstract)
			Set tMember = ""
			For {
				Set tMember = $$$comMemberNext(pClassName,tMemberType,tMember)
				Quit:tMember=""
				
				// Skip non-abstract methods.
				Continue:'$$$comMemberKeyGet(pClassName,tMemberType,tMember,tAbstract)
				
				// Get the origin for abstract methods.
				Set tOrigin = $$$comMemberKeyGet(pClassName,tMemberType,tMember,$$$cXXXXorigin)
				Continue:(tOrigin="%Library.SystemBase")
				Continue:(tOrigin="%Library.RegisteredObject")
				
				// Copy member from origin to pClassName (using Objects)
				If (tMemberType = $$$cCLASSmethod) {
					#dim tSourceMethod,tDestMethod As %Dictionary.MethodDefinition
					Set tSourceMethod = ##class(%Dictionary.MethodDefinition).%OpenId(tOrigin_"||"_tMember)
					Set tDestMethod = tSourceMethod.%ConstructClone()
					Set tDestMethod.Abstract = 0
					If (pDefaultToSuper) && (tDestMethod.Implementation.Size > 0) {
						// Make implementation a call to do or quit ##super()
						Do tDestMethod.Implementation.Clear()
						Set tCommand = $Case(tSourceMethod.ReturnType,"":"Do",:"Quit")
						Do tDestMethod.Implementation.Write($c(9)_" "_tCommand_" ##super(")
						Set tFormalSpecParsed = $$$comMemberKeyGet(tOrigin,$$$cCLASSmethod,tMember,$$$cMETHformalspecparsed)
						Set tPointer = 0
						Set tParamCount = 0
						While $ListNext(tFormalSpecParsed,tPointer,tMethParam) {
							Set tStart = $Case($Increment(tParamCount),1:".",:",.")
							Do tDestMethod.Implementation.Write(tStart_$List(tMethParam))
						}
						Do tDestMethod.Implementation.WriteLine(")")
					}
					$$$ThrowOnError(tClassDef.Methods.Insert(tDestMethod))
				} ElseIf (tMemberType = $$$cCLASSparameter) {
					#dim tSourceParam,tDestParam As %Dictionary.ParameterDefinition
					Set tSourceParam = ##class(%Dictionary.ParameterDefinition).%OpenId(tOrigin_"||"_tMember)
					Set tDestParam = tSourceParam.%ConstructClone()
					Set tDestParam.Abstract = 0
					$$$ThrowOnError(tClassDef.Parameters.Insert(tDestParam))
				}
			}
		}
		
		// Save updated class definition
		$$$ThrowOnError(tClassDef.%Save())
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
