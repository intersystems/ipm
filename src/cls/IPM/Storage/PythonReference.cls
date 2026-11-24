/// store the python libraries mentioned in the requirements.txt file
Class %IPM.Storage.PythonReference Extends (%Persistent, %XML.Adaptor, %IPM.Utils.ComparisonAdaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.PythonRefs";

Property LibraryName As %String(MAXLEN = 255) [ Required ];

Property Version As %String;

Property SourceType As %String(VALUELIST = ",pypi,whl") [ InitialExpression = "pypi" ];

/// The physical path to the .whl file on the server
Property WheelPath As %String(MAXLEN = 1000);

/// The specific platform tag (e.g., 'manylinux_2_17_x86_64' or 'win_amd64')
Property PlatformTag As %String(MAXLEN = 100);

Property RefCount As %Integer [ InitialExpression = 1 ];

Index LibIdx On LibraryName [ IdKey, Unique ];

ClassMethod SavePythonDependencies(pLibrarySpec As %String) As %IPM.Storage.PythonReference
{
    set libraryInfo = ..ParseLibrarySpec(pLibrarySpec)
    if libraryInfo="" {
        quit $$$ERROR("Invalid library specification: "_pLibrarySpec)
    }
    set libraryName = $listget(libraryInfo)
    set libararyVersion = $listget(libraryInfo,2)
    set pyRef = ##class(%IPM.Storage.PythonReference).%OpenId(libraryName)
    if $isobject(pyRef) {
        set pyRef.RefCount = pyRef.RefCount + 1
    } else {
        set pyRef = ..%New()
        set pyRef.LibraryName = libraryName
    }
    if libararyVersion'="" {
        set pyRef.Version = libararyVersion
    }
    if $listget(libraryInfo,3)="pypi" {
        set pyRef.SourceType = $listget(libraryInfo,3)
        set pyRef.PlatformTag = ""
        set pyRef.WheelPath = ""
    }
    else {
        set pyRef.SourceType = $listget(libraryInfo,3)
        set pyRef.PlatformTag = $listget(libraryInfo,4)
        set pyRef.WheelPath = $listget(libraryInfo,5)
    }
    $$$ThrowOnError(pyRef.%Save())
    quit pyRef
}

ClassMethod ParseLibrarySpec(pLibrarySpec As %String) As %String
{
    if pLibrarySpec="" {
        quit ""
    }
    if (pLibrarySpec[".whl")||(pLibrarySpec[".wheel") {
        set filename = $piece($translate(pLibrarySpec, "\", "/"), "/", *)
        set libName = $$$lcase($piece(filename, "-", 1))
        set platformTag = $piece($piece(filename, "-", 5),".")
        set version = $piece(filename, "-", 2)
        quit $listbuild(libName, version,"whl",platformTag,pLibrarySpec)
    }
    else {
        set filename = $$$lcase($piece(pLibrarySpec,"=="))
        set version = $piece(pLibrarySpec,"==",2)
        quit $listbuild(filename,version,"pypi")
    }
}

/// Checks if this specific instance's version matches the libraryInfo
Method IsVersionMatch(pLibrarySpec As %String) As %Boolean
{
    set libraryInfo = ..ParseLibrarySpec(pLibrarySpec)
    set version = $listget(libraryInfo, 2)
    if version = "" {
        quit 1
    }
    quit ..Version = version
}

ClassMethod IsPythonDependencyInstalled(pLibrarySpec As %String) As %Boolean
{
    set libraryInfo = ..ParseLibrarySpec(pLibrarySpec)
    set libraryName = $listget(libraryInfo)
    set version = $listget(libraryInfo, 2)
    set pyRef = ##class(%IPM.Storage.PythonReference).%OpenId(libraryName)
    if '$isobject(pyRef) {
        quit 0
    }
    if version'=""&&(pyRef.Version'=version) {
        quit 0
    }
    quit $$$OK
}

ClassMethod RemovePythonReference(
	pLibrarySpec As %String,
	ByRef pParams) As %Status
{
    set libraryInfo = ..ParseLibrarySpec(pLibrarySpec)
    set libraryName = $listget(libraryInfo)
    set pyRef = ##class(%IPM.Storage.PythonReference).%OpenId(libraryName)
    if '$isobject(pyRef) {
        quit $$$OK
    }
    if pyRef.RefCount<=1 {
        do ..UninstallPythonLibrary(libraryName, .pParams)
        $$$ThrowOnError(..%DeleteId(libraryName))
    } else {
        set pyRef.RefCount = pyRef.RefCount - 1
        $$$ThrowOnError(pyRef.%Save())
    }
    quit $$$OK
}

ClassMethod UninstallPythonLibrary(
	pLibraryName As %List,
	ByRef pParams)
{
    set verbose = $get(pParams("Verbose"))
    set target = ##class(%File).NormalizeDirectory("python", $system.Util.ManagerDirectory())
    if '$listvalid(pLibraryName) {
        set pLibraryName = $listfromstring(pLibraryName)
    }
    if '$data(^||%IPM.PipCaller, pipCaller) {
        set pipCaller = ##class(%IPM.Utils.Python).ResolvePipCaller(.pParams)
    }
    set command = pipCaller _ $listbuild("uninstall", "-y")_pLibraryName
    if $$$isUNIX {
        set command = command _ $listbuild("--break-system-packages")
    }
    if verbose {
        write !, "Running "
        zwrite command
    } else {
        set stdout = ""
    }
    set tSC = ##class(%IPM.Utils.Module).RunCommand(target, command,.stdout)
    $$$ThrowOnError(tSC)
}

Storage Default
{
<Data name="PythonReferenceDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Version</Value>
</Value>
<Value name="3">
<Value>SourceType</Value>
</Value>
<Value name="4">
<Value>WheelPath</Value>
</Value>
<Value name="5">
<Value>PlatformTag</Value>
</Value>
<Value name="6">
<Value>RefCount</Value>
</Value>
</Data>
<DataLocation>^IPM.Storage.PythonRefsD</DataLocation>
<DefaultData>PythonReferenceDefaultData</DefaultData>
<IdLocation>^IPM.Storage.PythonRefsD</IdLocation>
<IndexLocation>^IPM.Storage.PythonRefsI</IndexLocation>
<StreamLocation>^IPM.Storage.PythonRefsS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
