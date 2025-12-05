/// This class is used for interacting with a lock file for a given module
/// Covers functionality for both creating a lock file and installing from a lock file
Class %IPM.General.LockFile Extends (%RegisteredObject, %JSON.Adaptor)
{

/// Name of the JSON lock file
Parameter LockFileName As String = "module-lock.json";

Property ModuleName As %IPM.DataType.ModuleName(%JSONFIELDNAME = "name") [ Required ];

Property VersionString As %IPM.DataType.VersionString(%JSONFIELDNAME = "version") [ Required ];

Property Repository As %IPM.DataType.RepoName(%JSONFIELDNAME = "repository");

Property LockFileVersion As %String(%JSONFIELDNAME = "lockFileVersion", MAXLEN = "") [ InitialExpression = "1" ];

Property Repositories As array Of %IPM.Repo.Definition(%JSONFIELDNAME = "repositories");

Property Dependencies As array Of %IPM.General.LockFile.Dependency(%JSONFIELDNAME = "dependencies");

ClassMethod CreateLockFileForModule(
	baseModName As %String,
	ByRef params)
{
    set verbose = $get(params("Verbose"), 0)
    set module = ##class(%IPM.Storage.Module).NameOpen(baseModName, .sc)
    $$$ThrowOnError(sc)

    if (verbose) {
        write !, "Creating lock file for module "_module.DisplayName
    }

    /// Create lock file object and set values for the base module
    set lockFile = ##class(%IPM.General.LockFile).%New()
    set lockFile.ModuleName = module.Name
    set lockFile.VersionString = module.VersionString
    set lockFile.Repository = module.Repository

    // Create dependency list of least dependent module to most dependent from dependency graph
    $$$ThrowOnError(module.BuildDependencyGraph(.dependencyGraph))
    do ##class(%IPM.Utils.Module).ConstructInvertedDependencyGraph(.dependencyGraph, .inverted)
    set dependencyList = ##class(%IPM.Utils.Module).GetFlatDependencyListFromInvertedDependencyGraph(.inverted)

    // Iterate over module dependency list
    // For each module:
    //      1. Set values for module name, version, repository (name), and direct dependencies
    //      2. Add repository information to the list (if the module is from a new repo)
    set moduleName = ""
    for i = 1:1:dependencyList.Count() {
        set moduleName = dependencyList.GetAt(i).Name
        set mod = ##class(%IPM.Storage.Module).NameOpen(moduleName, .sc)
        $$$ThrowOnError(sc)

        if (verbose) {
            write !, "Adding "_mod.DisplayName_" to the lock file"
        }

        // DEPENDENCY STUFF
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

        // REPOSITORY STUFF:
        set repo = ..GetRepo(mod.Repository)
        if 'lockFile.Repositories.IsDefined(repo.Name) {
            if (verbose) {
                write !, "Adding new repository to the lock file: "_repo.Name
            }
            $$$ThrowOnError(lockFile.Repositories.SetAt(repo, repo.Name))
        }
    }
    // Add repository for base module if not already added by a dependency
    set repo = ..GetRepo(module.Repository)
    if 'lockFile.Repositories.IsDefined(repo.Name) {
        if (verbose) {
            write !, "Adding new repository to the lock file: "_repo.Name
        }
        $$$ThrowOnError(lockFile.Repositories.SetAt(repo, repo.Name))
    }

    $$$ThrowOnError(lockFile.%JSONExportToStream(.lockFileJSON, "LockFileMapping"))

    set lockFilePath = module.Root_..#LockFileName
    if (verbose) {
        write !, "Saving lock file for "_module.Name_" to: "_lockFilePath
    }
    set file = ##class(%File).%New(lockFilePath)
    $$$ThrowOnError(file.Open("WSN"))
    $$$ThrowOnError(file.CopyFrom(lockFileJSON))
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
