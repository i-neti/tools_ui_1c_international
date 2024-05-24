
#Region Public

#Region StorageOfAlgorithms

// New description of algorithm headers.
// 
// Return values:
//  Structure -  Новый описание шапки алгоритма:
// * ID - String - 
// * Name - String - 
// * Code - String - 
// * Comment - String - 
// * Cache - Boolean - 
// * AtClient - Boolean - 
// * ThrowException - Boolean - 
// * ExecuteInTransaction - Boolean - 
// * RecordErrorsORL - Boolean - 
// * IDHTTP - String - 
// * RegularTaskID - String - 
// * ExecuteOnSchedule - Boolean - 
// * InSettingsStorage - Boolean - Если установлено Истина, сохранение происходит в хранилище общих настроек в базе
Function NewDescriptionOfAlgorithmHeaders() Export
	Description = New Structure;
	Description.Insert("ID","");
	Description.Insert("Name", "");
	Description.Insert("Code", "");
	Description.Insert("Comment","");
	Description.Insert("Cache", False);
	Description.Insert("AtClient", False);
	Description.Insert("ThrowException", False);
	Description.Insert("ExecuteInTransaction", False);
	Description.Insert("RecordErrorsORL", False);
	Description.Insert("IDHTTP", "");
	Description.Insert("RegularTaskID", "");
	Description.Insert("ExecuteOnSchedule", False);
	Description.Insert("InSettingsStorage", False);
	
	Return Description;
EndFunction

// New description of an algorithm.
// 
// Return values:
//  Structure -  New description of an algorithm:
// * ID - String - 
// * Name - String - 
// * Code - String - 
// * Comment - String - 
// * Cache - Boolean - 
// * AtClient - Boolean - 
// * ThrowException - Boolean - 
// * ExecuteInTransaction - Boolean - 
// * RecordErrorsORL - Boolean - 
// * IDHTTP - String - 
// * RegularTaskID - String - 
// * ExecuteOnSchedule - Boolean - 
// * InSettingsStorage - Boolean - If set to True, saving occurs in the general settings storage in the database
// * TextOfTheAlgorithm - String - 
// * Options - Array from look at NewAlgorithmParameterDescription - 
Function NewDescriptionOfAlgorithm() Export
	Description = NewDescriptionOfAlgorithmHeaders();
	Description.Insert("TextOfTheAlgorithm","");
	Description.Insert("Options", New Array);
	
	Return Description;
EndFunction

// New algorithm parameter description.
// 
// Return values:
//  Structure -  New algorithm parameter description:
// * Entrance - Boolean - 
// * Name - String - 
// * ParameterType - String - 
// * Default - String - 
Function NewAlgorithmParameterDescription() Export
	Description = New Structure;
	Description.Insert("Entrance", False);
	Description.Insert("Name", "");
	Description.Insert("ParameterType", "");
	Description.Insert("Default", "");
	
	Return Description;	
EndFunction

#EndRegion

#Region ExecutionOfAlgorithms

Function ExecuteAlgorithm(Algorithm, IncomingParameters = Undefined, ExecutionError = False, ErrorMessage = "") Export
	AlgorithmRef = UT_CommonServerCall.GetRefCatalogAlgorithms(Algorithm);
	If AlgorithmRef = Undefined Or Not ValueIsFilled(AlgorithmRef) Then
		ErrorMessage = "Algorithms : Error function execution(no script defined " + Algorithm + " )";
		If IncomingParameters = Undefined Then
			IncomingParameters = New Structure;
		EndIf;
		IncomingParameters.Insert("Cancel", True);
		IncomingParameters.Insert("ErrorMessage", ErrorMessage);
		//        WriteToEventLog(,ErrorMessage);
		Return New Map;
	EndIf;

	If TypeOf(IncomingParameters) = Type("Structure") Then
		If IncomingParameters.Property("this") Then
			this = IncomingParameters.this;
		Else
			this = New Map;
		EndIf;
	Else
		IncomingParameters = New Structure;
		this = New Map;
	EndIf;

	//	For Each StoredParameter In StoredParameters Do
	//		If Not Parameters.Property(StoredParameter.Key) Then 
	//			Parameters.Insert(StoredParameter.Key,StoredParameter.Value);
	//		EndIf;
	//	EndDo;

	PropertiesForAlgorithmAttributes = "Ref,AlgorithmText,ThrowException,WriteErrorsToEventLog,ExecuteInTransaction";

	AlgorithmProperties = UT_CommonServerCall.ObjectAttributesValues(AlgorithmRef,
		PropertiesForAlgorithmAttributes);

	ExecutableCode = ConvertTextToAlgorithmCode(AlgorithmProperties.AlgorithmText);

#If Server Then
	If AlgorithmProperties.ExecuteInTransaction Then
		BeginTransaction();
	EndIf;
#EndIf
	Try
		Execute (ExecutableCode);

#If Server Then
		If AlgorithmProperties.ExecuteInTransaction Then
			CommitTransaction();
		EndIf;
#EndIf

	Except
#If Server Then
		If AlgorithmProperties.ExecuteInTransaction Then
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;
		EndIf;
#EndIf

		ErrorMessage = ErrorMessage + " Error: " + ErrorDescription() + ";";
		ExecutionError = True;
		If AlgorithmProperties.WriteErrorsToEventLog Then
//			WriteLogEvent("Execute procedures "
//				+ AlgorithmRef,Parameters.ErrorMessage);
		EndIf;
		If AlgorithmProperties.ThrowException Then
			Raise ErrorDescription();
		EndIf;
	EndTry
	;
///	Object = Algorithm.GetObject();
////	Return Object.ExecuteFunction(AdditionalParameters);
EndFunction

#EndRegion

#Region Private

Function NormalizeText(Text, MarkEndOfText = True, WordsString = "") Export
	AlgorithmCode = StrReplace(Text, Chars.Tab, " ");
	AlgorithmCode = StrReplace(AlgorithmCode, Chars.LF, " ^ ");
	AlgorithmCode = StrReplace(AlgorithmCode, "=", " = ");
	AlgorithmCode = StrReplace(AlgorithmCode, "+", " + ");
	AlgorithmCode = StrReplace(AlgorithmCode, "<", " < ");
	AlgorithmCode = StrReplace(AlgorithmCode, ">", " > ");
	AlgorithmCode = StrReplace(AlgorithmCode, ";", " ; ");

	For А = 0 To Round(Sqrt(StrOccurrenceCount(AlgorithmCode, "  ")), 0) Do
		AlgorithmCode = StrReplace(AlgorithmCode, "  ", " ");
	EndDo;
	AlgorithmCode = StrReplace(AlgorithmCode, "< =", "<=");
	AlgorithmCode = StrReplace(AlgorithmCode, "> =", ">=");
	AlgorithmCode = StrReplace(AlgorithmCode, "< >", "<>");
	WordsArray = StrSplit(AlgorithmCode, " ");
	ByDefaultWordsString = "Return,And,Or,Not,If,Then,EndIf,For,Each,In,While,Do,EndDo";
	ServiceWordsArray = StrSplit(?(IsBlankString(WordsString), ByDefaultWordsString, WordsString), ",");
	For Word = 0 To WordsArray.UBound() Do
		For Each ServiceWord In ServiceWordsArray Do
			If Lower(TrimAll(WordsArray[Word])) = Lower(ServiceWord) Then
				WordsArray[Word] = ServiceWord;
			EndIf;
		EndDo;
	EndDo;
	AlgorithmCode = StrConcat(WordsArray, " ");
	AlgorithmCode = StrReplace(AlgorithmCode, "^", Chars.LF);
	If MarkEndOfText And Find(AlgorithmCode, "~EndOfText:") = 0 Then
		AlgorithmCode = AlgorithmCode + Chars.LF + "~EndOfText:";
	EndIf;
	Return AlgorithmCode;
EndFunction

Function ExcludedSymbolsArray() Export
	MExcluding = StrSplit(";,+, = ,-,),(,.,[,],{,},|,/,\,>,<,$,@,#", ",");
	mExcluding.Add(Chars.LF);
	mExcluding.Add(Chars.Tab);
	mExcluding.Add(Char(32));
	mExcluding.Add(",");
	mExcluding.Add("""");
	Return mExcluding;
EndFunction

Function ConvertTextToAlgorithmCode(Text) Export
	AlgorithmCode = NormalizeText(Text);
	MExcluding = ExcludedSymbolsArray();
	pReplacementInsert(AlgorithmCode, "@EvalFunction", "_37583_AlgorithmsServer.ExecuteFunction", "[""""Result""""]",
		mExcluding);
	pReplacementInsert(AlgorithmCode, "@FunctionResult", "_37583_AlgorithmsServer.ExecuteFunction", "[""Result""]",
		mExcluding);
	pReplacementInsert(AlgorithmCode, "@FunctionResultClient", "_37583_AlgorithmClient.ExecuteFunction",
		"[""Result""]", mExcluding);
	AlgorithmCode = StrReplace(AlgorithmCode, "@ProcedureClient", "_37583_AlgorithmClient.ExecuteProcedure");
	AlgorithmCode = StrReplace(AlgorithmCode, "@ProcedureClientAsync", "_37583_AlgorithmClient.ExecuteProcedure");
	AlgorithmCode = StrReplace(AlgorithmCode, "@FunctionClient", "_37583_AlgorithmClient.ExecuteFunction");
	AlgorithmCode = StrReplace(AlgorithmCode, "@Procedure", "_37583_AlgorithmsServer.ExecuteProcedure");
	AlgorithmCode = StrReplace(AlgorithmCode, "@Function", "_37583_AlgorithmsServer.ExecuteFunction");
	AlgorithmCode = StrReplace(AlgorithmCode, "@EnvironmentVariables", "_37583_AlgorithmsCache.GetParameters_37583()");
	pReplacementInsert(AlgorithmCode, "#", "[""", """]", mExcluding);
	pReplacementInsert(AlgorithmCode, "$$", "this[", "]", mExcluding);
	pReplacementInsert(AlgorithmCode, "$'", "this[""""", """""]", mExcluding);
	pReplacementInsert(AlgorithmCode, "$", "this[""", """]", mExcluding);
	AlgorithmCode = StrReplace(AlgorithmCode, "@", "Parameters.");
	AlgorithmCode = StrReplace(AlgorithmCode, "Return ;", "Goto ~EndOfText;");
	//AlgorithmCode = StrReplace(AlgorithmCode,"Return ","this[""Result""] = ");
	pReplacementInsert(AlgorithmCode, "Return ", "this[""Result""] = ", "; Goto ~EndOfText", ";", " ");

	Return AlgorithmCode;
EndFunction

Procedure pReplacementInsert(AlgoCode, Prefix, Before = "", After = "", Excluding = "", Including = "") Export
	While Find(AlgoCode, Prefix) > 0 Do
		Word = GetWordFirstOccurrenceWithOutPrefix(AlgoCode, Prefix, Excluding, Including);
		AlgoCode = StrReplace(AlgoCode, Prefix + Word, Before + Word + After);
	EndDo;
EndProcedure

Function fReplacementInsert(Val AlgoCode, Prefix, Before = "", After = "", Excluding = "", Including = "") Export
	While Find(AlgoCode, Prefix) > 0 Do
		Word = GetWordFirstOccurrenceWithOutPrefix(AlgoCode, Prefix, Excluding, Including);
		AlgoCode = StrReplace(AlgoCode, Prefix + Word, Before + Word + After);
	EndDo;
	Return AlgoCode;
EndFunction

Function GetWordFirstOccurrenceWithOutPrefix(String, Pref, Excluding = ";,+, = ,-,),(,.,[,],{,},|,/,\,>,<",
	Including = "") Export
	PrefLen = StrLen(Pref);
	PrefPos = StrFind(String, Pref) + PrefLen;

	If TypeOf(Including) = Type("Array") Then
		mIncluding = Including;
	Else
		mIncluding = StrSplit(Including, ",");
	EndIf;

	If TypeOf(Excluding) = Type("Array") Then
		mExcluding = Excluding;
	Else
		mExcluding = StrSplit(Excluding, ",");
	EndIf;

	mTerm = New Array;
	For Each SymbolExcluding In mExcluding Do
		If mIncluding.Find(SymbolExcluding) = Undefined Then
			mTerm.Add(StrFind(Mid(String, PrefPos), SymbolExcluding));
		EndIf;
	EndDo;

	Term = 1000000;
	For Each Item In mTerm Do
		If Item > 0 And Item < Term Then
			Term = Item;
		EndIf;
	EndDo;

	Word = ?(Term < 1000000, Mid(String, Find(String, Pref) + PrefLen, Term - 1), Mid(String, Find(String, Pref)
		+ PrefLen));
	Return Word;
EndFunction

// Algorithm text file name DBF.
// 
// Return values:
//  String -  Algorithm text file name DBF
Function AlgorithmTextFileNameDBF() Export
	Return "TextOfTheAlgorithm.txt";
EndFunction

#EndRegion


#EndRegion

#Region Internal

// Code of procedures and functions

#EndRegion

#Region Private

// Code of procedures and functions

#EndRegion










