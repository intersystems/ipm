Include (%IPM.Common, %occErrors)

Class %IPM.StudioDocument.Module Extends %IPM.StudioDocument.Abstract
{

Projection RegisterExtension As %IPM.StudioDocument.Projection(DocumentDescription = "Application Module", DocumentExtension = "ZPM", DocumentNew = 1, DocumentType = "xml", XMLNamespace = "http://www.intersystems.com/PackageManager");

Parameter EXTENSION = ".ZPM";

Parameter INFOGLOBAL = "^IPM.StuDoc.Module";

Parameter STREAMCLASS = "%IPM.StudioDocument.ModuleStream";

/// Save the module definition document.
Method Save() As %Status
{
    set tName = ..Name
    set tSC = ..ImportStream(.tName,..Code)
    if $$$ISERR(tSC) {
        quit tSC
    }
    set ..Name = tName
    quit ..Load()
}

ClassMethod UpdatePersistentFromStream(
	pStream As %IPM.StudioDocument.ModuleStream,
	Output pModule As %IPM.Storage.Module) As %Status
{
    set tSC = $$$OK
    set pModule = $$$NULLOREF
    try {
        new $$$ZPMStudioDocumentModule
        new $$$ZPMDeferModifyResources
        set $$$ZPMDeferModifyResources = 1
        if ##class(%IPM.Storage.Module).NameExists(pStream.Name) {
            set pModule = ##class(%IPM.Storage.Module).NameOpen(pStream.Name,,.tSC)
            if $$$ISERR(tSC) {
                quit
            }
        } else {
            set pModule = ##class(%IPM.Storage.Module).%New()
        }

        if (pStream.Contents.Size = 0) {
            set pModule.Name = pStream.Name
            set pModule.VersionString = "0.0.1+snapshot"
        } else {
            set tReader = ##class(%XML.Reader).%New()
            do pStream.Contents.Rewind()
            // Preprocess the pStream contents to apply InternalXSL
            set tXSL = ##class(%Dictionary.CompiledXData).%OpenId(..%ClassName(1)_"||InternalXSL").Data
            set tTransformedStream = ##class(%Stream.GlobalCharacter).%New()
            set tTransformedStream.LineTerminator = $char(10)
            set tSC = ##class(%XML.XSLT.Transformer).TransformStream(pStream.Contents, tXSL, .tTransformedStream)
            if $$$ISERR(tSC) {
                quit
            }

            set tSC = tReader.OpenStream(tTransformedStream)
            if $$$ISERR(tSC) {
                quit
            }

            // Dependencies and Resources will be re-populated upon import.
            do pModule.Dependencies.Clear()
            do pModule.Resources.Clear()
            do pModule.Defaults.Clear()
            do pModule.Mappings.Clear()
            do pModule.Invokes.Clear()

            if (pModule.%Id() '= "") {
                // Save to prevent unique index violations on re-insert of things that weren't actually removed.
                // At some point a more robust approach would be to match existing items in collections/relationships by such unique indices.
                set tSC = pModule.%Save()
                if $$$ISERR(tSC) {
                    quit
                }
            }

            set $$$ZPMStudioDocumentModule = pModule //Stash for use in %IPM.Storage.Module:XMLNew
            do tReader.Correlate("Module","%IPM.Storage.Module")
            do tReader.Next(.pModule,.tSC)
            if $$$ISERR(tSC) {
                quit
            }

            if ($$$lcase(pStream.Name) '= $$$lcase(pModule.Name)) {
                set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module document name '%1' and module name in manifest '%2' must be the same.",pStream.Name,pModule.Name))
                quit
            }
        }

        set tSC = pModule.%Save()
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ##class(%IPM.ExtensionBase.SourceControl.Interface).%OnModifyResources(pModule)
        if $$$ISERR(tSC) {
            quit
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method OnCompileDocument(ByRef qstruct As %String) As %Status
{
    #dim tModule As %IPM.Storage.Module
    #dim tGeneralSettings As %IPM.General.Settings
    set tSC = $$$OK
    try {
        set tNameNoExt = $piece(..Name,".",1,*-1)
        set tModStream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen(tNameNoExt,,.tSC)
        $$$ThrowOnError(tSC)

        do tModStream.Contents.Clear()
        set tSC = tModStream.Contents.CopyFrom(..Code)
        $$$ThrowOnError(tSC)
        set tSC = tModStream.%Save()
        $$$ThrowOnError(tSC)

        set tSC = ..UpdatePersistentFromStream(tModStream,.tModule)
        $$$ThrowOnError(tSC)

        set ..Name = tModule.Name_..#EXTENSION

        // Determine whether to suppress compilation from settings
        set tGeneralSettings = ##class(%IPM.General.Settings).%Get(.tSC)
        $$$ThrowOnError(tSC)
        set tSuppressCompilation = tGeneralSettings.SuppressCompilation
        if tSuppressCompilation {
            write !, "Module compilation suppressed due to user settings."
        } else {
            set tSC = tModule.%Compile(.qstruct)
            $$$ThrowOnError(tSC)
        }

        set @..#INFOGLOBAL@("compile",tModStream.Name) = $zdatetime($ztimestamp,3)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Save the module definition document from stream to database.
ClassMethod ImportStream(
	pName As %String,
	pStream As %GlobalCharacterStream) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        set tSC = ..%ValidateName(pName)
        if $$$ISERR(tSC) {
            quit
        }

        set tName = $piece(pName,".",1,*-1)
        if ##class(%IPM.StudioDocument.ModuleStream).NameExists(tName) {
            set tModStream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen(tName,.tSC)
            if $$$ISERR(tSC) {
                quit
            }
        } else {
            set tModStream = ##class(%IPM.StudioDocument.ModuleStream).%New()
            set tModStream.Name = tName
        }

        do tModStream.Contents.Clear()
        do pStream.Rewind()
        while '(pStream.AtEnd) {
            set tSC = tModStream.Contents.Write(pStream.Read(16000))
            if $$$ISERR(tSC) {
                quit
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        tstart
        set tSC = tModStream.%Save()
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ..UpdatePersistentFromStream(tModStream,.tModule)
        if $$$ISERR(tSC) {
            quit
        }
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

/// Delete the module definition <var>name</var>.
ClassMethod Delete(name As %String) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        set tSC = ..%ValidateName(name)
        $$$ThrowOnError(tSC)

        set tModuleName = $piece(name,".",1,*-1)
        tstart
        set tSC = ##class(%IPM.StudioDocument.ModuleStream).NameDelete(tModuleName)
        $$$ThrowOnError(tSC)
        set tSC = ##class(%IPM.Storage.Module).NameDelete(tModuleName)
        $$$ThrowOnError(tSC)
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

/// Return the timestamp of schema category 'name' in %TimeStamp format, i.e. $zdatetime($horolog,3).
/// This is used to determine if the category has been updated on the server and so needs reloading into Studio.
/// So the format should be $zdatetime($horolog,3), or "" if the category does not exist.
ClassMethod TimeStamp(name As %String) As %TimeStamp [ SqlProc ]
{
    if '..%ValidateName(name) {
        quit ""
    }

    set tStamp = ""
    set tNameNoExt = $piece(name,".",1,*-1)
    set tModStream = ##class(%IPM.StudioDocument.ModuleStream).NameOpen(tNameNoExt)
    if $isobject(tModStream) {
        set tStamp = tModStream.LastModifiedTimestamp
    } else {
        set tModule = ##class(%IPM.Storage.Module).NameOpen(tNameNoExt)
        if $isobject(tModule) {
            set tStamp = tModule.LastModifiedTimestamp
        }
    }
    quit tStamp
}

/// Return 1 if the given document exists and 0 if it does not.
ClassMethod Exists(name As %String) As %Boolean
{
    set tExists = 0
    try {
        set tSC = ..%ValidateName(name)
        if $$$ISERR(tSC) {
            quit
        }
        set tName = $piece(name,".",1,*-1)
        set tExists = ##class(%IPM.StudioDocument.ModuleStream).NameExists(tName)
                        || ##class(%IPM.Storage.Module).NameExists(tName)
    } catch e {
        set tExists = 0
    }
    quit tExists
}

/// Subclasses must override
Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
    select Name, LastModifiedTimestamp from %IPM_StudioDocument.ModuleStream
    union
    select Name, LastModifiedTimestamp from %IPM_Storage.ModuleItem
        where Name not in (select Name from %IPM_StudioDocument.ModuleStream)
}

/// Returns a comma-separated list of *individual* resources listed in the module manifest.
/// This does not include packages or CSP/filesystem resources.
ClassMethod GetOther(Name As %String) As %String
{
    set tOtherDocs = ""
    try {
        set tExt = $piece(Name,".",*)
        if (tExt = "ZPM") {
            set tModuleName = $piece(Name,".",1,*-1)
            set tResources = ##class(%SQL.Statement).%ExecDirect(,
                "select UniqueName from %IPM_Storage.ResourceReference where ""Module""->Name = ?",
                tModuleName)
            if (tResources.%SQLCODE < 0) {
                throw ##class(%Exception.SQL).CreateFromSQLCODE(tResources.%SQLCODE,tResources.%Message)
            }
            while (tResources.%Next(.tSC)) {
                $$$ThrowOnError(tSC)
                set tName = tResources.%Get("UniqueName")
                if (tName = "") || ($extract(tName) = "/") {
                    // Skip CSP/filesystem resources, and resources without a corresponding server document name.
                    continue
                }
                set tExt = $piece(tName,".",*)
                if (tExt = "PKG") {
                    // Cannot open packages directly.
                    // Perhaps we could call ResolveChildren or expand these if there's interest.
                    continue
                }
                set tOtherDocs = tOtherDocs _ $listbuild(tName)
            }
            $$$ThrowOnError(tSC)
        }
    } catch e {
        set tOtherDocs = ""
        // No way to report exceptions, so just Log it.
        do e.Log()
    }
    quit $listtostring(tOtherDocs)
}

/// Export this document to the current device in XML format
Method ExportToXML(flags As %String) As %Status
{
    if ('..Code.Size) {
        quit $$$OK
    }
    set tXSL=##class(%Dictionary.CompiledXData).%OpenId(..%ClassName(1)_"||ExternalXSL").Data

    set tSC = ##class(%XML.XSLT.Transformer).TransformStream(..Code, tXSL, .tOutput)
    if $$$ISERR(tSC) {
        quit tSC
    }

    set tSC = ##class(%XML.Document).GetDocumentFromStream(tOutput, .tDoc)
    if $$$ISERR(tSC) {
        quit tSC
    }
    set tXML = ##class(%XML.Writer).%New()
    set tXML.NoXMLDeclaration = 1
    set tXML.Indent = 2
    set tSC = tXML.Document(tDoc)
    if $$$ISERR(tSC) {
        quit tSC
    }
    do tXML.OutputToDevice()
    quit $$$OK
}

/// Import from the stream in XML format
Method ImportFromXML(
	stream As %RegisteredObject,
	flags As %String) As %Status
{
    if ('stream.Size) {
        quit $$$OK
    }
    do ..Code.Clear()
    do ..Code.Write("<?xml version=""1.0""?>")
    do ..Code.CopyFrom(stream)
    quit $$$OK
}

/// XSLT to replace the top-level module version with a new value
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

/// Returns a compiled XSLT to update a module's version to the specified <var>semver</var> in its XML representation
ClassMethod CompiledUpdateVersionXSLT(semver As %IPM.General.SemanticVersion) As %XML.XSLT.CompiledStyleSheet
{
    set tXData = ##class(%Dictionary.CompiledXData).IDKEYOpen($classname(), "UpdateVersionTransform",,.tSC)
    $$$ThrowOnError(tSC)
    set s = ""
    while 'tXData.Data.AtEnd {
        set s = s _ tXData.Data.Read()
    }
    set s = $replace(s, "replacementValue", semver.ToString())
    set stream = ##class(%Stream.TmpCharacter).%New()
    $$$ThrowOnError(stream.Write(s))
    $$$ThrowOnError(stream.Rewind())
    set tSC = ##class(%XML.XSLT.CompiledStyleSheet).CreateFromStream(stream, .compiledStyleSheet)
    $$$ThrowOnError(tSC)

    quit compiledStyleSheet
}

/// Updates the version of <var>moduleName</var> to <var>semver</var>
ClassMethod UpdateVersion(
	moduleName As %String,
	semver As %IPM.General.SemanticVersion)
{
    // Can't use %IPM.Repo.XSLTProvider because we need to pass a parameter
    set compiledTransform = ..CompiledUpdateVersionXSLT(semver)
    set document = ##class(%Library.RoutineMgr).%OpenId(moduleName_".ZPM")
    if '$isobject(document) {
        // %Library.RoutineMgr:%OpenId doesn't have a byref status arg.
        $$$ThrowStatus($get(%objlasterror,$$$ERROR($$$GeneralError,"Unknown error occurred.")))
    }

    $$$ThrowOnError(document.Code.Rewind())
    $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(document.Code, compiledTransform, .updatedContents))
    $$$ThrowOnError(document.Code.Clear())
    $$$ThrowOnError(document.Code.CopyFrom(updatedContents))
    $$$ThrowOnError(document.%Save())
}

/// XSLT to add Python Wheel resources
XData AppendWheelUnderModuleTransform [ XMLNamespace = "http://www.intersystems.com/studio/document" ]
{
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:param name="wheelName" select="'replacementWheelName'"/>

  <xsl:template match="@*|node()">
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
  </xsl:template>

  <!-- Append a wheel under /Module/Version -->
  <xsl:template match="*[local-name()='Module']/*[local-name()='Version']">
    <xsl:variable name="ns" select="namespace-uri(..)"/>
    <xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy>
    <xsl:element name="PythonWheel" namespace="{$ns}">
      <xsl:element name="Name" namespace="{$ns}">
        <xsl:value-of select="$wheelName"/>
      </xsl:element>
    </xsl:element>

  </xsl:template>
</xsl:stylesheet>
}

/// Compile AppendWheelUnderModuleTransform with concrete values
ClassMethod CompileAppendWheelUnderModuleXSLT(wheelName As %String) As %XML.XSLT.CompiledStyleSheet
{
    set xData = ##class(%Dictionary.CompiledXData).IDKEYOpen($classname(),"AppendWheelUnderModuleTransform",,.sc)
    $$$ThrowOnError(sc)
    set baseStream = ""
    while 'xData.Data.AtEnd {
        set baseStream = baseStream _ xData.Data.Read()
    }
    set baseStream = $replace(baseStream, "replacementWheelName", wheelName)
    set stream = ##class(%Stream.TmpCharacter).%New()
    $$$ThrowOnError(stream.Write(baseStream))
    $$$ThrowOnError(stream.Rewind())
    set sc = ##class(%XML.XSLT.CompiledStyleSheet).CreateFromStream(stream, .compiledStyleSheet)
    $$$ThrowOnError(sc)
    quit compiledStyleSheet
}

/// Append Python Wheel resources to module.xml
ClassMethod AddPythonWheels(
	moduleName As %String,
	wheelName As %String)
{
    // Can't use %IPM.Repo.XSLTProvider because we need to pass a parameter
    set compiledTransform = ..CompileAppendWheelUnderModuleXSLT(wheelName)
    set document = ##class(%Library.RoutineMgr).%OpenId(moduleName_".ZPM")
    if '$isobject(document) {
        // %Library.RoutineMgr:%OpenId doesn't have a byref status arg.
        $$$ThrowStatus($get(%objlasterror,$$$ERROR($$$GeneralError,"Unable to open "_moduleName_".ZPM")))
    }
    $$$ThrowOnError(document.Code.Rewind())
    set sc = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(document.Code, compiledTransform, .updatedContents)
    $$$ThrowOnError(document.Code.Clear())
    $$$ThrowOnError(document.Code.CopyFrom(updatedContents))
    $$$ThrowOnError(document.%Save())
}

XData ExternalXSL
{
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" method="xml" encoding="utf-8" indent="yes" />
  <xsl:strip-space elements="*" />
  <xsl:template match="Resources">
    <xsl:apply-templates select="*" />
  </xsl:template>
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>
  <xsl:template name="resource">
    <xsl:copy-of select="@*"/>
    <xsl:for-each select="*">
      <xsl:attribute name="{@Name}">
        <xsl:value-of select="text()" />
      </xsl:attribute>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="Resource[@ProcessorClass]">
    <xsl:element name="{@ProcessorClass}">
      <xsl:attribute name="Name">
        <xsl:value-of select="@Name" />
      </xsl:attribute>
      <xsl:call-template name="resource" />
    </xsl:element>
  </xsl:template>
  <xsl:template match="Resource[not(@ProcessorClass)]">
    <xsl:element name="Resource">
      <xsl:call-template name="resource" />
    </xsl:element>
  </xsl:template>
  <xsl:template match="Module/LifecycleClass[text()='Module']"/>
  <xsl:template match="Module/Packaging[text()='module']"/>
  <xsl:template match="Module/Deployed[text()='false']"/>
</xsl:stylesheet>
}

XData InternalXSL
{
<xsl:stylesheet version="1.0" xmlns:ext="http://exslt.org/common" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" method="xml" encoding="utf-8" indent="yes" />
  <xsl:strip-space elements="*" />

  <xsl:variable name="vrtfPass1">
    <xsl:apply-templates />
  </xsl:variable>
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*|node()" mode="pass2">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" mode="pass2" />
    </xsl:copy>
  </xsl:template>
  <xsl:template name="attributes">
    <xsl:param name="except" />
    <xsl:for-each select="@*">
      <xsl:element name="Attribute">
        <xsl:attribute name="Name">
          <xsl:choose>
            <xsl:when test="name()='SourcePath'">Path</xsl:when>
            <xsl:when test="name()='DeployPath'">Directory</xsl:when>
            <xsl:otherwise><xsl:value-of select="name()" /></xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:value-of select="." />
      </xsl:element>
    </xsl:for-each>
  </xsl:template>
  <xsl:template name="resource">
    <xsl:param name="name" />
    <xsl:element name="Resource">
      <xsl:copy-of select="@*"/>
      <xsl:if test="not(name()='Resource')">
        <xsl:attribute name="ProcessorClass">
          <xsl:value-of select="name()" />
        </xsl:attribute>
      </xsl:if>
      <xsl:attribute name="Name">
        <xsl:value-of select="@*[name()=$name]" />
      </xsl:attribute>
      <xsl:call-template name="attributes">
        <xsl:with-param name="except" select="$name" />
      </xsl:call-template>
    </xsl:element>
  </xsl:template>
  <xsl:template match="Resources">
    <xsl:apply-templates select="*" />
  </xsl:template>
  <xsl:template match="Module/*[@Name]">
    <xsl:call-template name="resource">
      <xsl:with-param name="name" select="'Name'" />
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="Module/*[@Path]">
    <xsl:call-template name="resource">
      <xsl:with-param name="name" select="'Path'" />
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="Module/*[@SourcePath]">
    <xsl:call-template name="resource">
      <xsl:with-param name="name" select="'SourcePath'" />
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="Module/*[@Url and not(@SourcePath) and not(@Path) and not(@Name)]">
    <xsl:call-template name="resource">
      <xsl:with-param name="name" select="'Url'" />
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="Module/Invoke">
    <xsl:element name="Invokes">
      <xsl:copy-of select="." />
    </xsl:element>
  </xsl:template>
  <xsl:template match="Module/Mapping">
    <xsl:element name="Mappings">
      <xsl:copy-of select="." />
    </xsl:element>
  </xsl:template>
  <xsl:template match="Module/Default|Module/Parameter">
    <xsl:element name="Defaults">
      <xsl:element name="Default">
        <xsl:copy-of select="./@*" />
      </xsl:element>
    </xsl:element>
  </xsl:template>
  <xsl:template match="Module/Resource">
    <xsl:call-template name="resource">
      <xsl:with-param name="name" select="'Name'" />
    </xsl:call-template>
  </xsl:template>
  <xsl:template match="Module" mode="pass2">
    <xsl:copy>
      <xsl:apply-templates select="./@*" mode="pass2" />
      <xsl:apply-templates mode="pass2" />
      <xsl:element name="Resources">
        <xsl:for-each select="Resource">
          <xsl:copy-of select="." />
        </xsl:for-each>
      </xsl:element>
    </xsl:copy>
  </xsl:template>
  <xsl:template match="Resource" mode="pass2"></xsl:template>
  <xsl:template match="/">
    <xsl:apply-templates select="ext:node-set($vrtfPass1)/*" mode="pass2" />
  </xsl:template>
</xsl:stylesheet>
}

}
