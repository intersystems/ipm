Include %IPM.Formatting

Class %IPM.ResourceProcessor.CPF Extends %IPM.ResourceProcessor.Abstract
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Name,Directory";

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Merges the specified CPF file in the ""Initialize"" lifecycle phase.";

Property Directory As %IPM.DataType.ResourceDirectory [ InitialExpression = "cpf" ];

Property Name As %IPM.DataType.ResourceName [ Required ];

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

        Set root = ..ResourceReference.Module.Root
        // Use Construct first, rather than NormalizeFilename, so we don't have to deal with leading/trailing slashes
        Set dir = $Select($$$isWINDOWS: $Replace(..Directory, "/", "\"), 1: ..Directory)
        Set dir = ##class(%File).Construct(root, dir)
        Set filename = ##class(%File).NormalizeFilename(..Name, dir)

        Set stream = ##class(%Stream.FileCharacter).%New()  
        $$$ThrowOnError(stream.LinkToFile(filename))
        If verbose {
            Write !, "Merging CPF file: ", filename, !
            Do stream.OutputToDevice()
        }

        Do ..MergeCPF(filename)

        Set pResourceHandled = 1
    } Catch ex {
        Set pResourceHandled = 0
        Write !, $$$FormattedLine($$$Red, $$$FormatText("Error merging CPF file. See the error for details."))
        Set status = ex.AsStatus()
    }
    Return status
}

ClassMethod MergeCPF(file As %String)
{
    // TODO The $zf(-100) callout is much slower than ##class(Config.CPF).Merge() 
    //      Figure out why ##class(Config.CPF).Merge() doesn't work
    //      c.f. https://github.com/intersystems/ipm/pull/703#discussion_r1917290136

    Set args($Increment(args)) = "merge"
    Set args($Increment(args)) = ##class(%SYS.System).GetInstanceName()
    Set args($Increment(args)) = file

    // Somehow, if the STDOUT is not set, the merge will silently fail
    Set flags = "/SHELL/LOGCMD/STDOUT=""zf100stdout""/STDERR=""zf100stderr"""
    Set status = $ZF(-100, flags, "iris", .args)
    If status '= 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error merging CPF file. $zf(-100) exited with "_status))
    }
}

}
