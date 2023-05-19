Class %IPM.Storage.ModuleTemplate Extends %IPM.Storage.Module
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleTemplate";

Property TemplateResources [ MultiDimensional ];

Property ModuleFolder As %String(XMLPROJECTION = "NONE");

/// Export Resources 
/// Example: ExportList="00000,apptools.,apptools.M^00000,apptools.,apptools.M"
ClassMethod ExportResources(Path As %String = "", ExportList As %String = "") As %Status
{
	Set st=$$$OK
		For i=1:1:$Length(ExportList,"^") { Set item=$Piece(ExportList,"^",i)
			Continue:item=""
			Do ..ExportOneResource(Path,$Piece(item,",",1),$Piece(item,",",2),$Piece(item,",",3))	
		}
	Quit st
}

/// Export different types of modules in different subfolders in UDL (plain) format
/// test.dfi -> /dfi/test.dfi
/// testpkg.test.cls -> /cls/testpkg/test.cls
/// Fork from https://github.com/intersystems-ru/cache-udl
/// d ##class(%IPM.Storage.ModuleTemplate).ExportOneResource("d:\_proj\app","00000","apptools.","apptools.M")
/// byte=1 isGenerated
/// byte=2 isSystem
/// byte=3 isPercented
/// byte=4 isMapped
/// byte=5 isDFI
ClassMethod ExportOneResource(workdir = "", flags, mask = "", ignoremask = "")
{
	///zu(12) namespace directory by default
	If workdir="" Set workdir=zu(12,"")
	#define export(%code, %file) Try {Set sc = $system.OBJ.ExportUDL(%code, %file,"/diffexport")} catch e {s sc=$$$ERROR($$$GeneralError,"Old version")} ##continue
								 Write:sc "Ok" Do:'sc $system.OBJ.DisplayError(sc)

	#define isGenerated(%code) ##class(%RoutineMgr).IsGenerated( %code )
	#define isPercented(%code) ("%" = $Extract(%code))
	#define isMapped(%code) ##class(%RoutineMgr).IsMapped( %code )
	#define log Write !, code, " -> ", $Piece(filename,workdir,2), " "
	
	#define mkdir(%filename) ##continue
			Set path = ##class(%File).GetDirectory( %filename ) ##continue
			If '##class(%File).DirectoryExists( path ) { ##continue
				Set sc = ##class(%File).CreateDirectoryChain( path ) ##continue
				Write !, "mkdir ", path, " ", sc ##continue
			}
						
	w "#; Exporting to ", workdir,!
	#; classes
	Set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:Summary")
	If rs.Execute() {

		While rs.%Next(){

			Set code = rs.Name _ ".cls", isSystem = rs.System
			If ( '$Extract(flags,2) && isSystem ) Continue
			If ( '$Extract(flags,1) && $$$isGenerated( code ) ) Continue
			If ( '$Extract(flags,3) && $$$isPercented( code ) ) Continue
			If ( '$Extract(flags,4) && $$$isMapped( code ) ) Continue
			If mask'="",(("@"_code)'[("@"_mask )) Continue
			If ignoremask'="",(("@"_code)[("@"_ignoremask )) Continue
			
			Set filename = ..Expfilename( code,workdir )
			$$$mkdir( filename )
			$$$log
			$$$export( code, filename )
			Set item(code)=""
		} Set rs=""
	}

	#; routines
	Set rs = ##class(%ResultSet).%New("%Routine:RoutineList")
	If rs.Execute() {
    	While rs.%Next() {
	 		Set code = rs.Name
	 		If ( '$e(flags,1) && $$$isGenerated( code ) ) Continue
	 		If ( '$e(flags,3) && $$$isPercented( code ) ) Continue
			If ( '$e(flags,4) && $$$isMapped( code ) ) Continue
			If ( '$find( code, mask ) ) Continue
			
			Set filename = ..Expfilename( code,workdir )
			$$$mkdir( filename )
			$$$log
			$$$export( code, filename )
			Set item(code)=""
	    } Set rs=""
	}
	#; dfi
	#define export(%code,%file) s sc = ##class(%DeepSee.UserLibrary.Utils).%Export( %code, %file, 0 ) 
	If '$Extract(flags,5) {
		Set sql = "Select fullName as Name From %DeepSee_UserLibrary.FolderItem"
	    Set rs = ##class(%SQL.Statement).%ExecDirect( .stm, sql )
	    While rs.%Next() {
			Set code = rs.Name, filename = ..Expfilename( code_".dfi",workdir )
			If ( '$Find( code, mask ) ) Continue
			If ($Length(code,"$TRASH")>1) Continue
			$$$mkdir( filename )
			$$$log
			$$$export(code,filename)
			Set item(code)=""
		} Set rs=""
	}
	Write !!, "#; Exported to ", workdir
    Quit $$$OK
}

/// test.dfi -> /dfi/test.dfi
/// test.cls -> /cls/test.cls
/// testpkg.test.cls -> /cls/testpkg/test.cls
ClassMethod Expfilename(code, wd)
{
	#define log(%dir,%sc) Write !, "mkdir ", %dir, " ", sc

	If '##class(%File).DirectoryExists( wd ) {
		Set sc = ##class(%File).CreateDirectoryChain( wd )
		$$$log(wd,sc)
	}

	Set ext = $Piece( code, ".", * ), ext = $Zconvert( ext, "l" )
	#; for each type - different directory

	Set:ext'="" wd = ##class(%File).NormalizeDirectory( ext, wd )

	#; directory must exist before any call (%File).NormalizeFilename( , wd)
	If '##class(%File).DirectoryExists( wd ) {
		Set sc = ##class(%File).CreateDirectoryChain( wd )
		$$$log(wd,sc)
	}

	Set filename = ##class(%File).NormalizeFilename( code, wd )
	#; lowercase file extension
	Set $Piece(filename,".",*)=ext
	//B:code="DPRep.Rest.JSON.cls" "L"
	#; for *.cls Package.Subpackage.ClassName.cls -> Folder/Subfolder/ClassName.cls
	If ext ="cls" {
		Set dirs = $Piece( code, ".",1, *-2 ), dirs = $Translate( dirs, ".", "/" )
		Set relpath = dirs _ "/" _ $Piece( code, ".", *-1, * ) ;
		Set filename = ##class(%File).NormalizeFilename( relpath, wd )
	}
	Quit filename
}

/// returns list of non-system csp applications in the current namespace
ClassMethod GetCSPApplications(Output pApplications As %List, currentNamespace = {$Namespace}) As %Status
{
    Set pApplications = ""

    New $Namespace
    Set $Namespace = "%SYS"
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%PrepareClassQuery("Security.Applications", "List")
    Return:$$$ISERR(tSC) tSC
    Set row = statement.%Execute("*")
    While row.%Next(.sc) {
        Return:$$$ISERR(sc) sc
        If ( (row.%Get("Namespace")=currentNamespace) && (row.%Get("IsSystemApp") = 0) && (row.%Get("Type") = "CSP") ) {
            Set pApplications = pApplications_$LB(row.%Get("Name"))
        }
    }
    return $$$OK
}

/// adds a web application to the temporary array of module resources
Method AddWebApps(pApps As %String, Output cspapps As %List, curns = {$Namespace}) As %Status
{
    Set tAppList = ""
    Set pApps = $ZSTRIP(pApps,"<>W")
    If ( pApps = "*" ) {
	    Do ..GetCSPApplications(.tAppList)
    } Else { 
        Set tAppList = $Listfromstring(pApps,",")
    }
    Set cspapps = ""

    New $Namespace
    Set $Namespace = "%SYS"
    For i=1:1:$Listlength(tAppList) {
        Set app = ##class(Security.Applications).Get($Listget(tAppList,i),.props)
        Set tAppName = props("Name")
        Set ..TemplateResources(tAppName) = tAppName
        Set ..TemplateResources(tAppName, "Url") = tAppName
        if props("MatchRoles")["%DB_"_curns {
	    Set props("MatchRoles") = $replace(props("MatchRoles"),"%DB_"_curns,"{$dbrole}")
        } 
        If (props("DispatchClass")'="") {
            Set ..TemplateResources(tAppName,"DispatchClass") = props("DispatchClass") 
        } Else {
            Set tCSPDir = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory())_"/csp")
            Set ..TemplateResources(tAppName,"Directory") = $Replace(props("Path"),tCSPDir,"${cspdir}")
            Set cspapps = cspapps_$Listbuild(tAppName)
            
        }
        If ( props("AutheEnabled") = 32 ) {
            Set ..TemplateResources(tAppName,"UnauthenticatedEnabled") = 0
            Set ..TemplateResources(tAppName,"PasswordAuthEnabled") = 1
        } ElseIf ( props("AutheEnabled") = 64 ) {
            Set ..TemplateResources(tAppName,"UnauthenticatedEnabled") = 0
            Set ..TemplateResources(tAppName,"PasswordAuthEnabled") = 1            
        } ElseIf ( props("AutheEnabled") = 96 ) {
            Set ..TemplateResources(tAppName,"UnauthenticatedEnabled") = 1
            Set ..TemplateResources(tAppName,"PasswordAuthEnabled") = 1            
        } Else {
            Set ..TemplateResources(tAppName,"AuthenticationMethods") = props("AutheEnabled")
        }

        // Map subscript of application properties to %Installer.CSPApplication properties 
        Set tMap("AutoCompile") = "AutoCompile"
        Set tMap("AutoCompile","default") = 1
        Set tMap("Enabled") = "Enabled"
        Set tMap("Enabled","default") = 1        
        Set tMap("ChangePasswordPage") = "ChangePasswordPage" 
        Set tMap("ErrorPage") = "CustomErrorPage" 
        Set tMap("SuperClass") = "DefaultSuperclass" 
        Set tMap("Timeout") = "DefaultTimeout" 
        Set tMap("Description") = "Description" 
        Set tMap("EventClass") = "EventClass" 
        Set tMap("MatchRoles") = "MatchRoles" 
        Set tMap("GroupById") = "GroupById" 
        Set tMap("InbndWebServicesEnabled") = "InboundWebServicesEnabled" 
        Set tMap("InbndWebServicesEnabled","default") = 1
        Set tMap("IsNamespaceDefault") = "IsNamespaceDefault" 
        Set tMap("IsNamespaceDefault","default") = 0
        Set tMap("LockCSPName") = "LockCSPName" 
        Set tMap("LockCSPName","default") = 1
        Set tMap("LoginPage") = "LoginClass" 
        Set tMap("Package") = "PackageName" 
        Set tMap("CookiePath") = "CookiePath" 
        Set tMap("UseCookies") = "UseSessionCookie" 
        Set tMap("PermittedClasses") = "PermittedClasses" 
        Set tMap("Recurse") = "Recurse" 
        Set tMap("Recurse","default") = 0
        Set tMap("Resource") = "Resource" 
        Set tMap("ServeFiles") = "ServeFiles" 
        Set tMap("ServeFilesTimeout") = "ServeFilesTimeout" 
        Set tMap("TwoFactorEnabled") = "TwoFactorEnabled" 
        Set tMap("TwoFactorEnabled","default") = 0

        Set tAttr = ""
        For {
            Set tAttr = $Order(tMap(tAttr))
            Quit:(tAttr="")
            Continue:('$Data(props(tAttr)))
            If (props(tAttr)'=$Get(tMap(tAttr,"default"))) {
                Set ..TemplateResources(tAppName,$Get(tMap(tAttr)))=props(tAttr)
            }
        }
    }
    Return $$$OK
}

Method SetSourcePathForCSPApp(pCSPApp, pPath) As %Status
{
    Set ..TemplateResources(pCSPApp,"Path") = pPath
}

ClassMethod GetGlobalsList(Output globals As %List) As %Status
{
    Set globals=""
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%PrepareClassQuery("%SYS.GlobalQuery", "NameSpaceList")
    Return:$$$ISERR(tSC) tSC
    Set row = statement.%Execute($Namespace, "*", 0, , ,1,0)
    While row.%Next(.sc) {
        Return:$$$ISERR(sc) sc
        Set globals = globals_$Listbuild(row.%Get("Name"))
    }
    Return $$$OK
}

/// pSearchString - a mask, or comma-separated list of masks, to select globals
Method ReadGlobals(pSearchString As %String = "") As %Status
{
    If (pSearchString="") { Return $$$OK }
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%PrepareClassQuery("%SYS.GlobalQuery", "NameSpaceList")
    Return:$$$ISERR(tSC) tSC
    Set row = statement.%Execute($Namespace, pSearchString, 0, , ,1,0)
    While row.%Next(.sc) {
        Return:$$$ISERR(sc) sc
        Set ..TemplateResources("gbl"_row.%Get("Name")) = row.%Get("Name")
        Set ..TemplateResources("gbl"_row.%Get("Name"),"Directory") = "gbl"
    }
    Return $$$OK
}

/// add dependancy
Method AddDependant(pDependant As %String) As %Status
{
    Set tName = $Piece(pDependant,":",1)
    Set tVersion = $Piece(pDependant,":",2)
    If (tName="")||(tVersion="") { Return $$$OK }
    Set tModule = ##class(%IPM.Storage.ModuleReference).%New()
    Set tModule.Name = tName
    Do tModule.VersionStringSet(tVersion)
    Return ..Dependencies.Insert(tModule)
}

/// creates a module.xml file with fictional data
ClassMethod GenerateTemplate(pPath As %String = "") As %Status
{
    Return:(pPath="") $$$OK 
    Set tTemplate = ..%New()
    Do tTemplate.SetTemplateProps()
    Return tTemplate.SaveFile(pPath)
}

Method SetAuthorProps(pPerson As %String = "", pOrg As %String = "", pCopy As %String = "", pLicense As %String = "", pNotes As %String = "") As %Status
{
    Set tAuthor = ##class(%IPM.Storage.ModuleAuthorInfo).%New()
    Set tAuthor.Person = pPerson
    Set tAuthor.Organization = pOrg
    Set tAuthor.CopyrightDate = pCopy
    Set tAuthor.License = pLicense
    Set tAuthor.Notes = pNotes
    Set ..Author = tAuthor
    Return $$$OK
}

ClassMethod NewTemplate(pPath, pName, pVersion, pDescription = "", pKeywords = "") As %Status
{
    Set tTemplate = ..%New()
    Set tTemplate.ModuleFolder = ##class(%File).NormalizeDirectory(pPath)
    Set tTemplate.Name = pName
    Set tTemplate.VersionString = pVersion
    Set tTemplate.Description = pDescription
    Set tTemplate.Keywords = pKeywords
    Set tTemplate.Packaging = "module"
    Return tTemplate
}

Method ReadResources(pFolder) As %Status
{
    Set exts = $Listbuild("cls","mac","inc","int")
    If (($Extract(pFolder,1)="/") || ($Extract(pFolder,1)="\")) {
        Set pFolder = $Extract(pFolder,2,*)
    }
    Set ..SourcesRoot = pFolder
    Set tSC = ..ReadFolder(..ModuleFolder_pFolder, .files)
    Return:$$$ISERR(tSC) tSC
    Set tFile = ""
    For {
        Set tFile = $Order(files(tFile))
        Quit:(tFile="")
        Set tFileExt = $zcvt($p( tFile, ".", * ),"l")
        If ('$Listfind(exts,tFileExt)) {
            Continue
        }
        Set tSC = $System.OBJ.Load(tFile,"-d",,.tLoadedList,1)
        If $$$ISERR(tSC) {
            // Wasn't a valid file. We'll just continue.
            Continue
        }
        
        Set pDir = ""
        for i=##class(%File).GetDirectoryLength(..ModuleFolder_pFolder)+1:1:##class(%File).GetDirectoryLength(##class(%File).GetDirectory(tFile))-$Length(tLoadedList,".")+2 {
            Set pDir = pDir_"/"_##class(%File).GetDirectoryPiece(##class(%File).GetDirectory(tFile),i)
        }
        If (($Extract(pDir,1)="/") || ($Extract(pDir,1)="\")) {
            Set pDir = $Extract(pDir,2,*)
        }
        Set ..TemplateResources(tFile) = tLoadedList
        If (pDir'="") {
            Set ..TemplateResources(tFile,"Directory") = pDir
        }          
    }

    // instead of classes individually use packages (.PKG)
    Set key = ""
    Kill resource
    For {
        Set key = $Order(..TemplateResources(key))
        Quit:(key="")
        If ( "cls" = $zcvt($p( ..TemplateResources(key), ".", * ),"l") ) {
            Set pPath = ##class(%File).NormalizeDirectory(..ModuleFolder_pFolder) 
            Set pPKGName = $p( ..TemplateResources(key), ".", 1 ) 
            If ( $Data(resource(pPath_pPKGName)) && $Get(resource(pPath_pPKGName, "Directory"))=$Get(..TemplateResources(key,"Directory")) ) {
                Merge resource(key) = ..TemplateResources(key)
            } Else {
                Set resource(pPath_pPKGName) = pPKGName_".PKG"
                If ($Data(..TemplateResources(key,"Directory"))) {
                    Set resource(pPath_pPKGName, "Directory") = ..TemplateResources(key,"Directory")
                }
            }
        } Else {
            Merge resource(key) = ..TemplateResources(key)
        }
        
    }
    kill ..TemplateResources
    Merge ..TemplateResources = resource
    Return $$$OK
}

Method ProcessResources()
{
    merge resources = ..TemplateResources
    Set key = ""
	For {
		Set key = $Order(resources(key))
		Quit:(key="")
		Set resource = ##class(%IPM.Storage.ResourceReference).%New()
		Set resource.Name = $Get(resources(key),"resourceName")
		Set att = ""
		For {
			Set att = $Order(resources(key,att))
			Quit:(att="")
			Do resource.Attributes.SetAt($Get(resources(key,att),"value"),att)
		}
		Set resource.Module = $this
	}
}

ClassMethod ReadFolder(pPath, ByRef files) As %Status
{
    Set pPath =  ##class(%File).NormalizeDirectory(pPath)   
    If '##class(%File).DirectoryExists(pPath) { Return $$$ERROR(5001, "Directory "_pPath_" doesn't exist") }
    
    Set statement = ##class(%SQL.Statement).%New()
    Set tSC = statement.%PrepareClassQuery("%File", "FileSet")
    Return:$$$ISERR(tSC) tSC
    Set row = statement.%Execute(pPath)
    While row.%Next(.sc) {
        Return:$$$ISERR(sc) sc
        If ( row.%Get("Type") = "D" ) {
            Do ..ReadFolder(row.%Get("Name"), .files)
        } ElseIf ( row.%Get("Type") = "F" ) {
            Set files(row.%Get("Name"))=""
        }
    }
    Return $$$OK
}

Method SetTemplateProps() As %Status
{
    Set ..Name = "template"
    Set ..VersionString = "1.0.0"
    Set ..Description = "description"
    Set ..Keywords = "keywords"
	Set ..Author = ##class(%IPM.Storage.ModuleAuthorInfo).%New()
	Set ..Author.Person = "your name"
	Set ..Author.Organization = "your organization"
	Set ..Author.CopyrightDate = $Piece($ZDate($Now(),3),"-")
	Set ..Author.License = "MIT"
	Set ..Author.Notes = "notes"

    Set tModule = ##class(%IPM.Storage.ModuleReference).%New()
    Set tModule.Name = "module"
    Do tModule.VersionStringSet("1.*")
    Do ..Dependencies.Insert(tModule)

    Set ..Packaging = "module"
    Set ..SourcesRoot = "src"

	Set ..TemplateResources("inc") = "MyPackage.First.INC"
	Set ..TemplateResources("inc","Directory")="inc"

	Set ..TemplateResources("mac") = "MyPackage.FirstRoutine.MAC"
	Set ..TemplateResources("mac","Directory") = "mac"

	Set ..TemplateResources("cls") = "MyPackage.Demo.CLS"
	Set ..TemplateResources("cls","Directory") = "cls"	

	Set ..TemplateResources("pkg") = "Sample.PKG"
	Set ..TemplateResources("pkg","Directory") = "cls"

    Set ..TemplateResources("gbl") = "MyApp.Settings.GBL"
    Set ..TemplateResources("gbl","Directory") = "gbl"

	Set ..TemplateResources("test") = "/tests/unit_tests/"
	Set ..TemplateResources("test","Package") = "Test.Unit"
	Set ..TemplateResources("test","Phase") = "test"

	// REST APP
	Set ..TemplateResources("rest") = "/crud"
	Set ..TemplateResources("rest","Url") = "/crud"
	Set ..TemplateResources("rest","CookiePath") = "/crud"
	Set ..TemplateResources("rest","UseCookies") = 2
	Set ..TemplateResources("rest","DispatchClass") = "Sample.REST"
	Set ..TemplateResources("rest","PasswordAuthEnabled") = 1
	Set ..TemplateResources("rest","UnauthenticatedEnabled") = 0
	Set ..TemplateResources("rest","Recurse") = 1

	// WEB APP
	Set ..TemplateResources("web") = "/web"
	Set ..TemplateResources("web","Url") = "/web"
	Set ..TemplateResources("web","CookiePath") = "/web"
	Set ..TemplateResources("web","UseCookies") = 2
	Set ..TemplateResources("web","PasswordAuthEnabled") = 1
	Set ..TemplateResources("web","UnauthenticatedEnabled") = 0
	Set ..TemplateResources("web","Recurse") = 1
	Set ..TemplateResources("web","ServeFiles") = 1
	Set ..TemplateResources("web","Directory") = "{$cspdir}myapp"
	Set ..TemplateResources("web","Path") = "/web"

    Do ..ProcessResources()

    Return $$$OK
}

Method SaveFile(pPath As %String = "") As %Status
{
    Return:(pPath="") $$$OK
    // If pPath doesn't exists - create one 
    If ('##class(%File).DirectoryExists(pPath)) {
        If ('##class(%File).CreateDirectoryChain(pPath)) {
            $$$ThrowStatus($$$ERROR(5001,"Error creating directory: "_pPath))
        }
    }

    Set tFileName = pPath_"module.xml"
    // If module.xml already exists - rename old one
	If (##class(%File).Exists(tFileName)) {
		If ('##class(%File).Rename(tFileName,pPath_"module_"_##class(%PosixTime).CurrentUTCTimeStamp(6)_".xml")){
			$$$ThrowStatus($$$ERROR(5001,"error renaming existing file:"_tFileName))
		}
	}

    // save 
    Try {
        $$$ThrowOnError(..XMLExportToStream(.tStream))
        Set tXSL=##class(%Dictionary.CompiledXData).%OpenId("%IPM.StudioDocument.Module||ExternalXSL").Data
        $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStream(tStream, tXSL, .tOutput))

        Set tXSL = ##class(%Dictionary.CompiledXData).%OpenId(..%ClassName(1)_"||XSLT").Data
        $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStream(tOutput, tXSL, .tXMLStream))

        Set tSC = ##class(%XML.Document).GetDocumentFromStream(tXMLStream, .tDoc)

	    Set tXML = ##class(%XML.Writer).%New()
        Set tXML.NoXMLDeclaration = 0
	    Set tXML.Indent = 2
        $$$ThrowOnError(tXML.OutputToFile(tFileName))
        $$$ThrowOnError(tXML.Document(tDoc))
        $$$ThrowOnError(tXML.EndDocument())
    } Catch ex {
        $$$ThrowStatus($$$ERROR(5001,"Unable to save: "_tFileName))
    }
	Quit $$$OK
}

XData XSLT
{
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output omit-xml-declaration="yes" method="xml" encoding="utf-8" indent="yes" />
  <xsl:strip-space elements="*" />

  <xsl:template match="/ModuleTemplate">
    <Export generator="Cache" version="25"> 
        <Document>
            <xsl:attribute name="name"><xsl:value-of select="Name" />.ZPM</xsl:attribute>
            <Module>
                <xsl:apply-templates select="*" />
            </Module>
        </Document>
    </Export>
  </xsl:template>
  <xsl:template match="Resource[@Url]">
    <CSPApplication>
        <xsl:apply-templates select="@*[local-name() != 'Name']" />
    </CSPApplication>
  </xsl:template>
  <xsl:template match="node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*">
    <xsl:choose>
		<xsl:when test="(name()='Directory') and (.!='') and ../@Url"><xsl:attribute name="DeployPath"><xsl:value-of select="." /></xsl:attribute></xsl:when>   
        <xsl:when test="(name()='Directory') and (.='')"></xsl:when>   
 		<xsl:when test="name()='Path'"><xsl:attribute name="SourcePath"><xsl:value-of select="." /></xsl:attribute></xsl:when>
        <xsl:otherwise><xsl:copy></xsl:copy></xsl:otherwise>
    </xsl:choose>
  </xsl:template>
</xsl:stylesheet>
}

Storage Default
{
<Data name="ModuleTemplateDefaultData">
<Subscript>"ModuleTemplate"</Subscript>
<Value name="1">
<Value>ModuleFolder</Value>
</Value>
</Data>
<DefaultData>ModuleTemplateDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
