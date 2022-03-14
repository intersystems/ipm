/// Used to wrap Studio document types not supported in Studio project deployments, putting the XML export in a class's XDATA block for later import. For example:
/// <example>
/// // Pack up Foo.ZPM in class Foo.ModuleWrappedInAClass:
/// Set tItems("Foo.ZPM") = ""
/// Set tSC = ##class(%IPM.Lifecycle.StudioProject.ContainerClass).Create("Foo.ModuleWrappedInAClass",.tItems)
/// // ... on another environment, after Foo.ModuleWrappedInAClass is loaded, retrieve the module manifest document from it:
/// Set tSC = ##class(Foo.ModuleWrappedInAClass).Unpack()
/// </example>
Class %IPM.Lifecycle.StudioProject.ContainerClass
{

/// Contains a Studio document export (from $System.OBJ.ExportStream)
XData Export
{
}

ClassMethod Unpack() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($classname(),"Export",,.tSC)
		$$$ThrowOnError(tSC)
		$$$ThrowOnError($System.OBJ.LoadStream(tXData.Data,,,.tLoaded))
		$$$ThrowOnError($System.OBJ.Delete($classname()))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod Create(pTargetClassName As %Dictionary.Classname, ByRef pItems, pVerbose As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Try {
		If ##class(%Dictionary.ClassDefinition).%ExistsId(pTargetClassName) {
			$$$ThrowOnError(##class(%Dictionary.ClassDefinition).%DeleteId(pTargetClassName))
		}
		Set tClassDefinition = ##class(%Dictionary.ClassDefinition).%New()
		Set tClassDefinition.Name = pTargetClassName
		Set tClassDefinition.ProcedureBlock = 1
		
		Set tMethodDefinition = ##class(%Dictionary.MethodDefinition).IDKEYOpen($classname(),"Unpack",,.tSC)
		$$$ThrowOnError(tSC)
		Set tClone = tMethodDefinition.%ConstructClone()
		Do tClassDefinition.Methods.Insert(tClone)
		
		Set tXDataDefinition = ##class(%Dictionary.XDataDefinition).%New()
		Set tXDataDefinition.Name = "Export"
		$$$ThrowOnError($System.OBJ.ExportToStream(.pItems,tXDataDefinition.Data,$Select(pVerbose:"d",1:"-d")))
		Do tClassDefinition.XDatas.Insert(tXDataDefinition)
		
		$$$ThrowOnError(tClassDefinition.%Save())
		$$$ThrowOnError($System.OBJ.Compile(pTargetClassName,"c-k-d"))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
