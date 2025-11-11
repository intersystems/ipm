Class %IPM.General.LockFile
{

/// Name of the JSON lock file
Parameter LockFileName As String = "module-lock.json";

/// For a given module name, this will write it's lock file and save it under the module's root
ClassMethod WriteToLockFile(
	baseModName As %String,
	ByRef params) As %Status
{
    set sc = $$$OK
    try {
        set verbose = $get(params("Verbose"), 0)
        set module = ##class(%IPM.Storage.Module).NameOpen(baseModName)
        do module.BuildDependencyGraph(.tDependencyGraph)

        if (verbose) {
            write !, "Creating lock file for module "_module.ExternalName
        }

        // Iterate over module dependency graph
        // For each module:
        //      1. Set values for module name, version, repository (name), and direct dependencies
        //      2. Add repository information to the list (if the module is from a new repo)
        set lockFileRepositories = {}
        set lockFileDependencies = {}
        set moduleName = ""
        for {
            set moduleName = $order(tDependencyGraph(moduleName))
            quit:moduleName=""
            set mod = ##class(%IPM.Storage.Module).NameOpen(moduleName)

            if (verbose) {
                write !, "Adding "_mod.ExternalName_" to the lock file"
            }

            // DEPENDENCY STUFF
            set dependencyVal = {}
            set dependencyVal.version = mod.VersionString
            set dependencyVal.repository = mod.Repository
            set dependencyVal.dependencies = {}
            set depKey = ""
            for {
                set depMod = mod.Dependencies.GetNext(.depKey)
                quit:depKey=""
                do dependencyVal.dependencies.%Set(depMod.Name, depMod.VersionString)
            }
            if dependencyVal.dependencies.%Size() '> 0 {
                do dependencyVal.%Remove("dependencies")
            }
            do lockFileDependencies.%Set(mod.Name, dependencyVal)


            // REPOSITORY STUFF:
            set repo = ..GetRepo(mod.Repository)
            // If repository already exists, skip creating a new entry for it
            if lockFileRepositories.%Get(repo.Name) {
                continue
            }
            set repoValues = repo.GetValuesForLockFile()
            // remove values set to "" for better readability in lock file
            set repoValuesIterator = repoValues.%GetIterator()
            while repoValuesIterator.%GetNext(.key, .value) {
                // TODO: Do we also want to remove values that are 0?
                //       OR, have the values removed as a part of the repo definition classes?
                if (value = "") {
                    do repoValues.%Remove(key)
                }
            }
            if (verbose) {
                write !, "Adding new repository to the lock file: "_repo.Name
            }
            do lockFileRepositories.%Set(repo.Name, repoValues)
        }
        // Add repository for base module if not already added by a dependency
        set repo = ..GetRepo(module.Repository)
        if 'lockFileRepositories.%Get(repo.Name) {
            set repoValues = repo.GetValuesForLockFile()
            // remove values set to "" for better readability in lock file
            set repoValuesIterator = repoValues.%GetIterator()
            while repoValuesIterator.%GetNext(.key, .value) {
                if (value = "") {
                    do repoValues.%Remove(key)
                }
            }
            if (verbose) {
                write !, "Adding new repository to the lock file: "_repo.Name
            }
            do lockFileRepositories.%Set(repo.Name, repoValues)
        }

        // TODO: Should probably add repository field for the base module as well?
        set lockFileJSON = {"name": (module.Name),
                            "version": (module.VersionString),
                            "lockFileVersion": "1"}
        do lockFileJSON.%Set("repositories", lockFileRepositories)
        do lockFileJSON.%Set("dependencies", lockFileDependencies)

        set lockFilePath = module.Root_..#LockFileName
        if (verbose) {
            write !, "Saving lock file for "_module.Name_" to: "_lockFilePath
        }
        set file = ##class(%File).%New(lockFilePath)
        do file.Open("WSN")
        do file.Write(lockFileJSON.%ToJSON())
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Returns a repo based on its name
ClassMethod GetRepo(repoName As %String) As %IPM.Repo.Definition [ Internal ]
{
    set query = "SELECT * FROM %IPM_Repo.Definition WHERE Name = ?"
    set tRes = ##class(%SQL.Statement).%ExecDirect(, query, repoName)
    if (tRes.%SQLCODE < 0) {
        throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
    }
    while tRes.%Next() {
        return ##class(%IPM.Repo.Definition).%OpenId(tRes.%Get("Id"))
    }
}

}
