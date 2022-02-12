ROUTINE %IPM.Formatting [Type=INC]
#; Contains utility macros for formatting lines printed to Terminal

#define ColorScheme $Case(##class(%IPM.Repo.UniversalSettings).GetValue("ColorScheme"),"none":0,:1)
/// Returns a line with given formatting, clearing the formatting at the end of the line
#define FormattedLine(%formatCode, %line) $Select($$$ColorScheme:$$$ControlSequence(%formatCode)_%line_$$$ControlSequence($$$ResetAll),1:%line)

/// Creates the control sequence for the formatting based on the code
#define ControlSequence(%code) $Char(27)_"["_%code_"m"

#; Codes to add to convert format types
#define Reset 20
#define Background 10

#; All font formats (bold, underline etc.)
#define Bold 1
#define Bright 1
#define Dim 2
#define Underlined 4
#define Blink 5
#define Reverse 7
#define Hidden 8

#; All font format resets
#define ResetAll 0
#define ResetFontFormat(%format) ($$$Reset + %format)

#; Text colour conversions
#define BackgroundColor(%fgColor) ($$$Background + %fgColor)

#; All text colors in foreground
#define Default 39
#define Black 30
#define Red 31
#define Green 32
#define Yellow 33
#define Blue 34
#define Magenta 35
#define Cyan 36
#define White 97