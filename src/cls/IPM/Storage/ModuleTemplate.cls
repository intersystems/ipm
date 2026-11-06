Class %IPM.Storage.ModuleTemplate Extends %IPM.Storage.Module
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleTemplate";

Property TemplateResources [ MultiDimensional ];

Property ModuleFolder As %String(MAXLEN = "", XMLPROJECTION = "NONE");

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

/// Adds the named web applications (comma-separated, or * for all of them in the namespace) as WebApplication resources.
/// <var>cspapps</var> returns the ones that serve files from a Path instead of having a dispatch class.
Method AddWebApps(
	pApps As %String,
	Output cspapps As %List,
	curns = {$namespace}) As %Status
{
    set tAppList = ""
    set pApps = $zstrip(pApps,"<>W")
    if (pApps = "*") {
        do ..GetCSPApplications(.tAppList)
    } else {
        set tAppList = $listfromstring(pApps,",")
    }
    set cspapps = ""
    set cspDir = ##class(%File).NormalizeDirectory("csp", $system.Util.InstallDirectory())

    new $namespace
    set $namespace = curns
    set dbRole = ##class(%IPM.Utils.Module).GetDatabaseRole()
    set $namespace = "%SYS"

    // WebApplication creates the app with Security.Applications defaults, so only values that differ need writing
    set defaults = ##class(Security.Applications).%New()
    set properties = $listbuild("AutoCompile", "ChangePasswordPage", "CookiePath", "Description", "DispatchClass", "Enabled", "ErrorPage", "EventClass", "GroupById", "InbndWebServicesEnabled", "LockCSPName", "LoginPage", "MatchRoles", "Package", "PermittedClasses", "Recurse", "Resource", "ServeFiles", "ServeFilesTimeout", "SuperClass", "Timeout", "TwoFactorEnabled", "UseCookies")
    set appPointer = 0
    while $listnext(tAppList, appPointer, appName) {
        kill props
        if $$$ISERR(##class(Security.Applications).Get(appName, .props)) {
            kill props
            set props("AutheEnabled") = $$$AutheCache
        }
        set ..TemplateResources(appName) = appName
        set ..TemplateResources(appName, "ProcessorClass") = "WebApplication"
        // Always written, even at its default, so readers of module.xml can see how the app authenticates
        set ..TemplateResources(appName, "AutheEnabled") = $get(props("AutheEnabled"), defaults.AutheEnabled)
        if $get(props("MatchRoles")) '= "" {
            set props("MatchRoles") = ..ReplaceRole(props("MatchRoles"), dbRole, "{$globalsDbRole}")
        }
        if ($get(props("DispatchClass")) = "") && ($get(props("Path")) '= "") {
            set ..TemplateResources(appName, "Path") = $replace(props("Path"), cspDir, "{$cspdir}")
            set cspapps = cspapps_$listbuild(appName)
        }
        set propertyPointer = 0
        while $listnext(properties, propertyPointer, property) {
            if $data(props(property), value) && (value '= $property(defaults, property)) {
                set ..TemplateResources(appName, property) = value
            }
        }
    }
    return $$$OK
}

/// Replaces each whole <var>role</var> in <var>matchRoles</var>, a Security.Applications MatchRoles value, e.g.
/// <example>ReplaceRole(":%DB_APP:%DB_APPDATA", "%DB_APP", "{$globalsDbRole}") -> ":{$globalsDbRole}:%DB_APPDATA"</example>
ClassMethod ReplaceRole(
	matchRoles As %String,
	role As %String,
	replacement As %String) As %String
{
    for i=1:1:$length(matchRoles, ",") {
        set entry = $piece(matchRoles, ",", i)
        for j=1:1:$length(entry, ":") {
            if ($piece(entry, ":", j) = role) {
                set $piece(entry, ":", j) = replacement
            }
        }
        set $piece(matchRoles, ",", i) = entry
    }
    return matchRoles
}

/// Adds a FileCopy resource that deploys <var>pPath</var>, relative to the module root, to the Path of CSP application <var>pCSPApp</var>
Method SetSourcePathForCSPApp(
	pCSPApp,
	pPath) As %Status
{
    set key = "files:"_pCSPApp
    set ..TemplateResources(key) = ..RelativeFolder(pPath)_"/"
    set ..TemplateResources(key, "ProcessorClass") = "FileCopy"
    set ..TemplateResources(key, "Target") = $get(..TemplateResources(pCSPApp, "Path"))
    return $$$OK
}

Method DefineReminWebAppProps(ByRef props)
{
    //add cors origin details
    set props("CorsAllowlist") = ""
    set props("CorsCredentialsAllowed") = 0
    // add cors headers
    set props("CorsHeadersList") = ""
    set props("DeepSeeEnabled") = 0
    set props("JWTAuthEnabled") = 0
    set props("JWTRefreshTokenTimeout") = 900
    set props("JWTAccessTokenTimeout") = 60
    set props("WSGIAppLocation") = ""
    set props("WSGIAppName") = ""
    set props("WSGICallable") = ""
    set props("WSGIDebug") = ""
    set props("WSGIType") = ""
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

Method SetCORSProps(
	apps As %String = "",
	ByRef cors)
{
    set appList = ""
    set apps = $zstrip(apps,"<>W")
    if (apps = "*") {
        $$$ThrowOnError(..GetCSPApplications(.appList))
    } else {
        set appList = $listfromstring(apps,",")
    }
    set ptr = 0
    while $listnext(appList, ptr, webpApp) {
        set ..TemplateResources(webpApp,"CorsCredentialsAllowed") = cors("enableCors")
        set ..TemplateResources(webpApp,"CorsHeadersList") = cors("allowedHeaders")
        set ..TemplateResources(webpApp,"CorsAllowlist") = cors("allowedOrigins")
    }
}

Method SetJWTProps(
	apps As %String = "",
	ByRef jwt)
{
    set appList = ""
    set apps = $zstrip(apps,"<>W")
    if (apps = "*") {
        $$$ThrowOnError(..GetCSPApplications(.appList))
    } else {
        set appList = $listfromstring(apps,",")
    }
    set ptr = 0
    while $listnext(appList, ptr, webpApp) {
        set ..TemplateResources(webpApp,"JWTAccessTokenTimeout") = jwt("JWTAccessTokenTO")
        set ..TemplateResources(webpApp,"JWTAuthEnabled") = jwt("enableJWT")
        set ..TemplateResources(webpApp,"JWTRefreshTokenTimeout") = jwt("JWTRefreshTokenTO")
    }
}

Method ValidateCorsOrigin(pAllowedOrigins As %String = "") As %Status
{
    new $namespace
    set $namespace = "%SYS"
    set originsList = $listfromstring(pAllowedOrigins,",")
    set ptr = 0
    set sc = $$$OK
    while $listnext(originsList, ptr, origin){
        set sc = ##class(Security.Applications).ValidateCorsOrigin(origin)
        if $$$ISERR(sc) quit
    }
    return sc
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

/// Adds the source files under <var>pFolder</var>, relative to the module folder, as resources, with one .PKG per directory
/// and top-level package. Classes under <var>testsFolder</var>, if it exists, become UnitTest resources instead, e.g.
/// <example language="xml"><UnitTest Name="/tests/unit_tests/" Package="MyApp.Test" Phase="test"/></example>
Method ReadResources(
	pFolder,
	testsFolder As %String = "")
{
    set pFolder = ..RelativeFolder(pFolder)
    set ..SourcesRoot = pFolder
    set testsFolder = ..RelativeFolder(testsFolder)
    set testsDir = $select(testsFolder="":"", 1:##class(%File).NormalizeDirectory(testsFolder, ..ModuleFolder))
    do ..ReadItems(pFolder, .items, testsDir)
    do ..GroupClasses(.items, .packages)
    merge ..TemplateResources = items
    do ..AddPackages(.packages)

    if (testsDir '= "") && ##class(%File).DirectoryExists(testsDir) {
        do ..ReadItems(testsFolder, .testItems)
        do ..GroupClasses(.testItems, .testPackages)
        do ..AddPackages(.testPackages, testsFolder)
    }
}

/// Adds a resource for each package in <var>packages</var>, as grouped by <method>GroupClasses</method>.
/// Each is a .PKG, or a UnitTest if the classes came from <var>testsFolder</var>.
Method AddPackages(
	ByRef packages,
	testsFolder As %String = "")
{
    set directoryKey = ""
    for {
        set directoryKey = $order(packages(directoryKey))
        quit:directoryKey=""
        set directory = $extract(directoryKey, 2, *)
        set topLevel = ""
        for {
            set topLevel = $order(packages(directoryKey, topLevel), 1, package)
            quit:topLevel=""
            if (testsFolder = "") {
                set key = "pkg:"_directoryKey_":"_package
                set ..TemplateResources(key) = package_".PKG"
                if (directory '= "") {
                    set ..TemplateResources(key, "Directory") = directory
                }
            } else {
                set key = "test:"_directoryKey_":"_package
                set ..TemplateResources(key) = "/"_..RelativeFolder(testsFolder_directoryKey)_"/"
                set ..TemplateResources(key, "ProcessorClass") = "UnitTest"
                set ..TemplateResources(key, "Package") = package
                set ..TemplateResources(key, "Phase") = "test"
            }
        }
    }
}

/// Returns <var>folder</var> with forward slashes and without leading or trailing ones, e.g. "\tests\" -> "tests"
ClassMethod RelativeFolder(folder As %String) As %String
{
    return $zstrip($translate(folder, "\", "/"), "<>", "/")
}

/// Lists the ObjectScript source files under <var>folder</var>, relative to the module folder, skipping any under <var>excludeDir</var>.
/// <var>items</var>(file) is the item the file holds, e.g. "MyApp.Util.Helper.cls", and <var>items</var>(file, "Directory") is
/// the directory, relative to <var>folder</var>, that the item's package path starts in, e.g. "cls" for cls/MyApp/Util/Helper.cls.
Method ReadItems(
	folder As %String,
	Output items,
	excludeDir As %String = "")
{
    kill items
    set exts = $listbuild("cls","mac","inc","int")
    $$$ThrowOnError(..ReadFolder(..ModuleFolder_folder, .files))
    set tFile = ""
    for {
        set tFile = $order(files(tFile))
        quit:(tFile="")
        set tFileExt = $zconvert($piece( tFile, ".", * ),"l")
        if ('$listfind(exts,tFileExt)) {
            continue
        }
        if (excludeDir '= "") && ($extract(tFile, 1, $length(excludeDir)) = excludeDir) {
            continue
        }
        set tSC = $system.OBJ.Load(tFile,"-d",,.tLoadedList,1)
        if $$$ISERR(tSC) {
            // Wasn't a valid file. We'll just continue.
            continue
        }

        set pDir = ""
        for i=##class(%File).GetDirectoryLength(..ModuleFolder_folder)+1:1:##class(%File).GetDirectoryLength(##class(%File).GetDirectory(tFile))-$length(tLoadedList,".")+2 {
            set pDir = pDir_"/"_##class(%File).GetDirectoryPiece(##class(%File).GetDirectory(tFile),i)
        }
        if (($extract(pDir,1)="/") || ($extract(pDir,1)="\")) {
            set pDir = $extract(pDir,2,*)
        }
        set items(tFile) = tLoadedList
        if (pDir'="") {
            set items(tFile,"Directory") = pDir
        }
    }
}

/// Moves the classes out of <var>items</var>, as listed by <method>ReadItems</method>, into <var>packages</var>, which holds
/// the deepest package that a directory's classes under one top-level package share:
/// <var>packages</var>("/"_directory, topLevelPackage) = package. Classes without a package stay in <var>items</var>.
ClassMethod GroupClasses(
	ByRef items,
	Output packages)
{
    kill packages
    set file = ""
    for {
        set file = $order(items(file), 1, item)
        quit:file=""
        continue:$zconvert($piece(item, ".", *), "l")'="cls"
        set package = $piece(item, ".", 1, *-2)
        continue:package=""
        // Prefix the directory so a class root at the folder itself ("") is still a valid subscript
        set directoryKey = "/"_$get(items(file, "Directory"))
        set topLevel = $piece(package, ".")
        if $data(packages(directoryKey, topLevel), shared) {
            set package = ..SharedPackage(shared, package)
        }
        set packages(directoryKey, topLevel) = package
        kill items(file)
    }
}

/// Returns the longest package that contains both <var>first</var> and <var>second</var>, e.g. "A.B.C" and "A.B.D" -> "A.B"
ClassMethod SharedPackage(
	first As %String,
	second As %String) As %String
{
    set shared = ""
    for i=1:1:$length(first, ".") {
        quit:$piece(first, ".", i)'=$piece(second, ".", i)
        set shared = $piece(first, ".", 1, i)
    }
    return shared
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
        set resource.ProcessorClass = $get(resources(key,"ProcessorClass"))
        set att = ""
        for {
            set att = $order(resources(key,att))
            quit:(att="")
            continue:att="ProcessorClass"
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
    set ..TemplateResources("test","ProcessorClass") = "UnitTest"
    set ..TemplateResources("test","Package") = "Test.Unit"
    set ..TemplateResources("test","Phase") = "test"

    // REST APP
    set ..TemplateResources("rest") = "/crud"
    set ..TemplateResources("rest","ProcessorClass") = "WebApplication"
    set ..TemplateResources("rest","CookiePath") = "/crud"
    set ..TemplateResources("rest","UseCookies") = 2
    set ..TemplateResources("rest","DispatchClass") = "Sample.REST"
    set ..TemplateResources("rest","AutheEnabled") = $$$AutheCache
    set ..TemplateResources("rest","Recurse") = 1

    //CORS
    set ..TemplateResources("rest","CorsAllowlist") = "http://www.example.com"
    set ..TemplateResources("rest","CorsCredentialsAllowed") = 1
    set ..TemplateResources("rest","CorsHeadersList") = "Access-Control-Allow-Origin, Access-Control-Allow-Methods, Access-Control-Allow-Headers, Access-Control-Allow-Credentials, Access-Control-Max-Age, Access-Control-Expose-Headers, Origin, Access-Control-Request-Method, Access-Control-Request-Headers"

    // WEB APP
    set ..TemplateResources("web") = "/web"
    set ..TemplateResources("web","ProcessorClass") = "WebApplication"
    set ..TemplateResources("web","CookiePath") = "/web"
    set ..TemplateResources("web","UseCookies") = 2
    set ..TemplateResources("web","AutheEnabled") = $$$AutheCache
    set ..TemplateResources("web","Recurse") = 1
    set ..TemplateResources("web","ServeFiles") = 1
    set ..TemplateResources("web","Path") = "{$cspdir}myapp/"

    // Static files for the WEB APP
    set ..TemplateResources("webfiles") = "web/"
    set ..TemplateResources("webfiles","ProcessorClass") = "FileCopy"
    set ..TemplateResources("webfiles","Target") = "{$cspdir}myapp/"

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
  <xsl:template match="node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>
  <xsl:template match="@*">
    <xsl:choose>
        <xsl:when test="name()='ProcessorClass'"></xsl:when>
        <xsl:when test="(name()='Directory') and (.='')"></xsl:when>
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
