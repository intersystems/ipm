Class %IPM.Repo.Remote.ModuleInfo Extends (%RegisteredObject, %IPM.General.ModuleInfo)
{

/// Since %IPM.General.ModuleInfo is XML enabled, XMLTYPEs of all its child classes must be able to differentiate from each other
/// So set it differently to avoid having the same XMLTYPE (default to be "ModuleInfo" taken from the classname) with %IPM.Storage.ModuleInfo 
Parameter XMLTYPE = "CoreModule";

Property Payload As %Stream.GlobalBinary(%JSONFIELDNAME = "package");

Property Manifest As %Stream.GlobalCharacterSearchable(%JSONFIELDNAME = "manifest", SIMILARITYINDEX = "ManifestSearchIndex");

Property Installer As %Stream.GlobalCharacterSearchable(%JSONFIELDNAME = "installer");

/// NOTE: Must be redeclared in subclasses (?)
Index ManifestSearchIndex On Manifest(KEYS) [ Data = Manifest(ELEMENTS) ];

ClassMethod ManifestBuildValueArray(pDocument As %Library.Binary, ByRef pValueArray As %Library.Binary) As %Status
{
	#dim tKeywords,tXSLT As %Stream.Object
	Set tSC = $$$OK
	Try {
		Set tDocument = $Select(pDocument="":"",1:$classmethod($classname(),"ManifestOpen",pDocument))
		If '$IsObject(tDocument) {
			Quit
		}
		Set tXData = ##class(%Dictionary.XDataDefinition).%OpenId($Classname()_"||ManifestTransform",,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tXSL = tXData.Data
		Set tSC = ##class(%XML.XSLT.Transformer).TransformStream(tDocument,tXSL,.tKeywords)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = ##class(%Text.English).BuildValueArray(tKeywords.Read($$$MaxStringLength),.pValueArray)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod CloneFrom(pSource As %IPM.Repo.Remote.ModuleInfo) As %IPM.Repo.Remote.ModuleInfo
{
	Set tInst = ..%New()
	Set tInst.Name = pSource.Name
	Set tInst.Version = pSource.Version
  Set tInst.PlatformVersion = pSource.PlatformVersion
	Set tInst.Manifest = pSource.Manifest.%ConstructClone()
	Set tInst.Payload = pSource.Payload.%ConstructClone()
	Quit tInst
}

XData ManifestTransform
{
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="text"/>
 <xsl:preserve-space elements="*" />
 <xsl:template match="/">
 <xsl:value-of select="concat(Module/Name,' ')" />
 <xsl:value-of select="concat(Module/ExternalName,' ')" />
 <xsl:value-of select="concat(Module/Description,' ')" />
 <xsl:value-of select="concat(Module/Keywords,' ')" />
 <xsl:value-of select="concat(Module/Author/*,' ')"/>
 </xsl:template>
</xsl:stylesheet>
}

}
