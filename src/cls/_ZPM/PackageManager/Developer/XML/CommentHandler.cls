/// Use: Extracts XML comments from a document and allows them to be added back in later,
/// assuming that the XPath paths to their previous locations are still valid.
Class %ZPM.PackageManager.Developer.XML.CommentHandler Extends %XML.SAX.ContentHandler
{

/// ..Comments = <number of comments extracted from document>
/// ..Comments(i) = <text of ith comment in XML document>
Property Comments [ MultiDimensional, Private ];

/// ..CommentMap(i) = <XPath expression for location of ..Comments(i)>
Property CommentMap [ MultiDimensional, Private ];

/// ..Path = <depth of current path in document>
/// ..Path(i) = $ListBuild(<containing element descriptor>,<previous element descriptor>,<previous padding characters>)
Property Path [ MultiDimensional, Private ];

Property Padding As %String(MAXLEN = "") [ Private ];

Method GetResults(Output pComments, Output pCommentMap) [ Internal ]
{
	Merge pComments = i%Comments
	Merge pCommentMap = i%CommentMap
}

Method Reapply(ByRef pXMLStream As %Stream.Object, pIndent As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		// Construct XSLT to add comments back in.
		Do ..GetResults(.tComments, .tCommentMap)
		If '$Data(tComments) {
			// No-op.
			Quit
		}
		
		Set tXSL = ##class(%Stream.TmpBinary).%New()
		Do tXSL.Write("<?xml version=""1.0"" encoding=""UTF-8""?>")
		Do tXSL.Write("<xsl:stylesheet version=""1.0"" xmlns:xsl=""http://www.w3.org/1999/XSL/Transform"">")
		Do tXSL.Write("<xsl:output method=""xml"" "_$Select(pIndent:"indent=""yes""",1:"")_"/>")
		Do tXSL.Write("<xsl:template match=""node()|@*"">")
    	Do tXSL.Write("<xsl:copy>")
        Do tXSL.Write("<xsl:text /><xsl:apply-templates select=""node()|@*""/><xsl:text />")     
    	Do tXSL.Write("</xsl:copy>")
		Do tXSL.Write("</xsl:template>")
		
		// First pass: build map of comments to associated elements (with filters)
		#define BEFORE 0
		#define AFTER 1
		For i=1:1:$Get(tComments) {
			Set tComment = tComments(i)
			Set tContainerElement = $ListGet(tCommentMap(i))
			Set tPrevElement = $ListGet(tCommentMap(i),2)
			Set tPadding = $ListGet(tCommentMap(i),3)
			
			If (tPrevElement = $lb("","")) {
				Set tMatch = $ListGet(tContainerElement,2)
				Set tPlace = $$$BEFORE
			} Else {
				Set tMatch = $ListGet(tPrevElement,2)
				Set tPlace = $$$AFTER
			}
			
			// Hash to avoid <SUBSCRIPT> errors
			Set tHash = $zcrc(tMatch,7)
			Set tLocationHashMap(tHash) = tMatch
			Set tLocationHashMap(tHash,tPlace,i) = $lb(tPadding,tComment)
		}
		
		// Second pass: write XSLT to add comments
		Set tKey = ""
		For {
			Set tKey = $Order(tLocationHashMap(tKey),1,tMatchExpression)
			Quit:tKey=""
			
			Do tXSL.Write("<xsl:template match="""_tMatchExpression_""">")
			Do tXSL.Write("<xsl:copy><xsl:copy-of select=""@*""/>")
			
			Set tBeforeKey = 0
			For {
				Set tBeforeKey = $Order(tLocationHashMap(tKey,$$$BEFORE,tBeforeKey),1,tData)
				Quit:tBeforeKey=""
				
				Do:pIndent tXSL.Write("<xsl:text>"_$ZConvert($ListGet(tData,1),"O","XML")_"</xsl:text>")
				Do tXSL.Write("<xsl:comment>"_$ZConvert($ListGet(tData,2),"O","XML")_"</xsl:comment>")
			}
			
			Do tXSL.Write("<xsl:apply-templates select=""node()|@*"" /></xsl:copy>")
			
			Set tAfterKey = 0
			For {
				Set tAfterKey = $Order(tLocationHashMap(tKey,$$$AFTER,tAfterKey),1,tData)
				Quit:tAfterKey=""
				
				Do:pIndent tXSL.Write("<xsl:text>"_$ZConvert($ListGet(tData,1),"O","XML")_"</xsl:text>")
				Do tXSL.Write("<xsl:comment>"_$ZConvert($ListGet(tData,2),"O","XML")_"</xsl:comment>")
			}
			Do tXSL.Write("</xsl:template>")
		}
		
		Do tXSL.Write("</xsl:stylesheet>")
		
		// Apply XSLT to input stream.
		Set tSC = ##class(%XML.XSLT.Transformer).TransformStream(pXMLStream, tXSL, .tOutStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set pXMLStream = tOutStream
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod BuildAttributeFilter(pAttrList As %List) As %String [ Private ]
{
	If (pAttrList = "") {
		Quit ""
	}
	
	Set tPointer = 0
	Set tExpr = ""
	While $ListNext(pAttrList,tPointer,tAttr) {
		Set tExpr = tExpr_"[@"_$ListGet(tAttr)_"='"_$Replace($ListGet(tAttr,2),"'","\'")_"']"
	}
	Quit tExpr
}

/// Receive notification of comments.
/// 
/// <p>The Parser will call this method to report each occurence of
/// a comment in the XML document.</p>
/// 
/// <p>The application must not attempt to read from the array
/// outside of the specified range.</p>
/// <ul>
/// <li>chars: The characters from the XML document.</li>
/// <li>length: The number of characters to read from the array.</li>
/// </ul>
/// <p>
/// Exceptions thrown: SAXException - Any SAX exception, possibly
/// wrapping another exception.</p>
Method comment(chars As %String, length As %Integer)
{
	Set tPosition = ..GetPosition()
	Set i%Comments($Increment(i%Comments)) = chars
	Set i%CommentMap(i%Comments) = tPosition
	Set i%Padding = ""
	Quit
}

/// Returns current position in the XML document, as an XPath expression with information on the previous node.
Method GetPosition() As %String
{
	Set tPath = ""
	Set tPrevious = ""
	Set tType = ""
	Set tPreviousType = ""
	Set tPadding = ""
	For i=1:1:$Get(..Path) {
		Kill tVal1,tVal2
		Set $ListBuild(tType,tVal1) = ..Path(i)
		If (i = ..Path) {
			Set tNext = $Case(tType,
				"element":"/"_tVal1,
				"document":"/",
				:"")
			Set tPrevious = $Get(..Path(i+1))
		} Else {
			Set tNext = $Case(tType,
				"element":"/"_tVal1,
				:"")
		}
		Set tPath = tPath_tNext
		If (tPrevious '= "") {
			Set tPreviousType = $ListGet(tPrevious,1)
			Set tPrevious = tPath_
				$Case(tType,"document":"",:"/")_
				$ListGet(tPrevious,2)
		}
	}
	Quit $ListBuild($ListBuild(tType,tPath),$ListBuild(tPreviousType,tPrevious),i%Padding)
}

/// Receive notification of the beginning of the document.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method in a subclass to take specific actions at the beginning
/// of a document (such as allocating the root node of a tree or 
/// creating an output file)
/// <p>
Method startDocument()
{
	Kill i%Comments
	Kill i%CommentMap
	Set i%Padding = ""
	Set i%Path($i(i%Path)) = $lb("document")
}

/// Receive notification of the start of an element.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method in a subclass to take specific actions at the start of
/// each element (such as allocating a new tree node or writin
/// output to a file).
/// </p>
/// <p>
/// <ul>
/// <li>uri: The URI of the associated namespace for this element</li>
/// <li>localname: the local part of the element name</li>
/// <li>qname: the QName of this element</li>
/// <li>attrs: a list in $List format consisting of a repeating group of attributes.</li>
/// </ul>
/// <p>
/// The format of the repeating group is as follows:
/// <ul>
/// <li>+0 - uri: The URI of the associated namespace for this attribute</li>
/// <li>+1 - localname: The local part of the name of this attribute</li>
/// <li>+2 - qname: The QName of this attribute</li>
/// <li>+3 - type: The type of this attribute ("CDATA", NMTOKEN", "ENTITY", etc.)</li>
/// <li>+4 - value: The value of this attribute</li>
/// </ul>
/// </p>
Method startElement(uri As %Library.String, localname As %Library.String, qname As %Library.String, attrs As %Library.List)
{
	// Extract just qname/value from attrs, build $lb($lb(qname,value),$lb(qname,value),...)
	Set tModArgs = ""
	Set tPointer = 0
	Set tQName = ""
	Set tPosition = 0
	While $ListNext(attrs,tPointer,tAttrValue) {
		If (tPosition#5) = 2 {
			Set tQName = tAttrValue
		} ElseIf (tPosition#5) = 4 {
			Set tModArgs = tModArgs_$ListBuild($ListBuild(tQName,tAttrValue))
			Set tQName = ""
		}
		Set tPosition = tPosition + 1
	}
	
	Set tFilter = ..BuildAttributeFilter(tModArgs)
	
	// Update path info
	Set i%Path($Increment(i%Path)) = $lb("element",localname_tFilter)
	Set tNext = i%Path
	For {
		Set tNext = $Order(i%Path(tNext))
		Quit:tNext=""
		Kill i%Path(tNext)
	}
	Set i%Padding = ""
}

/// Receive notification of the end of an element.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method in a subclass to take specific actions at the end of
/// each element (such as finalising a tree node or writing
/// output to a file).
/// </p>
/// 
/// <p>
/// <ul>
/// <li>uri: The URI of the associated namespace for this element</li>
/// <li>localname: The local part of the element name</li>
/// <li>qname: The QName of this element</li>
/// </ul>
/// </p>
Method endElement(uri As %Library.String, localname As %Library.String, qname As %Library.String)
{
	Set i%Path = i%Path - 1
	Set i%Padding = ""
}

/// Receive notification of character data inside an element.
/// 
/// <p>
/// By default, do nothing.  Application writers may override this
/// method to take specific actions for each chunk of character data
/// (such as adding the data to a node or buffer, or printing it to
/// a file).
/// </P>
/// <p>
/// <ul>
/// <li>chars: The characters.</li>
/// <li>length: The number of characters to use from the character
/// array.</li>
/// </ul>
Method characters(chars As %Library.String, length As %Library.Integer)
{
	Set i%Padding = chars
}

}
