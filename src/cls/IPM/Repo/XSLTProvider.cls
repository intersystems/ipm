Class %IPM.Repo.XSLTProvider Extends %IPM.General.Singleton
{

/// If set to 1, calls to %Get must return an instance of this class created in the current namespace; a new instance will be created if none exists.
Parameter NAMESPACESCOPE As BOOLEAN = 1;

Property Transforms [ MultiDimensional, Private ];

/// @API.Method
/// @Modifier Availability InterSystems
ClassMethod GetCompiledTransformForXData(pClassName As %Dictionary.Classname, pXData As %Dictionary.Identifier) As %XML.XSLT.CompiledStyleSheet
{
	Set tInstance = ..%Get(.tSC)
	$$$ThrowOnError(tSC)
	Quit tInstance.GetCompiledTransformForXDataInternal(pClassName,pXData)
}

Method GetCompiledTransformForXDataInternal(pClassName As %Dictionary.Classname, pXData As %Dictionary.Identifier) As %XML.XSLT.CompiledStyleSheet [ Internal, Private ]
{
	If '$Data(..Transforms(pClassName,pXData),tCompiledStyleSheet)#2 || (..Transforms(pClassName,"%RandomSig") '= $Parameter(pClassName,"%RandomSig")) {
		Set tXData = ##class(%Dictionary.CompiledXData).IDKEYOpen(pClassName,pXData,,.tSC)
		$$$ThrowOnError(tSC)
		Set tSC = ##class(%XML.XSLT.CompiledStyleSheet).CreateFromStream(tXData.Data,.tCompiledStyleSheet)
		$$$ThrowOnError(tSC)
		Set ..Transforms(pClassName,"%RandomSig") = $Parameter(pClassName,"%RandomSig") // Detect recompilation
		Set ..Transforms(pClassName,pXData) = tCompiledStyleSheet
	}
	Quit tCompiledStyleSheet
}

}
