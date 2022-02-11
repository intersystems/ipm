Class %IPM.JSON.Generator Extends %JSON.Generator [ System = 2 ]
{

/// Generate code for getting the field value from a binary stream and storing in variable named data.
ClassMethod GenImportBinaryStream(class As %String, propertyMap As %List, indent As %String, isCollectionValue As %Integer) [ Internal ]
{
  Set property=$$$jsonproperty(propertyMap)
  
  // If present, then must be the expected JSON type
  $$$GENERATE(indent_"  If jsontype'=""string"" Goto %JSONImportError")
  // Get the field value
  // Code to use property stream
  $$$GENERATE(indent_"  Set stream=.."_$$$jsonpropertyQN(propertyMap)_" Do stream.Rewind()")
  $$$GENERATE(indent_"  Set tBase64=%JSONObject."_$$$QN($$$jsonfieldname(propertyMap)))
  $$$GENERATE(indent_"  Set tBase64=$Translate(tBase64, ""=""_$Char(10,13))")
  $$$GENERATE(indent_"  Set tLen=$Length(tBase64)")
  $$$GENERATE(indent_"  For i=1:1:tLen\30020+1 {")
  $$$GENERATE(indent_"    Set sc=stream.Write($system.Encryption.Base64Decode($Extract(tBase64, i-1*30020+1, i*30020))) If $$$ISERR(sc) Goto %JSONImportExit")
  $$$GENERATE(indent_"  }")
}

/// Generate code for exporting a binary stream as JSON.
ClassMethod GenExportBinaryStream(class As %String, propertyMap As %List, fieldName As %String, indent As %String, isCollectionValue As %Integer) [ Internal ]
{
  Do ..GenWriteField(fieldName,indent,"")
  $$$GENERATE(indent_"  "_%outputCode_"""""""""")
  $$$GENERATE(indent_" Do value.Rewind()")
  $$$GENERATE(indent_" If value.Size>0 { While 'value.AtEnd {")
  $$$GENERATE(indent_" "_%outputCode_"$system.Encryption.Base64Encode(value.Read(22515,.sc),1)")
  $$$GENERATE(indent_" If $$$ISERR(sc) Goto "_%exitCode_" }} "_%outputCode_"""""""""")
}

}
