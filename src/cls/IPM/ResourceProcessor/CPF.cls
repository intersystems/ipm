Include %IPM.Formatting

Class %IPM.ResourceProcessor.CPF Extends %IPM.ResourceProcessor.Abstract
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Name,Directory,Phase,CustomPhase,When";

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Merges the specified CPF file in the ""Initialize"" lifecycle phase.";

/// Directory containing the CPF file to merge
Property Directory As %IPM.DataType.ResourceDirectory [ InitialExpression = "cpf" ];

/// FileN ame of the CPF merge file
Property Name As %IPM.DataType.ResourceName [ Required ];

/// The phase before/after which the CPF file should be merged
Property Phase As %IPM.DataType.PhaseName [ InitialExpression = "Initialize" ];

/// If provided, the Phase property will be ignored. The CPF merge will happen during this custom phase.
Property CustomPhase As %IPM.DataType.CustomPhaseName;

/// When to merge the CPF file: Before or After the specified phase. This only applies to the standard phases.
Property When As %IPM.DataType.PhaseWhen [ InitialExpression = "Before" ];

Method OnBeforePhase(pPhase As %String, ByRef pParams) As %Status
{
    If (..When = "Before") && (..Phase = pPhase) && (..CustomPhase = "") {
        Quit ..DoMerge(.pParams)
    }
    Quit $$$OK
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
    If (..When = "After") && (..Phase = pPhase) && (..CustomPhase = "") {
        Quit ..DoMerge(.pParams)
    }
    Quit $$$OK
}

Method DoMerge(ByRef pParams) As %Status
{
    Try {
        Set verbose = $GET(pParams("Verbose"))
        Set root = ..ResourceReference.Module.Root
        Set sourcesRoot = ..ResourceReference.Module.SourcesRoot
        // Use Construct first, rather than NormalizeFilename, so we don't have to deal with leading/trailing slashes
        Set dir = $SELECT($$$isWINDOWS: $REPLACE(..Directory, "/", "\"), 1: ..Directory)
        Set dir = ##class(%File).Construct(root, sourcesRoot, dir)
        Set filename = ##class(%File).NormalizeFilename(..Name, dir)
        If (filename = "") || ('##class(%File).Exists(filename)) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("CPF file '%1' not found in directory '%2'", ..Name, dir)))
        }

        Set stream = ##class(%Stream.FileCharacter).%New()  
        $$$ThrowOnError(stream.LinkToFile(filename))
        If verbose {
            Write !, "Merging CPF file: ", filename, !
            Do stream.OutputToDevice()
        }
        Do ..MergeCPF(filename)
    } Catch ex {
        Return ex.AsStatus()
    }
    Return $$$OK
}

ClassMethod MergeCPF(file As %String)
{
    // TODO The $zf(-100) callout is much slower than ##class(Config.CPF).Merge() 
    //      Figure out why ##class(Config.CPF).Merge() doesn't work
    //      c.f. https://github.com/intersystems/ipm/pull/703#discussion_r1917290136

    Set args($INCREMENT(args)) = "merge"
    Set args($INCREMENT(args)) = ##class(%SYS.System).GetInstanceName()
    Set args($INCREMENT(args)) = file

    // Somehow, if the STDOUT is not set, the merge will silently fail
    Set flags = "/SHELL/LOGCMD/STDOUT=""zf100stdout""/STDERR=""zf100stderr"""
    Set status = $ZF(-100, flags, "iris", .args)
    If status '= 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error merging CPF file. $zf(-100) exited with "_status))
    }
}

}
