Class Test.UnsupportedPreload.Processor Extends %IPM.ResourceProcessor.Abstract
{

Method OnBeforePhase(
	pPhase As %String,
	ByRef pParams) As %Status
{
    set ^IPMTest("UnsupportedFiles", pPhase) = 1
    quit ##super(pPhase, .pParams)
}

}
