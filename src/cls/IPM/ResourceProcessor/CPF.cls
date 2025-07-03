Include %IPM.Formatting

Class %IPM.ResourceProcessor.CPF Extends (%IPM.ResourceProcessor.Abstract, %IPM.ResourceProcessor.CustomPhaseMixin)
{

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Name,Directory,Phase,CustomPhase,When";

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Merges the specified CPF file in the specified lifecycle phase (""Initialize"" by default).";

/// Directory containing the CPF file to merge
Property Directory As %IPM.DataType.ResourceDirectory [ InitialExpression = "cpf" ];

/// FileN ame of the CPF merge file
Property Name As %IPM.DataType.ResourceName [ Required ];

/// The phase before/after which the CPF file should be merged
Property Phase As %IPM.DataType.PhaseName [ InitialExpression = "Initialize" ];

/// When to merge the CPF file: Before or After the specified phase. This only applies to the standard phases.
Property When As %IPM.DataType.PhaseWhen [ InitialExpression = "Before" ];

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    if (..When = "Before") && (..Phase = pPhase) && (..CustomPhase = "") {
        quit ..DoMerge(.pParams)
    }
    quit $$$OK
}

Method OnAfterPhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    if (..When = "After") && (..Phase = pPhase) && (..CustomPhase = "") {
        quit ..DoMerge(.pParams)
    }
    quit $$$OK
}

Method OnCustomPhase(
	pCustomPhase As %String,
	ByRef pParams) As %Status
{
    if (..CustomPhase = pCustomPhase) {
        quit ..DoMerge(.pParams)
    }
    quit $$$OK
}

Method DoMerge(ByRef pParams) As %Status
{
    try {
        set verbose = $get(pParams("Verbose"))
        set root = ..ResourceReference.Module.Root
        set sourcesRoot = ..ResourceReference.Module.SourcesRoot
        // Use Construct first, rather than NormalizeFilename, so we don't have to deal with leading/trailing slashes
        set dir = $select($$$isWINDOWS: $replace(..Directory, "/", "\"), 1: ..Directory)
        set dir = ##class(%File).Construct(root, sourcesRoot, dir)
        set filename = ##class(%File).NormalizeFilename(..Name, dir)
        if (filename = "") || ('##class(%File).Exists(filename)) {
            $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("CPF file '%1' not found in directory '%2'", ..Name, dir)))
        }

        set stream = ##class(%Stream.FileCharacter).%New()
        $$$ThrowOnError(stream.LinkToFile(filename))
        if verbose {
            write !, "Merging CPF file: ", filename, !
            do stream.OutputToDevice()
        }
        do ..MergeCPF(filename)
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

ClassMethod MergeCPF(file As %String)
{
    // TODO The $zf(-100) callout is much slower than ##class(Config.CPF).Merge()
    //      Figure out why ##class(Config.CPF).Merge() doesn't work
    //      c.f. https://github.com/intersystems/ipm/pull/703#discussion_r1917290136

    set args($increment(args)) = "merge"
    set args($increment(args)) = ##class(%SYS.System).GetInstanceName()
    set args($increment(args)) = file

    // Somehow, if the STDOUT is not set, the merge will silently fail
    set flags = "/SHELL/LOGCMD/STDOUT=""zf100stdout""/STDERR=""zf100stderr"""
    set status = $zf(-100, flags, "iris", .args)
    if status '= 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Error merging CPF file. $zf(-100) exited with "_status))
    }
}

}
