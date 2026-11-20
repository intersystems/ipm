/// For a module that requires steps to be run when updating to a new version, define those steps in a class named <UpdatePackage>.V#.
/// That class must extend %IPM.General.Update.VersionBase and override at least one of <method>GetOrderedMethods</method> and <method>GetOrderedMethodsPrimaryOnly</method>
Class %IPM.General.Update.VersionBase [ Abstract ]
{

/// Returns dynamic array of update method names to apply in order. <br />
/// These are always run synchronously when the zpm "update" command is run (during the ApplyUpdateSteps lifecycle phase). <br />
/// When the instance is mirrored, this will run on every mirror member. <br />
/// <example>
///     Output: ["methodA", "methodB", "methodC"]
/// </example>
ClassMethod GetOrderedMethods() As %Library.DynamicArray [ Abstract ]
{
}

/// Returns a dynamic array of update method names to apply in order. <br />
/// When the instance is not mirrored, these are always run synchronously when the zpm "update" command is run (during the ApplyUpdateSteps lifecycle phase). <br />
/// When the instance is mirrored, this will run only when the instance becomes the primary member. <br />
/// <example>
///     Output: ["methodA", "methodB", "methodC"]
/// </example>
ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray [ Abstract ]
{
}

/// For a given UpdatePackage name, compiles a list of the update step classes ordered by number. <br />
/// <example>
///     Example output for module with update steps V1, V2, V3, & V5 classes:
///         updatePackageClassList(1) = "MyModUpdatePackage.V1"
///         updatePackageClassList(2) = "MyModUpdatePackage.V2"
///         updatePackageClassList(3) = "MyModUpdatePackage.V3"
///         updatePackageClassList(5) = "MyModUpdatePackage.V5"
/// </example>
ClassMethod GetUpdatePackageClassList(
	updatePackage As %String,
	Output updatePackageClassList)
{
    set sc = $$$OK
    try {
        set res = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT * "_
            "FROM %Dictionary.CompiledClass "_
            "WHERE Name %STARTSWITH '"_updatePackage_".V'")
        if (res.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(res.%SQLCODE,res.%Message)
        }
        while res.%Next() {
            set className = res.Name
            set stepClass = $piece(className, ".", *)
            if ($length(className, ".") '= ($length(updatePackage, ".") + 1)) || '$match(stepClass, "V[0-9]+") {
                continue
            }
            // Preserve distinct class names such as V1 and V01.
            set classNum = $extract(stepClass, 2, *)
            set updatePackageClassList(classNum) = className
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    $$$ThrowOnError(sc)
}

}
