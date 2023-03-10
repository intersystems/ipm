/// Property parameter class for <class>%IPM.Utils.ComparisonAdaptor</class>
Class %IPM.Utils.ComparisonAdaptor.PropertyParams [ System = 2 ]
{

/// Forces code generation for the given property. <br />
/// If 1, then force code generate. <br />
/// If 0, then force skipping of code generation. <br />
/// If -1, ignore this parameter. <br />
Parameter ForceCodeGenerate As INTEGER [ Constraint = "0,1,-1", Flags = ENUM ] = -1;

}
