Class %IPM.Storage.PinnedModule Extends (%Persistent, %JSON.Adaptor, %XML.Adaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.PinnedModule";

Parameter DOMAIN = "ZPM";

Property Name As %String(MAXLEN = 128) [ Required ];

Property PinnedVersion As %String(MAXLEN = 32) [ Required ];

Property PinnedAt As %TimeStamp [ Required ];

Property PinnedBy As %String;

Index PinnedModuleIdx On Name [ IdKey, Unique ];

ClassMethod IsModulePinned(pModule As %String = "") As %Boolean [ CodeMode = expression ]
{
$select($$$lcase(pModule)'="": ..%ExistsId($$$lcase(pModule)),1: 0)
}

ClassMethod GetAllPinnedModules(Output list)
{
    set tResult = ##class(%SQL.Statement).%ExecDirect(,"select Name, PinnedVersion from %IPM_Storage.PinnedModule")
    $$$ThrowSQLIfError(tResult.%SQLCODE, tResult.%Message)
    kill list
    set width=0
    while tResult.%Next(.tSC) {
        $$$ThrowOnError(tSC)
        set name=$zconvert(tResult.%Get("Name"),"l")
        set list($increment(list))=$listbuild(name,$zconvert(tResult.%Get("PinnedVersion"),"l")_"-pinned")
        if $length(name)>width set width=$length(name)
    }
    set list("width") = width
}

/// Pin Only Installed Modules
ClassMethod PinModule(pModule As %String = "") As %Status
{
    set pModule=$$$lcase(pModule)
    if ..IsModulePinned(pModule) {
        return $$$ERROR($$$GeneralError,"Module "_pModule_" already pinned")
    }
    &SQL(SELECT ID INTO :id FROM %IPM_Storage.ModuleItem where name=:pModule)
    if id = ""{
        return $$$ERROR($$$GeneralError,"Module "_pModule_" not found")
    }
    set moduleObj = ##class(%IPM.Storage.Module).%OpenId(id)
    set pinModule = ..%New()
    set pinModule.Name= moduleObj.Name
    set pinModule.PinnedVersion = moduleObj.VersionString
    set pinModule.PinnedAt = $zdatetime($ztimestamp,3)
    set pinModule.PinnedBy = $username
    set sc = pinModule.%Save()
    if $$$ISERR(sc) {
        return sc
    }
    return $$$OK
}

/// UnPin Only Installed Modules
ClassMethod UnPinModule(pModule As %String = "") As %Status
{
    set pModule = $$$lcase(pModule)
    if '..IsModulePinned(pModule) {
        return $$$ERROR($$$GeneralError,"Module "_pModule_" not currently pinned.")
    }
    return ..%DeleteId(pModule)
}

Storage Default
{
<Data name="PinnedModuleDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>PinnedVersion</Value>
</Value>
<Value name="3">
<Value>PinnedAt</Value>
</Value>
<Value name="4">
<Value>PinnedBy</Value>
</Value>
</Data>
<DataLocation>^IPM.Storage.PinnedModuleD</DataLocation>
<DefaultData>PinnedModuleDefaultData</DefaultData>
<IdLocation>^IPM.Storage.PinnedModuleD</IdLocation>
<IndexLocation>^IPM.Storage.PinnedModuleI</IndexLocation>
<StreamLocation>^IPM.Storage.PinnedModuleS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
