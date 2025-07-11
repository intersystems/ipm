/// Custom Studio document projection class to ensure that metadata globals are included in Studio Project exports.
/// This will allow the package manager to be installed (and function properly) from a Studio project export.
Class %IPM.StudioDocument.Projection Extends %Projection.StudioDocument
{

ClassMethod CreateProjection(
	classname As %String,
	ByRef parameters As %String) As %Status
{
    set tSC = ##super(classname,.parameters)
    quit $$$ADDSC(tSC,..AddToManifest(classname,"^oddStudioDocument("_$$$QUOTE(classname)_").GBL"))
}

ClassMethod RemoveProjection(
	classname As %String,
	ByRef parameters As %String,
	recompile As %Boolean) As %Status
{
    set tSC = ##super(classname,.parameters,recompile)
    quit $$$ADDSC(tSC,..RemoveFromManifest(classname,"^oddStudioDocument("_$$$QUOTE(classname)_").GBL"))
}

}
