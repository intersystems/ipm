/// This class is used for interacting with a lock file for a given module
/// Covers functionality for both creating a lock file and installing from a lock file
Class %IPM.General.LockFile Extends (%RegisteredObject, %JSON.Adaptor)
{

/// Name of the JSON lock file
Parameter LockFileName As String = "module-lock.json";

/// Name of the module the lock file is for
Property ModuleName As %IPM.DataType.ModuleName(%JSONFIELDNAME = "name") [ Required ];

/// Version string of the module
Property VersionString As %IPM.DataType.VersionString(%JSONFIELDNAME = "version") [ Required ];

/// Repository where the base module used to create the lock file comes from
Property Repository As %IPM.DataType.RepoName(%JSONFIELDNAME = "repository");

/// Version of the lock file schema used in creating the lock file
Property LockFileVersion As %String(%JSONFIELDNAME = "lockFileVersion", MAXLEN = "") [ InitialExpression = "1" ];

/// Array of repository definitions from where at least one of the base module or dependency comes from
Property Repositories As array Of %IPM.Repo.Definition(%JSONFIELDNAME = "repositories");

/// Array of dependency modules required by the module. Ordered by least dependent to most dependent
Property Dependencies As array Of %IPM.General.LockFile.Dependency(%JSONFIELDNAME = "dependencies");

/// When given the name of a module, creates the lock file for it and saves it to module.Root_..#LockFileName
/// flatDependencyList is the output from ##class(%IPM.Utils.Module).GetFlatDependencyListFromInvertedDependencyGraph()
ClassMethod CreateLockFileForModule(
	module As %IPM.Storage.Module,
	ByRef flatDependencyList,
	ByRef params)
{
    set verbose = $get(params("Verbose"), 0)
    if (verbose) {
        write !, "Creating lock file for module "_module.DisplayName
    }

    // Create lock file object and set values for the base module
    set lockFile = ##class(%IPM.General.LockFile).%New()
    set lockFile.ModuleName = module.Name
    set lockFile.VersionString = module.VersionString
    set lockFile.Repository = module.Repository

    // Iterate over module dependency list
    // For each module:
    //      1. Set values for module name, version, repository (name), and direct dependencies
    //      2. Add repository information to the list (if the module is from a new repo)
    set moduleName = ""
    for i = 1:1:flatDependencyList.Count() {
        set moduleName = flatDependencyList.GetAt(i).Name
        set mod = ##class(%IPM.Storage.Module).NameOpen(moduleName, 0, .sc)
        $$$ThrowOnError(sc)

        if (verbose) {
            write !, "Adding "_mod.DisplayName_" to the lock file"
        }

        // Add the dependency to the lock file
        set dependencyVal = ##class(%IPM.General.LockFile.Dependency).%New()
        set dependencyVal.VersionString = mod.VersionString
        set dependencyVal.Repository = mod.Repository
        set depKey = ""
        for {
            set depMod = mod.Dependencies.GetNext(.depKey)
            quit:depKey=""
            $$$ThrowOnError(dependencyVal.Dependencies.SetAt(depMod.VersionString, depMod.Name))
        }
        $$$ThrowOnError(lockFile.Dependencies.SetAt(dependencyVal, mod.Name))

        // Add the dependency's repository to the lock file
        do AddRepositoryToLockFile(.lockFile, mod.Repository, verbose)
    }
    // Add repository for base module if not already added by a dependency
    // Skip undefined repositories as that means the module was installed via the zpm "load" command
    if (module.Repository '= "") {
        do AddRepositoryToLockFile(.lockFile, module.Repository, verbose)
    }

    $$$ThrowOnError(lockFile.%JSONExportToStream(.lockFileJSON, "LockFileMapping"))

    set lockFilePath = module.Root_..#LockFileName
    if (verbose) {
        write !, "Saving lock file for "_module.Name_" to: "_lockFilePath
    }
    set file = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(file.LinkToFile(lockFilePath))
    $$$ThrowOnError(file.CopyFrom(lockFileJSON))
    $$$ThrowOnError(file.%Save())
}

/// Adds a module's repository to the lock file
ClassMethod AddRepositoryToLockFile(
	ByRef lockFile As %IPM.General.LockFile,
	repositoryName As %String,
	verbose As %Boolean = 0) [ Internal ]
{
    set repo = ..GetRepo(repositoryName)
    if 'lockFile.Repositories.IsDefined(repo.Name) {
        if (verbose) {
            write !, "Adding new repository to the lock file: "_repo.Name
        }
        $$$ThrowOnError(lockFile.Repositories.SetAt(repo, repo.Name))
    }
}

/// Returns a repo based on its name
ClassMethod GetRepo(repoName As %String) As %IPM.Repo.Definition [ Internal ]
{
    if ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(repoName, .id) {
        set repo = ##class(%IPM.Repo.Definition).%OpenId(id, , .sc)
        $$$ThrowOnError(sc)
        return repo
    } else {
        $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Tried getting repo ""%1"" but none found with that name", repoName)))
    }
}

}
