Class ResourceTest.TestDTL Extends Ens.DataTransformDTL [ DependsOn = EnsLib.ebXML.Message ]
{

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='EnsLib.ebXML.Message' targetClass='EnsLib.ebXML.Message' create='new' language='objectscript' >
</transform>
}

}
