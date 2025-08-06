Include %IPM.Common

Class %IPM.Utils.Update.VersionBase [ Abstract ]
{

/// Returns dynamic array of update method names to apply in order that can be run on both primary and backup
/// Example output list: ["methodA", "methodB", "methodC"]
ClassMethod GetOrderedMethodsAnyMember() As %Library.DynamicArray [ Abstract ]
{
}

/// Returns dynamic array of update method names to apply in order that must be run on the primary
/// Example output list: ["methodA", "methodB", "methodC"]
ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray [ Abstract ]
{
}

/// For a given UpdatePackage name, compiles a list of the update step classes ordered by number
/// Example output for module with update steps V1, V2, V3, & V5 classes:
///     updatePackageClassList(1) = "MyModUpdatePackage.V1"
///     updatePackageClassList(2) = "MyModUpdatePackage.V2"
///     updatePackageClassList(3) = "MyModUpdatePackage.V3"
///     updatePackageClassList(5) = "MyModUpdatePackage.V5"
ClassMethod GetUpdatePackageClassList(
	updatePackage As %String,
	Output updatePackageClassList) As %Status
{
    set sc = $$$OK
    try {
        set tRes = ##class(%SQL.Statement).%ExecDirect(,
            "SELECT * "_
            "FROM %Dictionary.CompiledClass "_
            "WHERE Name LIKE '"_updatePackage_".%'")
        if (tRes.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
        }
        while tRes.%Next() {
            set className = tRes.Name
            set classNum = $zstrip($piece(className, ".", *),"*E'N")
            set updatePackageClassList(classNum) = className
        }
    } catch (ex) {
        set sc = ex.AsStatus()
    }
    return sc
}

}
