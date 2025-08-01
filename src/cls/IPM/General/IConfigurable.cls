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
ClassMethod SetSettingValue(
	pName As %String,
	pValue As %String) As %Status [ Abstract ]
{
}

/// Returns the datatype of a setting, as one of:
/// boolean, string
/// The default implementation is to always return "string"
ClassMethod GetSettingType(pName As %String) As %String
{
    quit "string"
}

Query ListSettings() As %Query(ROWSPEC = "Source:%String,SourceDescription:%String,Name:%String,Description:%String,Defined:%Boolean,Value:%String,IsFirstForSource:%Boolean,DataType:%String") [ Final, SqlProc ]
{
}

ClassMethod ListSettingsExecute(ByRef qHandle As %Binary) As %Status [ Final ]
{
    set tSC = $$$OK
    try {
        set tStmt = ##class(%SQL.Statement).%New()
        set tSC = tStmt.%PrepareClassQuery("%Dictionary.ClassDefinition","SubclassOf")
        if $$$ISERR(tSC) {
            quit
        }

        #dim tClassRes As %SQL.StatementResult
        set tClassRes = tStmt.%Execute($classname())
        if (tClassRes.%SQLCODE < 0) {
            set tSC = $$$ERROR($$$SQLCode,tClassRes.%SQLCODE,tClassRes.%Message)
            quit
        }

        set qHandle("classes") = tClassRes
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod ListSettingsFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ Final, PlaceAfter = ListSettingsExecute ]
{
    set tSC = $$$OK
    try {
        #dim tClassRes As %SQL.StatementResult
        set tClassRes = qHandle("classes")
        set tListEnd = 1
        set tFirstForSource = 0

        if $data(qHandle("settings"),tSettingList) {
            set tCurrentClass = qHandle("class")
            set tPointer = qHandle("pointer")
            set tListEnd = '$listnext(tSettingList,tPointer,tSetting)
        }

        if tListEnd {
            kill qHandle("class"),qHandle("settings"),qHandle("pointer")

            for {
                set AtEnd = 'tClassRes.%Next(.tSC)
                quit:AtEnd

                $$$ThrowOnError(tSC)
                set tCurrentClass = tClassRes.%GetData(1)
                set tSettingList = $listfromstring($parameter(tCurrentClass,"SETTINGS"),"|")
                continue:'$listlength(tSettingList)

                set qHandle("settings") = tSettingList
                set qHandle("class") = tCurrentClass
                set tPointer = 0
                set tFirstForSource = 1
                set tListEnd = '$listnext(tSettingList,tPointer,tSetting)
                quit
            }
        }

        if (AtEnd) {
            quit
        }

        set qHandle("pointer") = tPointer

        set tClassDesc = $parameter(tCurrentClass,"DESCRIPTION")
        set tName = $piece(tSetting,":")
        set tDesc = $piece(tSetting,":",2,*)
        set tIsDefined = $classmethod(tCurrentClass,"SettingIsDefined",tName)
        set tSettingValue = $classmethod(tCurrentClass,"GetSettingValue",tName)
        set tType = $classmethod(tCurrentClass,"GetSettingType",tName)
        set Row = $listbuild(tCurrentClass,tClassDesc,tName,tDesc,tIsDefined,tSettingValue,tFirstForSource,tType)
    } catch e {
        write ! zwrite e write !
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod ListSettingsClose(ByRef qHandle As %Binary) As %Status [ Final, PlaceAfter = ListSettingsExecute ]
{
    quit $$$OK
}

}
