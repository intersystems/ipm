/// For a module that requires steps to be run when updating to a new version, define those steps in a class named <UpdatePackage>.V#.
/// To make sure those steps run, have that class extend %IPM.General.Update.VersionBase and
/// override at least one of <method>GetOrderedMethods</method> and <method>GetOrderedMethodsPrimaryOnly</method>
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

/// Returns a dynamic array of update method names to apply in order. This method has different behavior when the instance is mirrored versus not. <br />
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
	Output updatePackageClassList) As %Status
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
            // Class name is of the form UpdatePackage.V#
            set className = res.Name
            // This strips everything except numbers following the '.' in the class name so we can isolate the # of this update class itself
            set classNum = $zstrip($piece(className, ".", *),"*E'N")
            set updatePackageClassList(classNum) = className
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

}
