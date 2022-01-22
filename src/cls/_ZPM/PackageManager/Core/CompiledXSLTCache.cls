Class %ZPM.PackageManager.Core.CompiledXSLTCache Extends %ZPM.PackageManager.Core.Singleton
{

Property Cache [ MultiDimensional, Private ];

ClassMethod GetCompiledStyleSheet(pClassName As %Dictionary.Classname, pXDataName As %Dictionary.Identifier, Output pCompiledStylesheet As %XML.XSLT.CompiledStyleSheet = {$$$NULLOREF}) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tInstance = ..%Get(.tSC)
		If (pClassName = "") || (pXDataName = "") {
			$$$ThrowStatus($$$ERROR($$$InvalidArgument))
		}
		If '$Data(tInstance.Cache(pClassName,pXDataName),pCompiledStylesheet) {
			Set tSourceXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen(pClassName,pXDataName,,.tSC)
			$$$ThrowOnError(tSC)
			$$$ThrowOnError(##class(%XML.XSLT.CompiledStyleSheet).CreateFromStream(tSourceXData.Data,.pCompiledStylesheet))
			Set tInstance.Cache(pClassName,pXDataName) = pCompiledStylesheet
		}
	} Catch e {
		Set pCompiledStylesheet = $$$NULLOREF
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
