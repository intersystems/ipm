Class %IPM.DataType.ResourceName Extends %IPM.DataType.RegExString [ ClassType = datatype ]
{

Parameter MAXLEN = 255;

Parameter REGEX = "(/.*|(%)?(.+\.)+([A-Za-z0-9])+)";

}
