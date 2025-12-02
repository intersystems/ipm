Class %IPM.Storage.ModuleTemplate Extends %IPM.Storage.Module
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleTemplate";

Property TemplateResources [ MultiDimensional ];

Property ModuleFolder As %String(XMLPROJECTION = "NONE");

/// Export Resources
/// Example: ExportList="00000,apptools.,apptools.M^00000,apptools.,apptools.M"
ClassMethod ExportResources(
	Path As %String = "",
	ExportList As %String = "") As %Status
{
    set st=$$$OK
    for i=1:1:$length(ExportList,"^") {
        set item=$piece(ExportList,"^",i)
        continue:item=""
        do ..ExportOneResource(Path,$piece(item,",",1),$piece(item,",",2),$piece(item,",",3))
    }
    quit st
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
ClassMethod ExportOneResource(
	workdir = "",
	flags,
	mask = "",
	ignoremask = "")
{
    ///zu(12) namespace directory by default
    if workdir="" {
        set workdir=##class(%File).NormalizeDirectory("")
    }
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

    write "#; Exporting to ", workdir,!
    #; classes
    set rs = ##class(%ResultSet).%New("%Dictionary.ClassDefinition:Summary")
    if rs.Execute() {
        while rs.%Next(){
            set code = rs.Name _ ".cls", isSystem = rs.System
            if ( '$extract(flags,2) && isSystem ) continue
            if ( '$extract(flags,1) && $$$isGenerated( code ) ) continue
            if ( '$extract(flags,3) && $$$isPercented( code ) ) continue
            if ( '$extract(flags,4) && $$$isMapped( code ) ) continue
            if mask'="",(("@"_code)'[("@"_mask )) continue
            if ignoremask'="",(("@"_code)[("@"_ignoremask )) continue

            set filename = ..Expfilename( code,workdir )
            $$$mkdir( filename )
            $$$log
            $$$export( code, filename )
            set item(code)=""
        } set rs=""
    }

    #; routines
    set rs = ##class(%ResultSet).%New("%Routine:RoutineList")
    if rs.Execute() {
        while rs.%Next() {
            set code = rs.Name
            if ( '$extract(flags,1) && $$$isGenerated( code ) ) continue
            if ( '$extract(flags,3) && $$$isPercented( code ) ) continue
            if ( '$extract(flags,4) && $$$isMapped( code ) ) continue
            if ( '$find( code, mask ) ) continue

            set filename = ..Expfilename( code,workdir )
            $$$mkdir( filename )
            $$$log
            $$$export( code, filename )
            set item(code)=""
        }
        set rs=""
    }
    #; dfi
    #define export(%code,%file) s sc = ##class(%DeepSee.UserLibrary.Utils).%Export( %code, %file, 0 )
    if '$extract(flags,5) {
        set sql = "Select fullName as Name From %DeepSee_UserLibrary.FolderItem"
        set rs = ##class(%SQL.Statement).%ExecDirect( .stm, sql )
        while rs.%Next() {
            set code = rs.Name
            set filename = ..Expfilename( code_".dfi",workdir )
            if ( '$find( code, mask ) ) continue
            if ($length(code,"$TRASH")>1) continue
            $$$mkdir( filename )
            $$$log
            $$$export(code,filename)
            set item(code)=""
        }
        set rs=""
    }
    write !!, "#; Exported to ", workdir
    quit $$$OK
}

/// test.dfi -> /dfi/test.dfi
/// test.cls -> /cls/test.cls
/// testpkg.test.cls -> /cls/testpkg/test.cls
ClassMethod Expfilename(
	code,
	wd)
{
    #define log(%dir,%sc) Write !, "mkdir ", %dir, " ", sc

    if '##class(%File).DirectoryExists( wd ) {
        set sc = ##class(%File).CreateDirectoryChain( wd )
        $$$log(wd,sc)
    }

    set ext = $piece( code, ".", * ), ext = $zconvert( ext, "l" )
    #; for each type - different directory

    set:ext'="" wd = ##class(%File).NormalizeDirectory( ext, wd )

    #; directory must exist before any call (%File).NormalizeFilename( , wd)
    if '##class(%File).DirectoryExists( wd ) {
        set sc = ##class(%File).CreateDirectoryChain( wd )
        $$$log(wd,sc)
    }

    set filename = ##class(%File).NormalizeFilename( code, wd )
    #; lowercase file extension
    set $piece(filename,".",*)=ext
    //B:code="DPRep.Rest.JSON.cls" "L"
    #; for *.cls Package.Subpackage.ClassName.cls -> Folder/Subfolder/ClassName.cls
    if (ext = "cls") {
        set dirs = $piece( code, ".",1, *-2 ), dirs = $translate( dirs, ".", "/" )
        set relpath = dirs _ "/" _ $piece( code, ".", *-1, * ) ;
        set filename = ##class(%File).NormalizeFilename( relpath, wd )
    }
    quit filename
}

/// returns list of non-system csp applications in the current namespace
ClassMethod GetCSPApplications(
	Output pApplications As %List,
	currentNamespace = {$namespace}) As %Status
{
    set pApplications = ""

    new $namespace
    set $namespace = "%SYS"
    set statement = ##class(%SQL.Statement).%New()
    set tSC = statement.%PrepareClassQuery("Security.Applications", "List")
    return:$$$ISERR(tSC) tSC
    set row = statement.%Execute("*")
    while row.%Next(.sc) {
        return:$$$ISERR(sc) sc
        if ( (row.%Get("Namespace")=currentNamespace) && (row.%Get("IsSystemApp") = 0) && (row.%Get("Type") = "CSP") ) {
            set pApplications = pApplications_$listbuild(row.%Get("Name"))
        }
    }
    return $$$OK
}

/// adds a web application to the temporary array of module resources
Method AddWebApps(
	pApps As %String,
	Output cspapps As %List,
	curns = {$namespace}) As %Status
{
    set tAppList = ""
    set pApps = $zstrip(pApps,"<>W")
    if ( pApps = "*" ) {
        do ..GetCSPApplications(.tAppList)
    } else {
        set tAppList = $listfromstring(pApps,",")
    }
    set cspapps = ""

    new $namespace
    set $namespace = "%SYS"
    set (matchRoles,dispatchClass,autheEnabled,path)=""
    for i=1:1:$listlength(tAppList) {
        set app = ##class(Security.Applications).Get($listget(tAppList,i), .props)
        if $$$ISOK(app) {
            set tAppName = props("Name")
            set matchRoles = props("MatchRoles")
            set autheEnabled = props("AutheEnabled")
            set dispatchClass = props("DispatchClass")
            set path = props("Path")
        } else {
            set tAppName = $listget(tAppList,i)
            set autheEnabled = $$$AuthePassword
        }
        set ..TemplateResources(tAppName) = tAppName
        set ..TemplateResources(tAppName, "Url") = tAppName
        if matchRoles["%DB_"_curns {
            set props("MatchRoles") = $replace(matchRoles,"%DB_"_curns,"{$dbrole}")
        }
        if (dispatchClass'="") {
            set ..TemplateResources(tAppName,"DispatchClass") = dispatchClass
        } else {
            set tCSPDir = ##class(%File).NormalizeDirectory(##class(%File).ParentDirectoryName(##class(%File).ManagerDirectory())_"/csp")
            set ..TemplateResources(tAppName,"Directory") = $replace(path,tCSPDir,"${cspdir}")
            set cspapps = cspapps_$listbuild(tAppName)
        }
        if ( autheEnabled = $$$AuthePassword ) {
            set ..TemplateResources(tAppName,"UnauthenticatedEnabled") = 0
            set ..TemplateResources(tAppName,"PasswordAuthEnabled") = 1
        } elseif ( autheEnabled = $$$AutheUnauthenticated ) {
            set ..TemplateResources(tAppName,"UnauthenticatedEnabled") = 1
            set ..TemplateResources(tAppName,"PasswordAuthEnabled") = 0
        } elseif ( autheEnabled = 96 ) {
            set ..TemplateResources(tAppName,"UnauthenticatedEnabled") = 1
            set ..TemplateResources(tAppName,"PasswordAuthEnabled") = 1
        } else {
            set ..TemplateResources(tAppName,"AuthenticationMethods") = autheEnabled
        }

        // Map subscript of application properties to %Installer.CSPApplication properties
        set tMap("AutoCompile") = "AutoCompile"
        set tMap("AutoCompile","default") = 1
        set tMap("Enabled") = "Enabled"
        set tMap("Enabled","default") = 1
        set tMap("ChangePasswordPage") = "ChangePasswordPage"
        set tMap("ErrorPage") = "CustomErrorPage"
        set tMap("SuperClass") = "DefaultSuperclass"
        set tMap("Timeout") = "DefaultTimeout"
        set tMap("Description") = "Description"
        set tMap("EventClass") = "EventClass"
        set tMap("MatchRoles") = "MatchRoles"
        set tMap("GroupById") = "GroupById"
        set tMap("InbndWebServicesEnabled") = "InboundWebServicesEnabled"
        set tMap("InbndWebServicesEnabled","default") = 1
        set tMap("IsNamespaceDefault") = "IsNamespaceDefault"
        set tMap("IsNamespaceDefault","default") = 0
        set tMap("LockCSPName") = "LockCSPName"
        set tMap("LockCSPName","default") = 1
        set tMap("LoginPage") = "LoginClass"
        set tMap("Package") = "PackageName"
        set tMap("CookiePath") = "CookiePath"
        set tMap("UseCookies") = "UseSessionCookie"
        set tMap("PermittedClasses") = "PermittedClasses"
        set tMap("Recurse") = "Recurse"
        set tMap("Recurse","default") = 0
        set tMap("Resource") = "Resource"
        set tMap("ServeFiles") = "ServeFiles"
        set tMap("ServeFilesTimeout") = "ServeFilesTimeout"
        set tMap("TwoFactorEnabled") = "TwoFactorEnabled"
        set tMap("TwoFactorEnabled","default") = 0

        set tAttr = ""
        for {
            set tAttr = $order(tMap(tAttr))
            quit:(tAttr="")
            continue:('$data(props(tAttr)))
            if (props(tAttr)'=$get(tMap(tAttr,"default"))) {
                set ..TemplateResources(tAppName,$get(tMap(tAttr)))=props(tAttr)
            }
        }
    }
    return $$$OK
}

Method SetSourcePathForCSPApp(
	pCSPApp,
	pPath) As %Status
{
    set ..TemplateResources(pCSPApp,"Path") = pPath
}

ClassMethod GetGlobalsList(Output globals As %List) As %Status
{
    set globals=""
    set statement = ##class(%SQL.Statement).%New()
    set tSC = statement.%PrepareClassQuery("%SYS.GlobalQuery", "NameSpaceList")
    return:$$$ISERR(tSC) tSC
    set row = statement.%Execute($namespace, "*", 0, , ,1,0)
    while row.%Next(.sc) {
        return:$$$ISERR(sc) sc
        set globals = globals_$listbuild(row.%Get("Name"))
    }
    return $$$OK
}

/// pSearchString - a mask, or comma-separated list of masks, to select globals
Method ReadGlobals(pSearchString As %String = "") As %Status
{
    if (pSearchString="") { return $$$OK }
    set statement = ##class(%SQL.Statement).%New()
    set tSC = statement.%PrepareClassQuery("%SYS.GlobalQuery", "NameSpaceList")
    return:$$$ISERR(tSC) tSC
    set row = statement.%Execute($namespace, pSearchString, 0, , ,1,0)
    while row.%Next(.sc) {
        return:$$$ISERR(sc) sc
        set ..TemplateResources("gbl"_row.%Get("Name")) = row.%Get("Name")
        set ..TemplateResources("gbl"_row.%Get("Name"),"Directory") = "gbl"
    }
    return $$$OK
}

/// add dependancy
Method AddDependant(pDependant As %String) As %Status
{
    set tName = $piece(pDependant,":",1)
    set tVersion = $piece(pDependant,":",2)
    if (tName="")||(tVersion="") { return $$$OK }
    set tModule = ##class(%IPM.Storage.ModuleReference).%New()
    set tModule.Name = tName
    do tModule.VersionStringSet(tVersion)
    return ..Dependencies.Insert(tModule)
}

/// creates a module.xml file with fictional data
ClassMethod GenerateTemplate(pPath As %String = "") As %Status
{
    return:(pPath="") $$$OK
    set tTemplate = ..%New()
    do tTemplate.SetTemplateProps()
    return tTemplate.SaveFile(pPath)
}

Method SetAuthorProps(
	pPerson As %String = "",
	pOrg As %String = "",
	pCopy As %String = "",
	pLicense As %String = "",
	pNotes As %String = "") As %Status
{
    set tAuthor = ##class(%IPM.Storage.ModuleAuthorInfo).%New()
    set tAuthor.Person = pPerson
    set tAuthor.Organization = pOrg
    set tAuthor.CopyrightDate = pCopy
    set tAuthor.License = pLicense
    set tAuthor.Notes = pNotes
    set ..Author = tAuthor
    return $$$OK
}

ClassMethod NewTemplate(
	pPath,
	pName,
	pVersion,
	pDescription = "",
	pKeywords = "") As %Status
{
    set tTemplate = ..%New()
    set tTemplate.ModuleFolder = ##class(%File).NormalizeDirectory(pPath)
    set tTemplate.Name = pName
    set tTemplate.VersionString = pVersion
    set tTemplate.Description = pDescription
    set tTemplate.Keywords = pKeywords
    set tTemplate.Packaging = "module"
    return tTemplate
}

Method ReadResources(pFolder) As %Status
{
    set exts = $listbuild("cls","mac","inc","int")
    if (($extract(pFolder,1)="/") || ($extract(pFolder,1)="\")) {
        set pFolder = $extract(pFolder,2,*)
    }
    set ..SourcesRoot = pFolder
    set tSC = ..ReadFolder(..ModuleFolder_pFolder, .files)
    return:$$$ISERR(tSC) tSC
    set tFile = ""
    for {
        set tFile = $order(files(tFile))
        quit:(tFile="")
        set tFileExt = $zconvert($piece( tFile, ".", * ),"l")
        if ('$listfind(exts,tFileExt)) {
            continue
        }
        set tSC = $system.OBJ.Load(tFile,"-d",,.tLoadedList,1)
        if $$$ISERR(tSC) {
            // Wasn't a valid file. We'll just continue.
            continue
        }

        set pDir = ""
        for i=##class(%File).GetDirectoryLength(..ModuleFolder_pFolder)+1:1:##class(%File).GetDirectoryLength(##class(%File).GetDirectory(tFile))-$length(tLoadedList,".")+2 {
            set pDir = pDir_"/"_##class(%File).GetDirectoryPiece(##class(%File).GetDirectory(tFile),i)
        }
        if (($extract(pDir,1)="/") || ($extract(pDir,1)="\")) {
            set pDir = $extract(pDir,2,*)
        }
        set ..TemplateResources(tFile) = tLoadedList
        if (pDir'="") {
            set ..TemplateResources(tFile,"Directory") = pDir
        }
    }

    // instead of classes individually use packages (.PKG)
    set key = ""
    kill resource
    for {
        set key = $order(..TemplateResources(key))
        quit:(key="")
        if ( "cls" = $zconvert($piece( ..TemplateResources(key), ".", * ),"l") ) {
            set pPath = ##class(%File).NormalizeDirectory(..ModuleFolder_pFolder)
            set pPKGName = $piece( ..TemplateResources(key), ".", 1 )
            if ( $data(resource(pPath_pPKGName)) && $get(resource(pPath_pPKGName, "Directory"))=$get(..TemplateResources(key,"Directory")) ) {
                merge resource(key) = ..TemplateResources(key)
            } else {
                set resource(pPath_pPKGName) = pPKGName_".PKG"
                if ($data(..TemplateResources(key,"Directory"))) {
                    set resource(pPath_pPKGName, "Directory") = ..TemplateResources(key,"Directory")
                }
            }
        } else {
            merge resource(key) = ..TemplateResources(key)
        }

    }
    kill ..TemplateResources
    merge ..TemplateResources = resource
    return $$$OK
}

Method ProcessResources()
{
    merge resources = ..TemplateResources
    set key = ""
    for {
        set key = $order(resources(key))
        quit:(key="")
        set resource = ##class(%IPM.Storage.ResourceReference).%New()
        set resource.Name = $get(resources(key),"resourceName")
        set att = ""
        for {
            set att = $order(resources(key,att))
            quit:(att="")
            do resource.Attributes.SetAt($get(resources(key,att),"value"),att)
        }
        set resource.Module = $this
    }
}

ClassMethod ReadFolder(
	pPath,
	ByRef files) As %Status
{
    set pPath =  ##class(%File).NormalizeDirectory(pPath)
    if '##class(%File).DirectoryExists(pPath) {
        return $$$ERROR(5001, "Directory "_pPath_" doesn't exist")
    }

    set statement = ##class(%SQL.Statement).%New()
    set tSC = statement.%PrepareClassQuery("%File", "FileSet")
    return:$$$ISERR(tSC) tSC
    set row = statement.%Execute(pPath)
    while row.%Next(.sc) {
        return:$$$ISERR(sc) sc
        if ( row.%Get("Type") = "D" ) {
            do ..ReadFolder(row.%Get("Name"), .files)
        } elseif ( row.%Get("Type") = "F" ) {
            set files(row.%Get("Name"))=""
        }
    }
    return $$$OK
}

Method SetTemplateProps() As %Status
{
    set ..Name = "template"
    set ..VersionString = "1.0.0"
    set ..Description = "description"
    set ..Keywords = "keywords"
    set ..Author = ##class(%IPM.Storage.ModuleAuthorInfo).%New()
    set ..Author.Person = "your name"
    set ..Author.Organization = "your organization"
    set ..Author.CopyrightDate = $piece($zdate($now(),3),"-")
    set ..Author.License = "MIT"
    set ..Author.Notes = "notes"

    set tModule = ##class(%IPM.Storage.ModuleReference).%New()
    set tModule.Name = "module"
    do tModule.VersionStringSet("1.*")
    do ..Dependencies.Insert(tModule)

    set ..Packaging = "module"
    set ..SourcesRoot = "src"

    set ..TemplateResources("inc") = "MyPackage.First.INC"
    set ..TemplateResources("inc","Directory")="inc"

    set ..TemplateResources("mac") = "MyPackage.FirstRoutine.MAC"
    set ..TemplateResources("mac","Directory") = "mac"

    set ..TemplateResources("cls") = "MyPackage.Demo.CLS"
    set ..TemplateResources("cls","Directory") = "cls"

    set ..TemplateResources("pkg") = "Sample.PKG"
    set ..TemplateResources("pkg","Directory") = "cls"

    set ..TemplateResources("gbl") = "MyApp.Settings.GBL"
    set ..TemplateResources("gbl","Directory") = "gbl"

    set ..TemplateResources("test") = "/tests/unit_tests/"
    set ..TemplateResources("test","Package") = "Test.Unit"
    set ..TemplateResources("test","Phase") = "test"

    // REST APP
    set ..TemplateResources("rest") = "/crud"
    set ..TemplateResources("rest","Url") = "/crud"
    set ..TemplateResources("rest","CookiePath") = "/crud"
    set ..TemplateResources("rest","UseCookies") = 2
    set ..TemplateResources("rest","DispatchClass") = "Sample.REST"
    set ..TemplateResources("rest","PasswordAuthEnabled") = 1
    set ..TemplateResources("rest","UnauthenticatedEnabled") = 0
    set ..TemplateResources("rest","Recurse") = 1

    // WEB APP
    set ..TemplateResources("web") = "/web"
    set ..TemplateResources("web","Url") = "/web"
    set ..TemplateResources("web","CookiePath") = "/web"
    set ..TemplateResources("web","UseCookies") = 2
    set ..TemplateResources("web","PasswordAuthEnabled") = 1
    set ..TemplateResources("web","UnauthenticatedEnabled") = 0
    set ..TemplateResources("web","Recurse") = 1
    set ..TemplateResources("web","ServeFiles") = 1
    set ..TemplateResources("web","Directory") = "{$cspdir}myapp"
    set ..TemplateResources("web","Path") = "/web"

    do ..ProcessResources()

    return $$$OK
}

Method SaveFile(pPath As %String = "") As %Status
{
    return:(pPath="") $$$OK
    // If pPath doesn't exists - create one
    if ('##class(%File).DirectoryExists(pPath)) {
        if ('##class(%File).CreateDirectoryChain(pPath)) {
            $$$ThrowStatus($$$ERROR(5001,"Error creating directory: "_pPath))
        }
    }

    set tFileName = pPath_"module.xml"
    // If module.xml already exists - rename old one
    if (##class(%File).Exists(tFileName)) {
        if ('##class(%File).Rename(tFileName,pPath_"module_"_##class(%PosixTime).CurrentUTCTimeStamp(6)_".xml")){
            $$$ThrowStatus($$$ERROR(5001,"error renaming existing file:"_tFileName))
        }
    }

    // save
    try {
        $$$ThrowOnError(..XMLExportToStream(.tStream))
        set tXSL=##class(%Dictionary.CompiledXData).%OpenId("%IPM.StudioDocument.Module||ExternalXSL").Data
        $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStream(tStream, tXSL, .tOutput))

        set tXSL = ##class(%Dictionary.CompiledXData).%OpenId(..%ClassName(1)_"||XSLT").Data
        $$$ThrowOnError(##class(%XML.XSLT.Transformer).TransformStream(tOutput, tXSL, .tXMLStream))

        set tSC = ##class(%XML.Document).GetDocumentFromStream(tXMLStream, .tDoc)

        set tXML = ##class(%XML.Writer).%New()
        set tXML.NoXMLDeclaration = 0
        set tXML.Indent = 2
        $$$ThrowOnError(tXML.OutputToFile(tFileName))
        $$$ThrowOnError(tXML.Document(tDoc))
        $$$ThrowOnError(tXML.EndDocument())
    } catch ex {
        $$$ThrowStatus($$$ERROR(5001,"Unable to save: "_tFileName))
    }
    quit $$$OK
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
