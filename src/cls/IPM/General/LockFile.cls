/// This class is used for interacting with a lock file for a given module
/// Covers functionality for both creating a lock file and installing from a lock file
Class %IPM.General.LockFile Extends (%RegisteredObject, %JSON.Adaptor)
{

/// Name of the JSON lock file
Parameter LockFileName As String = "module-lock.json";

Property ModuleName As %IPM.DataType.ModuleName(%JSONFIELDNAME = "name", MAXLEN = "");

Property VersionString As %String(%JSONFIELDNAME = "version", MAXLEN = 100);

Property Repository As %String(%JSONFIELDNAME = "repository", MAXLEN = "");

Property LockFileVersion As %String(%JSONFIELDNAME = "lockFileVersion", MAXLEN = "") [ InitialExpression = "1" ];

Property Repositories As array Of %IPM.General.LockFile.Repository(%JSONFIELDNAME = "repositories");

Property Dependencies As array Of %IPM.General.LockFile.Dependency(%JSONFIELDNAME = "dependencies");

ClassMethod CreateLockFileForModule(
	baseModName As %String,
	ByRef params)
{
    set sc = $$$OK
    try {
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
        set repositoriesFound = ""
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
            // If repository already exists, skip creating a new entry for it
            if $listfind(repositoriesFound, repo.Name) {
                continue
            }
            set repositoriesFound = repositoriesFound_$listbuild(repo.Name)
            if (verbose) {
                write !, "Adding new repository to the lock file: "_repo.Name
            }
            set repoVal = ##class(%IPM.General.LockFile.Repository).%New()
            do repo.SetValuesForLockFile(.repoVal)
            $$$ThrowOnError(lockFile.Repositories.SetAt(repoVal, repo.Name))
        }
        // Add repository for base module if not already added by a dependency
        set repo = ..GetRepo(module.Repository)
        if '$listfind(repositoriesFound, repo.Name) {
            if (verbose) {
                write !, "Adding new repository to the lock file: "_repo.Name
            }
            set repoVal = ##class(%IPM.General.LockFile.Repository).%New()
            do repo.SetValuesForLockFile(.repoVal)
            $$$ThrowOnError(lockFile.Repositories.SetAt(repoVal, repo.Name))
        }

        do lockFile.%JSONExportToString(.lockFileJSON)

        set lockFilePath = module.Root_..#LockFileName
        if (verbose) {
            write !, "Saving lock file for "_module.Name_" to: "_lockFilePath
        }
        set file = ##class(%File).%New(lockFilePath)
        $$$ThrowOnError(file.Open("WSN"))
        $$$ThrowOnError(file.Write(lockFileJSON))
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    $$$ThrowOnError(sc)
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
