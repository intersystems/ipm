Include %IPM.Common

/// Builds the summary that the show command prints for one installed module.
Class %IPM.General.ModuleSummary
{

/// Writes the summary of moduleName, an installed module in the current namespace.
/// moduleName may be the module's Name or ExternalName, in any case.
ClassMethod Show(moduleName As %String)
{
    if ##class(%IPM.Storage.Module).NameExists(moduleName) {
        set module = ##class(%IPM.Storage.Module).NameOpen(moduleName, , .sc)
    } elseif ##class(%IPM.Storage.Module).ExternalNameExists(moduleName) {
        set module = ##class(%IPM.Storage.Module).ExternalNameOpen(moduleName, , .sc)
    } else {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Module '%1' is not installed in namespace %2.", moduleName, $namespace)))
    }
    $$$ThrowOnError(sc)
    set installedVersions = {}
    for i = 1:1:module.Dependencies.Count() {
        set dependency = module.Dependencies.GetAt(i)
        set installed = ##class(%IPM.Storage.Module).NameOpen(dependency.Name)
        if $isobject(installed) {
            do installedVersions.%Set($zconvert(dependency.Name, "L"), installed.VersionString)
        }
    }
    set lines = ..GetLines(module, installedVersions, ..GetDirectDependents(module.Name))
    set iterator = lines.%GetIterator()
    while iterator.%GetNext(, .line) {
        write !, line
    }
}

/// Returns the installed modules that declare moduleName as an unscoped dependency, as {"name":..., "version":...} objects.
ClassMethod GetDirectDependents(moduleName As %String) As %DynamicArray [ Private ]
{
    set dependents = []
    set query = "SELECT ModuleItem->Name AS Name, ModuleItem->VersionString AS VersionString FROM %IPM_Storage.ModuleItem_Dependencies WHERE Dependencies_Name = ? AND (Dependencies_Scope IS NULL OR Dependencies_Scope = '') ORDER BY ModuleItem->Name"
    set rs = ##class(%SQL.Statement).%ExecDirect(, query, moduleName)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        do dependents.%Push({"name": (rs.%Get("Name")), "version": (rs.%Get("VersionString"))})
    }
    $$$ThrowOnError(sc)
    return dependents
}

/// Returns the show output for module, one line per element.
/// installedVersions maps each lowercased dependency name to its installed version, e.g. {"fslog":"1.0.3"}.
/// requiredBy lists the installed modules that directly depend on module, e.g. [{"name":"other-app","version":"2.0.0"}].
ClassMethod GetLines(
	module As %IPM.Storage.Module,
	installedVersions As %DynamicObject,
	requiredBy As %DynamicArray) As %DynamicArray
{
    set lines = []
    if (module.ExternalName '= "") && (module.ExternalName '= module.Name) {
        do lines.%Push(module.ExternalName _ " (" _ module.Name _ ") " _ module.VersionString)
    } else {
        do lines.%Push(module.Name _ " " _ module.VersionString)
    }
    // Description text keeps the line breaks and indentation of module.xml, so fold it onto one line.
    do ..AddField(lines, "Description", $zstrip($translate(module.Description, $char(10, 13), "  "), "<=>W"))
    do ..AddField(lines, "Root", module.Root)
    do ..AddField(lines, "Mode", $select(module.DeveloperMode: "developer", module.Deployed: "deployed", 1: ""))
    do ..AddField(lines, "Repository", module.Repository)
    do ..AddField(lines, "Last updated", module.LastUpdated)

    set usage = []
    do ..AddList(usage, "After install:", ..SplitLines(module.AfterInstallMessage))
    set defaults = []
    for i = 1:1:module.Defaults.Count() {
        set setting = module.Defaults.GetAt(i)
        if setting.%IsA("%IPM.Storage.ModuleSetting.Default") {
            do defaults.%Push(setting.Name _ " = " _ setting.Value)
        }
    }
    do ..AddList(usage, "Defaults", defaults)
    do ..AddBlock(lines, usage)

    set sections = {"code":[], "globals":[], "webapps":[], "files":[], "settings":[], "python":[], "other":[]}
    set wheels = []
    set key = ""
    for {
        set resource = module.Resources.GetNext(.key)
        quit:key=""
        set section = ..GetSection(resource)
        set name = resource.Name
        if (section = "globals") {
            do sections.globals.%Push("^" _ $piece(name, ".", 1, *-1))
        } elseif (section = "webapps") {
            set url = ..GetAttribute(resource, "Url", "Name")
            do sections.webapps.%Push([($select(url = "": name, 1: url)), (..GetWebApplicationDetail(resource))])
        } elseif (section = "files") {
            set target = ..GetAttribute(resource, "Target", "Dest", "InstallDirectory")
            do sections.files.%Push([(name), ($select(target = "": "", 1: "-> " _ target))])
        } elseif (section = "settings") {
            set settingName = ..GetAttribute(resource, "Name")
            do sections.settings.%Push($select(settingName = "": name, 1: settingName) _ " = " _ ..GetAttribute(resource, "Value"))
        } elseif (section = "python") {
            // Saving uppercases the stored name's extension. The Name attribute keeps the real filename.
            set wheel = ..GetAttribute(resource, "Name")
            do wheels.%Push($select(wheel = "": name, 1: wheel))
        } elseif (section = "other") {
            set shortName = ..GetShortName(resource.ResolvedProcessorClass())
            do sections.other.%Push([(name), ($select(shortName = "": "", 1: "(" _ shortName _ ")"))])
        } elseif (section '= "") {
            do sections.%Get(section).%Push(name)
        }
    }
    set requirements = ..GetRequirements(module.Root)
    if requirements.%Size() {
        do sections.python.%Push("requirements.txt: " _ ..Join(requirements))
    }
    if wheels.%Size() {
        do sections.python.%Push("wheels: " _ ..Join(wheels))
    }
    set mappings = []
    set key = ""
    for {
        set mapping = module.Mappings.GetNext(.key)
        quit:key=""
        do mappings.%Push([(mapping.Name), ("from " _ mapping.Source)])
    }

    set footprint = []
    do ..AddList(footprint, "Code", sections.code)
    do ..AddList(footprint, "Globals", sections.globals)
    do ..AddTable(footprint, "Web applications", sections.webapps)
    do ..AddTable(footprint, "Files", sections.files)
    do ..AddTable(footprint, "Mappings", mappings)
    do ..AddList(footprint, "System settings", sections.settings)
    do ..AddList(footprint, "Python", sections.python)
    do ..AddTable(footprint, "Other resources", sections.other)
    do ..AddBlock(lines, footprint)

    set needs = []
    set dependsOn = []
    for i = 1:1:module.Dependencies.Count() {
        set dependency = module.Dependencies.GetAt(i)
        // Scoped dependencies are development only and usually not installed.
        continue:dependency.Scope'=""
        set installed = installedVersions.%Get($zconvert(dependency.Name, "L"))
        do dependsOn.%Push([(dependency.Name _ " " _ dependency.VersionString), ($select(installed = "": "not installed", 1: "installed " _ installed))])
    }
    do ..AddTable(needs, "Depends on", dependsOn)
    set dependents = []
    set iterator = requiredBy.%GetIterator()
    while iterator.%GetNext(, .dependent) {
        do dependents.%Push(dependent.name _ " " _ dependent.version)
    }
    do ..AddList(needs, "Required by (directly)", dependents)
    do ..AddList(needs, "System requirements", ..GetSystemRequirements(module.SystemRequirements))
    do ..AddBlock(lines, needs)
    return lines
}

/// Returns the requirement lines of stream, skipping blank lines and # comments.
ClassMethod ParseRequirements(stream As %Stream.Object) As %DynamicArray
{
    set requirements = []
    do stream.Rewind()
    set content = ""
    while 'stream.AtEnd {
        set content = content _ stream.Read(32000)
    }
    set iterator = ..SplitLines(content).%GetIterator()
    while iterator.%GetNext(, .line) {
        if ($extract(line) '= "#") {
            do requirements.%Push(line)
        }
    }
    return requirements
}

/// Returns the non-blank lines of text, each trimmed. Handles LF and CRLF line endings.
ClassMethod SplitLines(text As %String) As %DynamicArray [ Private ]
{
    set lines = []
    for i = 1:1:$length(text, $char(10)) {
        // "C" also strips the CR of a CRLF line ending.
        set line = $zstrip($piece(text, $char(10), i), "<>WC")
        if (line '= "") {
            do lines.%Push(line)
        }
    }
    return lines
}

/// Returns the section key for resource in the sections object of GetLines, or "" when show leaves it out.
/// Classifies by the resolved processor class alone and never instantiates the processor.
ClassMethod GetSection(resource As %IPM.Storage.ResourceReference) As %String [ Private ]
{
    // Scoped resources are development only.
    if (resource.Scope '= "") {
        return ""
    }
    set shortName = ..GetShortName(resource.ResolvedProcessorClass())
    if (shortName = "UnitTest") || (shortName = "Test") {
        return ""
    }
    if (shortName = "Default.Global") {
        return "globals"
    }
    if ($piece(shortName, ".") = "Default") {
        return "code"
    }
    return $case(shortName,
        "WebApplication": "webapps",
        "CSPApplication": "webapps",
        "FileCopy": "files",
        "SystemSetting": "settings",
        "PythonWheel": "python",
        : "other")
}

/// Returns processorClass without the default processor package, or unchanged when it is outside that package.
ClassMethod GetShortName(processorClass As %String) As %String [ Private ]
{
    set prefix = $$$DefaultProcessorPackageDot
    if ($extract(processorClass, 1, $length(prefix)) = prefix) {
        return $extract(processorClass, $length(prefix) + 1, *)
    }
    return processorClass
}

/// Returns what serves the web application: its dispatch class, WSGI app, or physical directory, or "" for none.
ClassMethod GetWebApplicationDetail(resource As %IPM.Storage.ResourceReference) As %String [ Private ]
{
    set dispatchClass = ..GetAttribute(resource, "DispatchClass")
    if (dispatchClass '= "") {
        return "dispatch " _ dispatchClass
    }
    set wsgiLocation = ..GetAttribute(resource, "WSGIAppLocation")
    if (wsgiLocation '= "") {
        return "wsgi " _ wsgiLocation
    }
    // Loading module.xml renames CSPApplication's DeployPath to Directory.
    set directory = ..GetAttribute(resource, "Path", "Directory")
    if (directory '= "") {
        return "files at " _ directory
    }
    return ""
}

/// Returns the first non-empty attribute among names, or "".
ClassMethod GetAttribute(
	resource As %IPM.Storage.ResourceReference,
	names... As %String) As %String [ Private ]
{
    for i = 1:1:$get(names) {
        set value = resource.Attributes.GetAt(names(i))
        if (value '= "") {
            return value
        }
    }
    return ""
}

/// Returns the lines of requirements.txt under root, or none when the file is absent.
ClassMethod GetRequirements(root As %String) As %DynamicArray [ Private ]
{
    if (root = "") {
        return []
    }
    // The two-argument NormalizeFilename returns "" when root does not exist.
    set fileName = ##class(%File).NormalizeFilename("requirements.txt", root)
    if (fileName = "") || '##class(%File).Exists(fileName) {
        return []
    }
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(fileName))
    return ..ParseRequirements(stream)
}

ClassMethod Join(values As %DynamicArray) As %String [ Private ]
{
    set joined = ""
    set iterator = values.%GetIterator()
    while iterator.%GetNext(, .value) {
        set joined = joined _ $select(joined = "": "", 1: ", ") _ value
    }
    return joined
}

ClassMethod GetSystemRequirements(requirements As %IPM.Storage.SystemRequirements) As %DynamicArray [ Private ]
{
    set entries = []
    if '$isobject(requirements) {
        return entries
    }
    if (requirements.VersionString '= "") {
        do entries.%Push("IRIS " _ requirements.VersionString)
    }
    if (requirements.Interoperability '= "") {
        do entries.%Push("Interoperability " _ requirements.Interoperability)
    }
    if requirements.Health {
        do entries.%Push("Health Connect, HealthShare, or IRIS for Health required")
    }
    if (requirements.IPMVersion '= "") {
        do entries.%Push("IPM " _ requirements.IPMVersion)
    }
    if (requirements.PythonVersion '= "") {
        do entries.%Push("Python " _ requirements.PythonVersion)
    }
    if requirements.SYSNamespace {
        do entries.%Push("%SYS namespace required")
    }
    return entries
}

ClassMethod AddField(
	lines As %DynamicArray,
	label As %String,
	value As %String) [ Private ]
{
    if (value '= "") {
        do lines.%Push("    " _ label _ ":" _ $justify("", 15 - $length(label)) _ value)
    }
}

/// Appends heading and entries to block, or nothing when there are no entries.
ClassMethod AddList(
	block As %DynamicArray,
	heading As %String,
	entries As %DynamicArray) [ Private ]
{
    if (entries.%Size() = 0) {
        return
    }
    do block.%Push("    " _ heading)
    set iterator = entries.%GetIterator()
    while iterator.%GetNext(, .entry) {
        do block.%Push("        " _ entry)
    }
}

/// Appends heading and rows to block, or nothing when there are no rows.
/// Each row is a [left, right] pair, where right may be "". Left columns of rows with a right side are padded to a common width.
ClassMethod AddTable(
	block As %DynamicArray,
	heading As %String,
	rows As %DynamicArray) [ Private ]
{
    set width = 0
    set iterator = rows.%GetIterator()
    while iterator.%GetNext(, .row) {
        if (row.%Get(1) '= "") && ($length(row.%Get(0)) > width) {
            set width = $length(row.%Get(0))
        }
    }
    set entries = []
    set iterator = rows.%GetIterator()
    while iterator.%GetNext(, .row) {
        set entry = row.%Get(0)
        if (row.%Get(1) '= "") {
            set entry = entry _ $justify("", width - $length(entry) + 2) _ row.%Get(1)
        }
        do entries.%Push(entry)
    }
    do ..AddList(block, heading, entries)
}

/// Appends a blank line and then block to lines, or nothing when block is empty.
ClassMethod AddBlock(
	lines As %DynamicArray,
	block As %DynamicArray) [ Private ]
{
    if (block.%Size() = 0) {
        return
    }
    do lines.%Push("")
    set iterator = block.%GetIterator()
    while iterator.%GetNext(, .line) {
        do lines.%Push(line)
    }
}

}
