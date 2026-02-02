Class Invoke.IpmDirTest
{

/// Validates that the passed ipmDir argument matches the expected path
ClassMethod ValidateIpmDir(ipmDir As %String) As %Status
{
    set sc = $$$OK
    try {
        // Calculate expected path
        set expectedDir = ##class(%Library.File).NormalizeDirectory($system.Util.DataDirectory() _ "ipm/invoke-ipmdir-test/1.0.0/")

        // Normalize received path for comparison
        set normalizedIpmDir = ##class(%Library.File).NormalizeDirectory(ipmDir)

        // Store in temp global for test validation
        set ^IRIS.Temp.Test.IpmDir = normalizedIpmDir

        // Validate the path matches
        if (normalizedIpmDir '= expectedDir) {
            set sc = $$$ERROR($$$GeneralError, "${ipmDir} mismatch: expected '" _ expectedDir _ "' but got '" _ normalizedIpmDir _ "'")
        }
    } catch ex {
        set sc = ex.AsStatus()
    }
    quit sc
}

}
