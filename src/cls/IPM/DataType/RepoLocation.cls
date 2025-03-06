Class %IPM.DataType.RepoLocation Extends %IPM.DataType.RegExString [ ClassType = datatype ]
{

Parameter MAXLEN = 2048;

Parameter REGEX = "https?:\/\/(?:[a-zA-Z0-9-]+\.)*[a-zA-Z0-9-]+(?::\d+)?(?:\/[^\s]*)?\/?";

}
