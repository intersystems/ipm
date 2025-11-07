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
                if (verbose) {
                    // TODO: Add verbose output for creating a new repository
                    // TODO: Probably don't even need verbose output here, just have it for when adding a new repo
                    write !, repo.Name_" repo already exists, skipping creating repo val for "_moduleName
                }
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
            write !, "Writing lock file for "_module.Name_" to: "_lockFilePath
        }
        set file = ##class(%File).%New(lockFilePath)
        do file.Open("WSN")
        do file.Write(lockFileJSON.%ToJSON())
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

/// When given a module name, this will read from the module's lock file and install it's listed modules and dependencies
ClassMethod InstallFromLockFile(
	baseModName As %String,
	ByRef params) As %Status
{
    // TODO: THIS IS JUST FOR TESTING PURPOSES UNTIL CORRECT INSTALL FIGURED OUT
    //quit ##class(%IPM.Jimmy).CIRedirect(baseModName, .params)

    set sc = $$$OK
    try {
        set verbose = $get(params("Verbose"), 0)
        set module = ##class(%IPM.Storage.Module).NameOpen(baseModName)
        set lockFilePath = module.Root_..#LockFileName
        if '##class(%File).Exists(lockFilePath) {
            if (verbose) {
                write !, "No lock file found at "_lockFilePath
            }
            quit
        }
        set lockFile = ##class(%DynamicAbstractObject).%FromJSONFile(lockFilePath)
        do ..InstallRepositories(lockFile.repositories)
        // Add base mod to dependency list so that it gets installed at the end
        set modules = lockFile.dependencies
        do modules.%Set(lockFile.name, { "version": (lockFile.Version) })
        do ..InstallModules(modules)
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Creates new repositories on the instance
/// repositories - list of repositories as defined in a lock file
ClassMethod InstallRepositories(repositories As %DynamicObject) [ Internal ]
{
    // Setting up repositories
    set iter = repositories.%GetIterator()
    while iter.%GetNext(.repoName, .repoValues) {
        // If repo already exists, don't create a new one
        if ##class(%IPM.Repo.Definition).ServerDefinitionKeyExists(repoName) {
            write !, "Repo with name """_repoName_""" already exists, skipping creating a new one"
            continue
        }
        // Select the correct type of repository to create
        set repoType = $zconvert(repoValues.type, "l")
        if repoType = "filesystem" {
            set newRepo = ##class(%IPM.Repo.Filesystem.Definition).%New()
        }
        elseif repoType = "http" {
            set newRepo = ##class(%IPM.Repo.Http.Definition).%New()
        }
        elseif repoType = "oras" {
            set newRepo = ##class(%IPM.Repo.Oras.Definition).%New()
        }
        elseif repoType = "remote" {
            set newRepo = ##class(%IPM.Repo.Remote.Definition).%New()
        }
        elseif repoType = "perforce" {
            set newRepo = ##class(%IPM.Repo.Extension.Perforce.Definition).%New()
        }

        // Adding the name repo key into the data object for creating a new repo
        set repoValues.name = repoName
        do newRepo.SetValuesFromLockFile(repoValues)

        $$$ThrowOnError(newRepo.%Save())
    }
}

ClassMethod InstallModules(modules As %DynamicObject) [ Internal, Private ]
{
    set iter = modules.%GetIterator()
    while iter.%GetNext(.moduleName, .moduleValues) {
        // TODO: Don't use the shell command
        // TODO: What if we need an env.json file to go along with installing??
        write !, "Still installing module from lock file by using zpm ""install"""
        do ##class(%IPM.Main).Shell("install -v "_moduleName_" "_moduleValues.version)
    }
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
