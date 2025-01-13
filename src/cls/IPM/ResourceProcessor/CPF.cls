Class %IPM.ResourceProcessor.CPF Extends %IPM.ResourceProcessor.Abstract
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Path";

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Merges the specified CPF file in the ""Initialize"" lifecycle phase.";

Property Path As %String(MAXLEN = "");

/// Called as phase <var>pPhase</var> is executed for the resource. If <var>pResourceHandled</var> is set to true,
/// then the default behavior for that resource will be bypassed in the current phase.
/// Currently, this is only used in the Verify phase, because of different handling of intermediate error statuses.
/// TODO: Implement for standard database resources (.INC, .CLS, etc.)
Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
    Set verbose = $Get(pParams("Verbose"))
    Set status = $$$OK
    Try {
        If pPhase '= "Initialize" {
            Quit
        }

        If '$Data(pParams("RootDirectory"), root) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, "RootDirectory unspecified"))
        }
        // Use Construct first, rather than NormalizeFilename, so we don't have to deal with leading/trailing slashes
        Set filename = ##class(%File).Construct(root, ..Path)  
        Set filename = ##class(%File).NormalizeFilename(filename)

        Set stream = ##class(%Stream.FileCharacter).%New()  
        $$$ThrowOnError(stream.LinkToFile(filename))
        If verbose {
            Write !, "Merging CPF file: ", filename, !
            While 'stream.AtEnd {
                Write stream.Read()
            }
        }
        // TODO actually merge the CPF file
        // ...

        Set pResourceHandled = 1
    } Catch ex {
        Set pResourceHandled = 0
        Set status = ex.AsStatus()
    }
    Return status
}

}
