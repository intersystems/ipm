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

ClassMethod ManifestBuildValueArray(
	pDocument As %Library.Binary,
	ByRef pValueArray As %Library.Binary) As %Status
{
    #dim tKeywords,tXSLT As %Stream.Object
    set tSC = $$$OK
    try {
        set tDocument = $select(pDocument="":"",1:$classmethod($classname(),"ManifestOpen",pDocument))
        if '$isobject(tDocument) {
            quit
        }
        set tXData = ##class(%Dictionary.XDataDefinition).%OpenId($classname()_"||ManifestTransform",,.tSC)
        if $$$ISERR(tSC) {
            quit
        }
        set tXSL = tXData.Data
        set tSC = ##class(%XML.XSLT.Transformer).TransformStream(tDocument,tXSL,.tKeywords)
        if $$$ISERR(tSC) {
            quit
        }
        set tSC = ##class(%Text.English).BuildValueArray(tKeywords.Read($$$MaxStringLength),.pValueArray)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod CloneFrom(pSource As %IPM.Repo.Remote.ModuleInfo) As %IPM.Repo.Remote.ModuleInfo
{
    set tInst = ..%New()
    set tInst.Name = pSource.Name
    set tInst.Version = pSource.Version
    set tInst.PlatformVersion = pSource.PlatformVersion
    set tInst.Manifest = pSource.Manifest.%ConstructClone()
    set tInst.Payload = pSource.Payload.%ConstructClone()
    quit tInst
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
