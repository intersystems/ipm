/// Provides class parameters for the magic numbers from <class>%Studio.Extension.Base</class> (used in the UserAction and AfterUserAction methods).
Class %IPM.ExtensionBase.Constants [ Abstract ]
{

/// Type (first argument to UserAction/AfterUserAction) for menu item-based actions
Parameter MenuItemActionType As INTEGER = 0;

/// Type (first argument to UserAction/AfterUserAction) for other editor (Studio/Atelier) actions
Parameter OtherEditorActionType As INTEGER = 1;

/// Other editor action: "User has tried to change a document that is locked in source control"
Parameter EditorLockedDocumentChanged As INTEGER = 0;

/// Other editor action: "User has created a new document"
Parameter EditorCreatedNewDocument As INTEGER = 1;

/// Other editor action: "User has deleted a document"
Parameter EditorDeletedDocument As INTEGER = 2;

/// Other editor action: "User has opened a document" <br />
/// Note: Not supported in Atelier as of Atelier 1.2.
Parameter EditorOpenedDocument As INTEGER = 3;

/// Other editor action: "User has closed a document" <br />
/// Note: Not supported in Atelier as of Atelier 1.2.
Parameter EditorClosedDocument As INTEGER = 4;

/// Other editor action: "User has connected to a new namespace document"
Parameter EditorConnectedToNewNamespace As INTEGER = 5;

/// Other editor action: "User has selected to import a comma-delimited list of documents" <br />
/// Note: Not supported in Atelier as of Atelier 1.2.
Parameter EditorImportedDocumentList As INTEGER = 6;

/// Other Studio action: "User has saved a new document for the first time"
Parameter SavedNewDocument As INTEGER = 7;

/// Action: do nothing
Parameter ActionDoNothing As INTEGER = 0;

/// Action: yes/no/cancel dialog
Parameter ActionYesNoCancel As INTEGER = 1;

/// Action: run CSP page/template
Parameter ActionRunCSP As INTEGER = 2;

/// Action: run .EXE or launch non-CSP web page
Parameter ActionRunEXEOrWebPage As INTEGER = 3;

/// Action: insert text in current document at current selection point
Parameter ActionInsertText As INTEGER = 4;

/// Action: open document(s)
Parameter ActionOpenDocuments As INTEGER = 5;

/// Action: alert
Parameter ActionAlert As INTEGER = 6;

/// Action: prompt, with Yes/No/Cancel buttons
Parameter ActionPrompt As INTEGER = 7;

}
