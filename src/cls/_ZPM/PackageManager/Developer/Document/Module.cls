Include (%ZPM.PackageManager.Common, %occErrors)

Class %ZPM.PackageManager.Developer.Document.Module Extends %ZPM.PackageManager.Developer.Document.AbstractDocument
{

Projection RegisterExtension As %Projection.StudioDocument(DocumentDescription = "Application Module", DocumentExtension = "ZPM", DocumentNew = 1, DocumentType = "xml", XMLNamespace = "http://www.intersystems.com/PackageManager");

Parameter EXTENSION = ".ZPM";

Parameter INFOGLOBAL = "^ZPM.Dev.Doc.Module";

/// Load the module definition <property>Name</property> into the stream <property>Code</property>
Method Load() As %Status
{
	$$$SuspendErrorCount
	Set tSC = $$$OK
	Try {
		Set tSC = ..%ValidateName(..Name)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tName = $Piece(..Name,".",1,*-1)
		Set tModStream = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameOpen(tName,,.tSC)
		If $$$ISERR(tSC) && ($Piece($System.Status.GetErrorCodes(tSC),",") = $$$KeyValueNotFoundOpen) {
			Set tSC = $$$OK
			
			// Fall back to direct rendering of XML from persistent object
			Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tName,,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			
			Do ..Code.WriteLine("<?xml version=""1.0""?>")
			Set tSC = tModule.XMLExportToStream(..Code,,"literal,indent")
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tSC = ..Code.CopyFrom(tModStream.Contents)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Save the module definition document.
Method Save() As %Status
{
	Set tName = ..Name
	Set tSC = ..ImportStream(.tName,..Code)
	If $$$ISERR(tSC) {
		Quit tSC
	}
	Set ..Name = tName
	Quit ..Load()
}

ClassMethod UpdatePersistentFromStream(pStream As %ZPM.PackageManager.Developer.Document.ModuleStream, Output pModule As %ZPM.PackageManager.Developer.Module) As %Status
{
	Set tSC = $$$OK
	Set pModule = $$$NULLOREF
	Try {
		New $$$ZPMStudioDocumentModule
		If ##class(%ZPM.PackageManager.Developer.Module).NameExists(pStream.Name) {
			Set pModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pStream.Name,,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set pModule = ##class(%ZPM.PackageManager.Developer.Module).%New()
		}
		
		If (pStream.Contents.Size = 0) {
			Set pModule.Name = pStream.Name
			Set pModule.VersionString = "0.0.1+snapshot"
		} Else {
			Set tReader = ##class(%XML.Reader).%New()
			Do pStream.Contents.Rewind()
			Set tSC = tReader.OpenStream(pStream.Contents)
			If $$$ISERR(tSC) {
				Quit
			}
			
			// Dependencies and Resources will be re-populated upon import.
			Do pModule.Dependencies.Clear()
			Do pModule.Resources.Clear()
			Do pModule.Defaults.Clear()
			Do pModule.Mappings.Clear()
			Do pModule.API.Clear()
			Do pModule.Invokes.Clear()
			
			If (pModule.%Id() '= "") {
				// Save to prevent unique index violations on re-insert of things that weren't actually removed.
				// At some point a more robust approach would be to match existing items in collections/relationships by such unique indices.
				Set tSC = pModule.%Save()
				If $$$ISERR(tSC) {
					Quit
				}
			}
			
			Set $$$ZPMStudioDocumentModule = pModule //Stash for use in %ZPM.PackageManager.Developer.Module:XMLNew
			Do tReader.Correlate("Module","%ZPM.PackageManager.Developer.Module")
			Do tReader.Next(.tModule,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
			
			If (pStream.Name '= pModule.Name) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module document name '%1' and module name in manifest '%2' must be the same.",pStream.Name,tModule.Name))
				Quit
			}
		}
		
		Set tSC = pModule.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnCompileDocument(ByRef qstruct As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tNameNoExt = $Piece(..Name,".",1,*-1)
		Set tModStream = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameOpen(tNameNoExt,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Do tModStream.Contents.Clear()
		Set tSC = tModStream.Contents.CopyFrom(..Code)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..UpdatePersistentFromStream(tModStream,.tModule)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set ..Name = tModule.Name_..#EXTENSION
		
		Set tSC = tModule.%Compile()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set @..#INFOGLOBAL@("compile",tModStream.Name) = $zdt($zts,3)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Save the module definition document from stream to database.
ClassMethod ImportStream(pName As %String, pStream As %GlobalCharacterStream) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tSC = ..%ValidateName(pName)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tName = $Piece(pName,".",1,*-1)
		If ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameExists(tName) {
			Set tModStream = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameOpen(tName,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tModStream = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).%New()
			Set tModStream.Name = tName
		}
		
		Do tModStream.Contents.Clear()
		Do pStream.Rewind()
		While '(pStream.AtEnd) {
			Set tSC = tModStream.Contents.Write(pStream.Read(16000))
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		TSTART
		Set tSC = tModStream.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..UpdatePersistentFromStream(tModStream,.tModule)
		If $$$ISERR(tSC) {
			Quit
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

/// Delete the module definition <var>name</var>.
ClassMethod Delete(name As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ..%ValidateName(name)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameDelete($Piece(name,".",1,*-1))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Return the timestamp of schema category 'name' in %TimeStamp format, i.e. $zdatetime($horolog,3).
/// This is used to determine if the category has been updated on the server and so needs reloading into Studio.
/// So the format should be $zdatetime($horolog,3), or "" if the category does not exist.
ClassMethod TimeStamp(name As %String) As %TimeStamp [ SqlProc ]
{
	If '..%ValidateName(name) {
		Quit ""
	}
	
	Set tStamp = ""
	Set tNameNoExt = $Piece(name,".",1,*-1)
	Set tModStream = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameOpen(tNameNoExt)
	If $IsObject(tModStream) {
		Set tStamp = tModStream.LastModifiedTimestamp
	} Else {
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(tNameNoExt)
		If $IsObject(tModule) {
			Set tStamp = tModule.LastModifiedTimestamp
		}
	}
	Quit tStamp
}

/// Return 1 if the given document exists and 0 if it does not.
ClassMethod Exists(name As %String) As %Boolean
{
	Set tExists = 0
	Try {
		Set tSC = ..%ValidateName(name)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tName = $Piece(name,".",1,*-1)
		Set tExists = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameExists(tName)
			|| ##class(%ZPM.PackageManager.Developer.Module).NameExists(tName)
	} Catch e {
		Set tExists = 0
	}
	Quit tExists
}

/// Subclasses must override
Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
	select Name, LastModifiedTimestamp from %ZPM_PackageManager_Developer_Document.ModuleStream
	union
	select Name, LastModifiedTimestamp from %ZPM_PackageManager_Developer."Module"
		where Name not in (select Name from %ZPM_PackageManager_Developer_Document.ModuleStream)
}

/// Lock the current routine, default method just unlocks the ^ROUTINE global with the name of the routine.
/// If it fails then return a status code of the error, otherise return $$$OK
Method Lock(flags As %String) As %Status
{
	Set tSC = $$$OK
	If ..Locked Set ..Locked=..Locked+1 Quit $$$OK
	If ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameExists($Piece(..Name,".",1,*-1),.tID) {
		Set tSC = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).%LockId(tID)
	}
	Set ..Locked=1
	Quit tSC
}

/// Unlock the current routine, default method just unlocks the ^ROUTINE global with the name of the routine
Method Unlock(flags As %String) As %Status
{
	Set tSC = $$$OK
	If ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameExists($Piece(..Name,".",1,*-1),.tID) {
		Set tSC = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).%UnlockId(tID)
	}
	Quit tSC
}

/// Export this document to the current device in XML format
Method ExportToXML(flags As %String) As %Status
{
	Set tXSL=##class(%Dictionary.CompiledXData).%OpenId(..%ClassName(1)_"||ExternalXSL").Data

	Set tSC = ##class(%XML.XSLT.Transformer).TransformStream(..Code, tXSL, .tOutput)
	If $$$ISERR(tSC) Quit tSC
	
	Set tSC = ##class(%XML.Document).GetDocumentFromStream(tOutput, .tDoc)
	If $$$ISERR(tSC) Quit tSC
	Set tXML = ##class(%XML.Writer).%New()
	Set tXML.NoXMLDeclaration = 1
	Set tXML.Indent = 2
	Set tSC = tXML.Document(tDoc)
	If $$$ISERR(tSC) Quit tSC
	Do tXML.OutputToDevice()
	Quit $$$OK
}

/// Import from the stream in XML format
Method ImportFromXML(stream As %RegisteredObject, flags As %String) As %Status
{
	Set tXSL = ##class(%Dictionary.CompiledXData).%OpenId(..%ClassName(1)_"||InternalXSL").Data

	Set tSC = ##class(%XML.XSLT.Transformer).TransformStream(stream, tXSL, .tOutput)
	If $$$ISERR(tSC) Quit tSC
	
	Do ..Code.Clear()
	#; Do ..Code.WriteLine("<?xml version=""1.0""?>") //add XML header
	Do ..Code.CopyFrom(tOutput)

	Quit $$$OK
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
