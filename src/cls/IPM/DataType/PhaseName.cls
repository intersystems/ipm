Class %IPM.DataType.PhaseName Extends %Library.String [ ClassType = datatype ]
{

/// The maximum number of characters the string can contain.
Parameter MAXLEN As INTEGER = 50;

/// Canonical lifecycle phase ordering. Phases execute in this order during a complete
/// lifecycle run (e.g., load with isComplete=1). Each phase name corresponds to a
/// %<PhaseName> method on %IPM.Lifecycle.Base and its subclasses.
/// 
/// The "*" entry is not a real phase — it is a module-object refresh checkpoint.
/// When ExecutePhases (in %IPM.Storage.Module) encounters "*", it kills and reopens
/// the module and lifecycle objects from storage, picking up any changes made by
/// earlier phases (e.g., module.xml modifications during Reload). No lifecycle method
/// is called for "*", and no resource processor hooks or <Invoke> elements target it.
/// 
/// Should be kept in sync with %IPM.Lifecycle.Base.PHASES.
Parameter VALUELIST = ",Clean,Initialize,Reload,*,Validate,ExportData,Compile,Activate,Document,MakeDeployed,Test,Package,Verify,Publish,Configure,Unconfigure,ApplyUpdateSteps";

}
