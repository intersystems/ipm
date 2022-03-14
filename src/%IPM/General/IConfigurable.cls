/// Interface for classes that require some level of configuration.
/// SETTINGS and DESCRIPTION are used to dynamically populate %IPM.Extension.ServerMenu.Configuration
/// with all classes that implement IConfigurable.
Class %IPM.General.IConfigurable [ Abstract ]
{

/// A delimited string in the format:
/// Key:Description[|Key:Description...]
Parameter SETTINGS;

/// A string to show in the grouping of settings for this class
Parameter DESCRIPTION;

/// Returns true if a value is defined for setting <var>pName</var>.
ClassMethod SettingIsDefined(pName As %String) As %Boolean [ Abstract ]
{
}

/// Clears value of setting <var>pName</var>
ClassMethod GetSettingValue(pName As %String) As %String [ Abstract ]
{
}

/// Clears value of setting <var>pName</var>
ClassMethod ClearSettingValue(pName As %String) As %Status [ Abstract ]
{
}

/// Sets setting <var>pName</var> to <var>pValue</var>. Should return an error %Status if <var>pValue</var> is invalid.
ClassMethod SetSettingValue(pName As %String, pValue As %String) As %Status [ Abstract ]
{
}

/// Returns the datatype of a setting, as one of:
/// boolean, string
/// The default implementation is to always return "string"
ClassMethod GetSettingType(pName As %String) As %String
{
	Quit "string"
}

Query ListSettings() As %Query(ROWSPEC = "Source:%String,SourceDescription:%String,Name:%String,Description:%String,Defined:%Boolean,Value:%String,IsFirstForSource:%Boolean,DataType:%String") [ Final, SqlProc ]
{
}

ClassMethod ListSettingsExecute(ByRef qHandle As %Binary) As %Status [ Final ]
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Set tSC = tStmt.%PrepareClassQuery("%Dictionary.ClassDefinition","SubclassOf")
		If $$$ISERR(tSC) {
			Quit
		}
		
		#dim tClassRes As %SQL.StatementResult
		Set tClassRes = tStmt.%Execute($classname())
		If (tClassRes.%SQLCODE < 0) {
			Set tSC = $$$ERROR($$$SQLCode,tClassRes.%SQLCODE,tClassRes.%Message)
			Quit
		}
		
		Set qHandle("classes") = tClassRes
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ListSettingsFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ Final, PlaceAfter = ListSettingsExecute ]
{
	Set tSC = $$$OK
	Try {
		#dim tClassRes As %SQL.StatementResult
		Set tClassRes = qHandle("classes")
		Set tListEnd = 1
		Set tFirstForSource = 0
		
		If $Data(qHandle("settings"),tSettingList) {
			Set tCurrentClass = qHandle("class")
			Set tPointer = qHandle("pointer")
			Set tListEnd = '$ListNext(tSettingList,tPointer,tSetting)
		}
			
		If tListEnd {
			Kill qHandle("class"),qHandle("settings"),qHandle("pointer")
			
			For {
				Set AtEnd = 'tClassRes.%Next(.tSC)
				Quit:AtEnd
				
				$$$ThrowOnError(tSC)
				Set tCurrentClass = tClassRes.%GetData(1)
				Set tSettingList = $ListFromString($Parameter(tCurrentClass,"SETTINGS"),"|")
				Continue:'$ListLength(tSettingList)
				
				Set qHandle("settings") = tSettingList
				Set qHandle("class") = tCurrentClass
				Set tPointer = 0
				Set tFirstForSource = 1
				Set tListEnd = '$ListNext(tSettingList,tPointer,tSetting)
				Quit
			}
		}
		
		If (AtEnd) {
			Quit
		}
		
		Set qHandle("pointer") = tPointer
		
		Set tClassDesc = $Parameter(tCurrentClass,"DESCRIPTION")
		Set tName = $Piece(tSetting,":")
		Set tDesc = $Piece(tSetting,":",2,*)
		Set tIsDefined = $ClassMethod(tCurrentClass,"SettingIsDefined",tName)
		Set tSettingValue = $ClassMethod(tCurrentClass,"GetSettingValue",tName)
		Set tType = $ClassMethod(tCurrentClass,"GetSettingType",tName)
		Set Row = $ListBuild(tCurrentClass,tClassDesc,tName,tDesc,tIsDefined,tSettingValue,tFirstForSource,tType)
	} Catch e {
		Write ! zw e w !
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ListSettingsClose(ByRef qHandle As %Binary) As %Status [ Final, PlaceAfter = ListSettingsExecute ]
{
	Quit $$$OK
}

}
