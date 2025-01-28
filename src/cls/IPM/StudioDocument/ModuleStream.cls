Class %IPM.StudioDocument.ModuleStream Extends %IPM.StudioDocument.AbstractStream
{

XData UpdateVersionTransform [ XMLNamespace = "http://www.intersystems.com/studio/document" ]
{
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:param name="replacement" select="'replacementValue'" />

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="Module/Version">
    <xsl:copy>
      <xsl:value-of select="$replacement" />
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
}

Parameter DEFAULTGLOBAL = "^IPM.StudioDoc.ModuleStream";

Method CompiledUpdateVersionXSLT(semver As %IPM.General.SemanticVersion) As %XML.XSLT.CompiledStyleSheet
{
	Set tXData = ##class(%Dictionary.CompiledXData).IDKEYOpen($ClassName(), "UpdateVersionTransform",,.tSC)
	$$$ThrowOnError(tSC)
	Set s = ""
	While 'tXData.Data.AtEnd {
		Set s = s _ tXData.Data.Read()
	}
	Set s = $REPLACE(s, "replacementValue", semver.ToString())
	Set stream = ##class(%Stream.TmpCharacter).%New()
	$$$ThrowOnError(stream.Write(s))
	$$$ThrowOnError(stream.Rewind())
	Set tSC = ##class(%XML.XSLT.CompiledStyleSheet).CreateFromStream(stream, .compiledStyleSheet)
	$$$ThrowOnError(tSC)

	Quit compiledStyleSheet
}

Method UpdateVersion(semver As %IPM.General.SemanticVersion)
{
	// Can't use %IPM.Repo.XSLTProvider because we need to pass a parameter
	Set compiledTransfrom = ..CompiledUpdateVersionXSLT(semver)

	$$$ThrowOnError(..Contents.Rewind())
	$$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(..Contents, compiledTransfrom, .updatedContents))
	$$$ThrowOnError(..Contents.Clear())
	$$$ThrowOnError(..Contents.CopyFrom(updatedContents))
	$$$ThrowOnError(..%Save())
}

Storage Default
{
<Data name="ModuleStreamDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Name</Value>
</Value>
<Value name="3">
<Value>Contents</Value>
</Value>
<Value name="4">
<Value>Hash</Value>
</Value>
<Value name="5">
<Value>LastModifiedTimestamp</Value>
</Value>
</Data>
<DataLocation>^IPM.StudioDoc.ModuleStreamD</DataLocation>
<DefaultData>ModuleStreamDefaultData</DefaultData>
<IdLocation>^IPM.StudioDoc.ModuleStreamD</IdLocation>
<IndexLocation>^IPM.StudioDoc.ModuleStreamI</IndexLocation>
<StreamLocation>^IPM.StudioDoc.ModuleStreamS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
