/// Utility class for all integration and unit test classes
Class Test.PM.General.Utils
{

ClassMethod ReadXDataToModule(
	pNamespace As %String = {$namespace},
	pXDataName As %String,
	ByRef pModule As %IPM.Storage.Module) As %Status
{
	new $namespace
	set tInitNS = $namespace
	set tStatus = $$$OK
	try {
		set $namespace = pNamespace
		set tXData = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||"_pXDataName,,.tStatus)
		if $$$ISERR(tStatus) {
			quit
		}

		// Find the module name by inspecting the XML prior to importing it as a document.
		set tReader = ##class(%XML.Reader).%New()
		set tSC = tReader.OpenStream(tXData.Data)
		if $$$ISERR(tSC) {
			quit
		}

		do tReader.Correlate("Module","%IPM.Storage.Module")
		do tReader.Next(.tModule,.tSC)
		set tName = tModule.Name_".ZPM"
		do tXData.Data.Rewind()

		set $namespace = tInitNS

		set tStatus = ##class(%IPM.StudioDocument.Module).ImportStream(.tName,tXData.Data)
		if $$$ISERR(tStatus) {
			quit
		}

		set pModule = ##class(%IPM.Storage.Module).NameOpen($piece(tName,".",1,*-1),,.tStatus)
		if $$$ISERR(tStatus) {
			quit
		}
	} catch e {
		set tStatus = e.AsStatus()
	}
	quit tStatus
}

ClassMethod GetModuleDir(subfolders... As %String) As %String
{
  set tTestRoot = ##class(%File).NormalizeDirectory($get(^UnitTestRoot))
  set tTestRoot = ##class(%File).GetDirectory(tTestRoot)
  set tModuleDir = ##class(%File).Construct(tTestRoot, "_data", subfolders...)
  set tModuleDir = ##class(%File).NormalizeDirectory(tModuleDir)
  quit tModuleDir
}

/// Returns whether a substring is found in any element of a multi-dimensional array
ClassMethod FindStringInMultiDimArray(
	pString As %String,
	ByRef pArray) As %Boolean
{
	set sub = ""
	for {
		set sub = $order(pArray(sub), 1, element)
		if sub = "" {
			quit
		}
		if element [ pString {
			return 1
		}
	}
	return 0
}

/// Returns true if any configured repository offers the named module
ClassMethod ModuleAvailableInRepositories(moduleName As %String) As %Boolean
{
	set criteria = ##class(%IPM.Repo.SearchCriteria).%New()
	set criteria.Name = $$$lcase(moduleName)
	set sc = ##class(%IPM.Repo.Utils).SearchRepositoriesForModule(criteria, .results)
	if $$$ISERR(sc) || '$isobject(results) {
		return 0
	}
	return results.Count() > 0
}

/// Returns whether <var>string</var> appears on any line of the file at <var>filePath</var>.
ClassMethod FileContains(
	filePath As %String,
	string As %String) As %Boolean
{
	set stream = ##class(%Stream.FileCharacter).%New()
	set stream.Filename = filePath
	while 'stream.AtEnd {
		if (stream.ReadLine() [ string) {
			return 1
		}
	}
	return 0
}

ClassMethod HttpGet(pPath As %String = "/") As %Status
{
	new $namespace
	set $namespace = "%SYS"

	set tSC = ##class(Config.Startup).Get(.props)
	if $$$ISERR(tSC) {
		quit tSC
	}

	set request = ##class(%Net.HttpRequest).%New()
	set request.Server = "127.0.0.1"
	set request.Port = props("WebServerPort")
	set path = props("WebServerURLPrefix") _ "/" _ pPath
	set tSC = request.Get(path)
	if $$$ISERR(tSC) {
		quit tSC
	}
	if (request.HttpResponse.StatusCode '= 200) {
		quit $$$ERROR($$$GeneralError, "HTTP Status: "_request.HttpResponse.StatusCode_$char(13,10)_request.HttpResponse.Data.Read())
	}
	quit $$$OK
}


}